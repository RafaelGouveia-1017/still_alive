import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:still_alive/data/all.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/services/integration_service.dart';
import 'package:still_alive/services/sms_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';

/// Per-contact emergency preferences as described by the `contacts.preferences`
/// row in the SQLite schema.
///
/// These preferences are evaluated independently for each configured contact
/// before an emergency destination is created. They determine whether the
/// emergency dispatch is permitted to include location information and/or
/// indicate that an audio recording was captured.
class EmergencyContactPreferences {
  const EmergencyContactPreferences({required this.sendLocation, required this.sendAudio});

  final bool sendLocation;
  final bool sendAudio;
}

/// Reads the emergency communication preferences configured for a contact.
///
/// The [contactId] identifies the contact whose preferences should be read.
/// The returned [EmergencyContactPreferences] determines which optional
/// emergency information may be included when dispatching to that contact,
/// such as location data or an indication that emergency audio was recorded.
///
/// Implementations may obtain these values from the application's persistent
/// settings or another appropriate preferences store.
typedef EmergencyContactPreferencesReader = Future<EmergencyContactPreferences> Function(String contactId);

/// Reads the application's configured emergency siren volume.
///
/// The returned integer is expected to represent the configured volume using
/// the application's 0-100 scale. [EmergencySirenService] converts this value
/// to the audio player's corresponding volume range when starting the siren.
typedef EmergencyVolumeReader = Future<int> Function();

/// Sends an emergency message to an email recipient.
///
/// [recipient] is the destination email address, [subject] is the email
/// subject, and [body] contains the emergency message. The returned [bool]
/// indicates whether the email-sending implementation accepted the request
/// successfully.
///
/// Implementations may use a direct email transport or another application
/// integration. The caller treats a `false` result as a failed dispatch and
/// allows the destination to be retried.
typedef EmergencyEmailSender = Future<bool> Function({required String recipient, required String subject, required String body});

/// Provides project-specific dependencies used by the emergency subsystem.
///
/// [EmergencyAdapters] isolates database access, settings access, and email
/// delivery from the emergency UI and dispatch logic. Each dependency can be
/// replaced through the constructor, which makes the emergency workflow
/// testable without requiring the concrete database or platform integrations.
///
/// When an adapter is not supplied, the class uses the default implementations
/// defined in this file.
class EmergencyAdapters {
  EmergencyAdapters({
    EmergencyContactPreferencesReader? contactPreferencesReader,
    EmergencyVolumeReader? volumeReader,
    EmergencyEmailSender? emailSender,
  }) : contactPreferencesReader = contactPreferencesReader ?? _defaultContactPreferencesReader,
       volumeReader = volumeReader ?? _defaultVolumeReader,
       emailSender = emailSender ?? _defaultEmailSender;

  final EmergencyContactPreferencesReader contactPreferencesReader;
  final EmergencyVolumeReader volumeReader;
  final EmergencyEmailSender emailSender;

  static Future<EmergencyContactPreferences> _defaultContactPreferencesReader(String contactID) async {
    try {
      String result = await selectOne(
        sql:
            """
            SELECT j.value
            FROM contacts c,
                json_each(c.value, '\$.contacts') AS j
            WHERE c.key = 'preferences'
              AND json_extract(j.value, '\$.id') = '$contactID';
            """,
      );
      Map<String, dynamic> preferences = (result == "None") ? {"id": contactID, "location": true, "audio": true} : jsonDecode(result);
      return EmergencyContactPreferences(sendLocation: preferences["location"], sendAudio: preferences["audio"]);
    } catch (e, st) {
      AppLogger.log.warning("Couldn't get configured contact preferences.", e, st);
      return const EmergencyContactPreferences(sendLocation: true, sendAudio: true);
    }
  }

  static Future<int> _defaultVolumeReader() async {
    try {
      final result = await selectOne(sql: "SELECT value FROM settings WHERE key = 'volume'");
      return int.parse(result);
    } catch (e, st) {
      AppLogger.log.warning("Couldn't get configured volume level.", e, st);
      return 100;
    }
  }

  static Future<bool> _defaultEmailSender({required String recipient, required String subject, required String body}) async {
    //Not automatic
    final uri = Uri(scheme: 'mailto', path: recipient, queryParameters: <String, String>{'subject': subject, 'body': body});
    return launchUrl(uri, mode: LaunchMode.externalApplication);

    //It would be automatic with SMTP details from user
  }
}

/// Identifies the transport used by an emergency destination.
///
/// Each value corresponds to an independently dispatchable destination type.
/// The selected value determines which delivery helper is used by
/// [EmergencyDispatchService].
enum EmergencyDestinationKind {
  /// Sends the emergency message to a phone number using SMS.
  ///
  /// Each SMS number is treated as an independent destination, allowing its
  /// delivery state to be tracked and retried separately from other
  /// destinations.
  sms,

  /// Sends the emergency message to an email address.
  ///
  /// Each email address is represented as an independent destination so its
  /// delivery result can be tracked separately from SMS and integration
  /// destinations.
  email,

  /// Sends the emergency message through a configured external integration.
  ///
  /// An integration destination is identified by the integration key,
  /// account ID, and destination ID stored in [EmergencyDispatchTarget].
  /// Examples include destinations belonging to services such as Discord or
  /// Telegram.
  integration,
}

/// Describes one independently addressable destination used during an
/// emergency dispatch.
///
/// The object contains both presentation information, such as [title] and
/// [destination], and the identifiers needed by the underlying SMS, email, or
/// integration transport.
class EmergencyDispatchTarget {
  const EmergencyDispatchTarget({
    required this.id,
    required this.kind,
    required this.title,
    required this.destination,
    this.contactId,
    this.integrationKey,
    this.accountId,
    this.destinationId,
    this.allowLocation = true,
    this.allowAudio = true,
  });

  final String id;
  final EmergencyDestinationKind kind;
  final String title;
  final String destination;

  final String? contactId;

  final String? integrationKey;
  final String? accountId;
  final String? destinationId;

  final bool allowLocation;
  final bool allowAudio;

  bool get requiresInternet => kind == EmergencyDestinationKind.email || kind == EmergencyDestinationKind.integration;
}

/// Represents the current delivery state of an emergency message.
///
/// The state progresses from [pending] to [sending] and then to either
/// [sent] or [failed]. A failed destination may subsequently be returned to
/// [pending] and dispatched again by the user.
enum EmergencyDispatchState {
  /// The message has not yet been sent.
  ///
  /// This is also the state used when a message is waiting for network
  /// connectivity or has been explicitly queued for retry.
  pending,

  /// The delivery operation is currently in progress.
  ///
  /// The emergency UI can use this state to show an indeterminate progress
  /// indicator and prevent a second simultaneous attempt for the same
  /// destination.
  sending,

  /// The delivery operation completed successfully.
  ///
  /// A destination in this state does not require another initial dispatch
  /// unless a newer location revision needs to be sent separately.
  sent,

  /// The delivery operation completed unsuccessfully.
  ///
  /// The associated [EmergencyDispatchResult.error], when available, can be
  /// used for diagnostics. The emergency UI should expose a retry action that
  /// moves the destination back to [pending].
  failed,
}

/// Contains the outcome of one emergency message-delivery attempt.
///
/// [state] represents the terminal or intermediate dispatch result known to
/// the caller. When a transport throws an exception or explicitly reports a
/// failure, [error] contains the associated failure object when one is
/// available so it can be displayed or persisted for diagnostics.
class EmergencyDispatchResult {
  const EmergencyDispatchResult({required this.state, this.error});

  final EmergencyDispatchState state;
  final Object? error;
}

/// Location/route data captured for one emergency send.
///
/// [currentLocation] contains the latest point available at the time of the
/// capture. [polyline] contains the encoded route when route sharing is
/// enabled. The convenience getters allow dispatch code to determine whether
/// either form of location information is actually available.
class EmergencyLocationPayload {
  const EmergencyLocationPayload({this.currentLocation, this.polyline = ''});

  final LatLng? currentLocation;
  final String polyline;

  bool get hasLocation => currentLocation != null;
  bool get hasRoute => polyline.isNotEmpty;
}

/// Builds independent destinations and performs sends through the helper
/// services already present in the project.
///
/// This service converts the active timer configuration into concrete
/// [EmergencyDispatchTarget] instances, applies contact-level location and
/// audio preferences, formats the initial and location-update messages, and
/// delegates delivery to the existing SMS, email, and integration helpers.
///
/// Each destination is dispatched independently so a failure for one
/// recipient does not prevent another configured recipient from being
/// attempted or retried.
class EmergencyDispatchService {
  EmergencyDispatchService(this.adapters, this.local);

  final EmergencyAdapters adapters;
  final AppLocalizations local;

  final SmsService _sms = const SmsService();

  Future<List<EmergencyDispatchTarget>> buildTargets(ActiveTimer timer) async {
    final targets = <EmergencyDispatchTarget>[];

    for (final contact in timer.config.contacts) {
      final prefs = await adapters.contactPreferencesReader(contact.id);

      for (final phone in contact.sms) {
        targets.add(
          EmergencyDispatchTarget(
            id: 'sms:${contact.id}:$phone',
            kind: EmergencyDestinationKind.sms,
            title: 'SMS',
            destination: phone,
            contactId: contact.id,
            allowLocation: prefs.sendLocation,
            allowAudio: prefs.sendAudio,
          ),
        );
      }

      for (final email in contact.email) {
        targets.add(
          EmergencyDispatchTarget(
            id: 'email:${contact.id}:$email',
            kind: EmergencyDestinationKind.email,
            title: 'Email',
            destination: email,
            contactId: contact.id,
            allowLocation: prefs.sendLocation,
            allowAudio: prefs.sendAudio,
          ),
        );
      }
    }

    for (final phone in timer.config.customSms) {
      targets.add(EmergencyDispatchTarget(id: 'sms:custom:$phone', kind: EmergencyDestinationKind.sms, title: 'SMS', destination: phone));
    }

    for (final email in timer.config.customEmail) {
      targets.add(EmergencyDispatchTarget(id: 'email:custom:$email', kind: EmergencyDestinationKind.email, title: 'Email', destination: email));
    }

    final integrations = await loadAllIntegrations();

    Future<void> addIntegrationTargets({required String integrationKey, required List<dynamic> timerAccounts}) async {
      final info = integrations.firstWhere(
        (item) => item.key == integrationKey,
        orElse: () => throw StateError('Integration "$integrationKey" is not configured.'),
      );

      for (final timerAccount in timerAccounts) {
        IntegrationAccount? account;
        for (final candidate in info.accounts) {
          if (candidate.id == timerAccount.id) {
            account = candidate;
            break;
          }
        }
        if (account == null) continue;

        for (final selectedDestinationId in timerAccount.destinations.cast<String>()) {
          final destination = account.destinations.firstWhere(
            (d) => d.id == selectedDestinationId,
            orElse: () => throw StateError(
              'Configured $integrationKey destination "$selectedDestinationId" '
              'is not present in the integration account.',
            ),
          );

          final parent = destination.parentName;
          final label = parent == null || parent.isEmpty
              ? '${account.name} • ${destination.name}'
              : '${account.name} • $parent / ${destination.name}';

          targets.add(
            EmergencyDispatchTarget(
              id: 'integration:$integrationKey:${account.id}:${destination.id}',
              kind: EmergencyDestinationKind.integration,
              title: info.key[0].toUpperCase() + info.key.substring(1),
              destination: label,
              integrationKey: integrationKey,
              accountId: account.id,
              destinationId: destination.id,
            ),
          );
        }
      }
    }

    await addIntegrationTargets(integrationKey: 'discord', timerAccounts: timer.config.integrations.discord.accounts);
    await addIntegrationTargets(integrationKey: 'telegram', timerAccounts: timer.config.integrations.telegram.accounts);

    return targets;
  }

  String buildInitialMessage({
    required String? baseMessage,
    required EmergencyDispatchTarget target,
    required EmergencyLocationPayload payload,
    required bool audioRecorded,
  }) {
    final buffer = StringBuffer(local.translate("emergency_active.dispatch.message.title"));
    final text = baseMessage?.trim();
    if (text != null && text.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln(text);
    } else {
      buffer
        ..writeln()
        ..writeln()
        ..write(local.translate("emergency_active.dispatch.message.default"));
    }

    if (target.allowLocation) {
      _appendLocation(buffer, payload);
    }

    if (audioRecorded && target.allowAudio) {
      buffer
        ..writeln()
        ..writeln(local.translate("emergency_active.dispatch.message.audio"));
    }

    return buffer.toString().trim();
  }

  String? buildLocationUpdate({required EmergencyDispatchTarget target, required EmergencyLocationPayload payload}) {
    if (target.allowLocation) {
      final buffer = StringBuffer(local.translate("emergency_active.dispatch.location.update"));
      _appendLocation(buffer, payload);
      return buffer.toString();
    }
    return null;
  }

  void _appendLocation(StringBuffer buffer, EmergencyLocationPayload payload) {
    final point = payload.currentLocation;
    if (point != null) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln(
          '${local.translate("emergency_active.dispatch.location.position")} '
          '${point.latitude.toStringAsFixed(6)}, '
          '${point.longitude.toStringAsFixed(6)}',
        )
        ..writeln('https://www.google.com/maps/search/${point.latitude}+${point.longitude}');
    }

    if (payload.polyline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('${local.translate("emergency_active.dispatch.location.decode")} https://tools.nextbillion.ai/polyline-decoder')
        ..writeln(local.translate("emergency_active.dispatch.location.encode"))
        ..writeln(payload.polyline);
    }
  }

  Future<EmergencyDispatchResult> send({required EmergencyDispatchTarget target, required String message}) async {
    try {
      switch (target.kind) {
        case EmergencyDestinationKind.sms:
          final result = await _sms.send(phoneNumbers: [target.destination], message: message);
          return EmergencyDispatchResult(
            state: result == SmsResult.sent ? EmergencyDispatchState.sent : EmergencyDispatchState.failed,
            error: result == SmsResult.sent ? null : result,
          );

        case EmergencyDestinationKind.email:
          final ok = await adapters.emailSender(
            recipient: target.destination,
            subject: local.translate("emergency_active.dispatch.subject"),
            body: message,
          );
          return EmergencyDispatchResult(state: ok ? EmergencyDispatchState.sent : EmergencyDispatchState.failed);

        case EmergencyDestinationKind.integration:
          final sent = await IntegrationService.sendMessage(
            integrationKey: target.integrationKey!,
            accountId: target.accountId!,
            destinationId: target.destinationId!,
            message: message,
          );
          return EmergencyDispatchResult(state: sent == null ? EmergencyDispatchState.failed : EmergencyDispatchState.sent);
      }
    } catch (error) {
      return EmergencyDispatchResult(state: EmergencyDispatchState.failed, error: error);
    }
  }

  Map<String, dynamic> toHistoryEntry(EmergencyDispatchTarget target, EmergencyDispatchState state, {Object? error}) {
    switch (target.kind) {
      case EmergencyDestinationKind.integration:
        return <String, dynamic>{'platform': '${target.title}|${target.destination}', 'status': state.name};
      default:
        return <String, dynamic>{'recipient': target.destination, 'status': state.name};
    }
  }
}

/// Owns microphone recording and user-selected export.
///
/// The service records emergency audio into a temporary application file while
/// the emergency is active. It exposes the current recording path and recording
/// state to the UI, supports stopping the recording, and copies the resulting
/// file to a location selected by the user through the platform file picker.
///
/// Microphone permission is checked before recording starts. A recording that
/// cannot be started therefore does not prevent the rest of the emergency
/// workflow from operating.
class EmergencyAudioService {
  final AudioRecorder _recorder = AudioRecorder();

  String? _path;
  bool _recording = false;

  String? get path => _path;
  bool get isRecording => _recording;

  Future<bool> start() async {
    if (_recording) return true;

    if (!await _recorder.hasPermission()) {
      return false;
    }

    final temp = await getTemporaryDirectory();
    final filePath = p.join(temp.path, 'emergency_audio_${DateTime.now().millisecondsSinceEpoch}.flac');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.flac,
        androidConfig: AndroidRecordConfig(
          muteAudio: false,
          audioSource: AndroidAudioSource.mic,
          speakerphone: true,
          audioManagerMode: AudioManagerMode.modeNormal,
        ),
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.overrideMutedMicrophoneInterruption,
            IosAudioCategoryOption.duckOthers,
          ],
          allowHapticsAndSystemSoundsDuringRecording: false,
        ),
      ),
      path: filePath,
    );

    _path = filePath;
    _recording = true;
    return true;
  }

  Future<String?> stop() async {
    if (!_recording) return _path;

    final result = await _recorder.stop();
    _recording = false;
    _path = result ?? _path;
    return _path;
  }

  Future<String?> exportToUserLocation({String? sourcePath}) async {
    final path = sourcePath ?? _path;
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    await stop();
    final bytes = await file.readAsBytes();
    await start();

    String title = "Export emergency recording";
    BuildContext? context = PermissionManager.instance.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      AppLocalizations local = AppLocalizations.of(context)!;
      title = local.translate("emergency_active.audio.save");
    }

    return (await FilePicker.saveFile(
      dialogTitle: title,
      fileName: 'StillAlive_Audio_${DateTime.now().toIso8601String().replaceAll(':', '-')}.flac',
      bytes: bytes,
      allowedExtensions: ['flac'],
      type: FileType.audio,
    ))?.toString();
  }

  Future<void> dispose() async {
    if (_recording) {
      await _recorder.stop();
    }
    _recorder.dispose();
  }
}

/// Plays the emergency siren at the volume configured in the settings table.
///
/// The siren is looped continuously while the application is in the offline
/// emergency state. The configured integer volume is converted from the
/// application's 0-100 representation to the audio player's 0.0-1.0 range.
///
/// Calling [start] while the siren is already playing updates its volume
/// without restarting playback. [stop] terminates the current playback and
/// [dispose] releases the underlying audio-player resource.
class EmergencySirenService {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  bool get isPlaying => _playing;

  Stream<AudioEvent> get audioStream => _player.eventStream;

  Future<void> start({required int volumePercent}) async {
    final volume = (volumePercent.clamp(0, 100)) / 100.0;

    if (_playing) {
      await _player.setVolume(volume);
      return;
    }

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume);

    final ByteData data = await rootBundle.load('lib/assets/audio/alarm_siren.mp3');
    final Uint8List siren = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await _player.play(BytesSource(siren, mimeType: 'audio/mp3'));

    _playing = true;
  }

  Future<void> stop() async {
    if (!_playing) return;
    await _player.stop();
    _playing = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// A small helper for the network stream owned by the emergency screen.
///
/// [EmergencyNetworkMonitor] provides a narrowly scoped abstraction over
/// [InternetConnection]. The emergency screen uses it to determine whether
/// internet access is currently available and to react to connectivity
/// transitions without coupling the UI directly to the connectivity package.
///
/// The monitor does not make dispatch decisions itself; it only exposes
/// connectivity state and events. The owning screen decides when pending
/// messages should pause, resume, or trigger the emergency siren.
class EmergencyNetworkMonitor {
  final InternetConnection _connection = InternetConnection();

  Stream<InternetStatus> get statusStream => _connection.onStatusChange;

  Future<bool> get hasInternetAccess => _connection.hasInternetAccess;
}
