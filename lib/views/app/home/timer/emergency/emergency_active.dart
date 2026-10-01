import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:still_alive/services/location_service.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/services/history_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/views/app/home/home.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';
import '../../../../widgets/elliptical_gradient.dart';
import 'emergency_helpers.dart';
import 'emergency_widgets.dart';

/// The top-level screen displayed while an emergency timer is active.
///
/// This screen coordinates the emergency workflow after the timer has
/// transitioned into its emergency state. It presents the current route or
/// location when location sharing is enabled, manages microphone recording,
/// dispatches messages to configured destinations, exposes retry controls for
/// failed sends, and reacts to network connectivity changes.
///
/// The screen also owns the final emergency-stop interaction. Stopping the
/// emergency captures the latest location data, stops and optionally exports
/// the active audio recording, stops the emergency siren, finalizes the
/// emergency history record, cancels the active timer, and navigates back to
/// [HomeScreen].
class EmergencyActiveScreen extends StatefulWidget {
  const EmergencyActiveScreen({super.key});

  @override
  State<EmergencyActiveScreen> createState() => _EmergencyActiveScreenState();
}

/// State implementation for [EmergencyActiveScreen].
///
/// This state owns all transient information associated with the current
/// emergency session, including:
///
/// - Dispatch progress for each configured destination.
/// - The latest route and current geographic location.
/// - The encoded route polyline used in outgoing messages and history.
/// - Audio recording and export state.
/// - Current network connectivity.
/// - Emergency siren state.
/// - Location revision tracking used to determine whether a destination has
///   received the newest location information.
///
/// It also owns and coordinates the lifecycle of the emergency-specific
/// services:
///
/// - [EmergencyDispatchService] for preparing and sending messages.
/// - [EmergencyAudioService] for recording and exporting audio.
/// - [EmergencySirenService] for controlling the emergency siren.
/// - [EmergencyNetworkMonitor] for observing connectivity changes.
///
/// Resources owned by this state are released in [dispose].
class _EmergencyActiveScreenState extends State<EmergencyActiveScreen> {
  late final EmergencyAdapters _adapters;
  late final EmergencyDispatchService _dispatcher;
  late final EmergencyAudioService _audio;
  late final EmergencySirenService _siren;
  late final EmergencyNetworkMonitor _network;

  StreamSubscription<InternetStatus>? _networkSubscription;
  Timer? _locationPoller;

  final List<DispatchRow> _rows = [];

  List<LatLng> _route = [];
  LatLng? _currentLocation;
  String _polyline = '';

  bool _isLoading = true;
  bool _online = true;
  bool _ending = false;
  bool _ignoreStop = false;
  bool _dispatchingPending = false;
  bool _audioUnavailable = false;
  bool _sirenDismissed = false;
  String? _audioPath;
  int _locationRevision = 0;

  /// Initializes the emergency screen and its supporting services.
  ///
  /// System UI is switched to immersive mode, the emergency service
  /// dependencies are created, and [_initialize] is started to load the
  /// current emergency state.
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _adapters = EmergencyAdapters();
      _dispatcher = EmergencyDispatchService(_adapters, AppLocalizations.of(context)!);
      _audio = EmergencyAudioService();
      _siren = EmergencySirenService();
      _network = EmergencyNetworkMonitor();

      _initialize();
    });
  }

  /// Loads the initial state required to operate the emergency screen.
  ///
  /// This includes the current network state, active timer configuration,
  /// current location data, route information, optional audio recording,
  /// configured dispatch destinations, and connectivity listeners.
  ///
  /// Location polling is started when location sharing is enabled without
  /// route sharing. Once initialization is complete, destinations that can
  /// be dispatched immediately are processed. Internet-dependent destinations
  /// remain pending while offline.
  ///
  /// Initialization failures are intentionally contained so that a failure
  /// while preparing dispatch metadata does not prevent the emergency UI
  /// itself from remaining available.
  Future<void> _initialize() async {
    try {
      final online = await _network.hasInternetAccess;
      final timer = TimerService.instance.activeTimer;

      final payload = await TimerService.instance.getLocationData();

      _route = LocationService.instance.currentRoute;
      _currentLocation = payload.currentLocation;
      _polyline = payload.polyline;

      if (timer.config.audioRecordingEnabled) {
        final started = await _audio.start();
        _audioUnavailable = !started;
      }

      final targets = await _dispatcher.buildTargets(timer);
      _rows
        ..clear()
        ..addAll(targets.map((target) => DispatchRow(target: target)));

      _online = online;

      // Subscribe before dispatching so a connectivity transition isn't missed.
      _networkSubscription = _network.statusStream.listen(_handleNetworkStatus);

      if (timer.config.locationSharingEnabled && !timer.config.routeSharingEnabled) {
        final interval = timer.config.locationCollectionIntervalSecs?.toInt() ?? 10;
        _locationPoller = Timer.periodic(Duration(seconds: interval.clamp(1, 3600).toInt()), (_) => _refreshSingleLocation());
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Dispatch what can be dispatched now.
      // SMS can proceed offline; internet transports wait.
      await _dispatchAllPending();

      if (!_online) {
        await _enterOfflineState();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Do not fail the entire emergency UI because dispatch metadata failed.
      // Network/audio/map state remains visible.
      AppLogger.log.severe('Emergency screen initialization failed.', error);
    }
  }

  /// Refreshes the current location when route sharing is not being used.
  ///
  /// The method obtains a fresh location from [LocationService]. If the
  /// location has changed, [_locationRevision] is incremented and every
  /// location-enabled destination is marked as requiring a location update.
  ///
  /// The operation is ignored while the emergency is being terminated or
  /// after the widget has been removed from the widget tree.
  Future<void> _refreshSingleLocation() async {
    if (_ending || !mounted) return;

    try {
      final next = await LocationService.instance.getCurrentLocation();

      if (_currentLocation == null) return;

      double truncateForDisplay(double value, int decimals) {
        final factor = pow(10, decimals);
        final truncated = (value * factor).truncate() / factor;
        return double.parse(truncated.toStringAsFixed(decimals));
      }

      double currentLatitudeTrimmed = truncateForDisplay(_currentLocation!.latitude, 4);
      double currentLongitudeTrimmed = truncateForDisplay(_currentLocation!.longitude, 4);
      double nextLatitudeTrimmed = truncateForDisplay(next.latitude, 4);
      double nextLongitudeTrimmed = truncateForDisplay(next.longitude, 4);
      bool latitude = currentLatitudeTrimmed == nextLatitudeTrimmed;
      bool longitude = currentLongitudeTrimmed == nextLongitudeTrimmed;
      if (latitude && longitude) {
        setState(() {});
        return;
      }

      setState(() {
        _currentLocation = next;
        _locationRevision++;
        for (final row in _rows) {
          if (row.target.allowLocation) {
            row.locationUpdateDirty = row.lastLocationRevisionSent != _locationRevision;
          }
        }
      });
    } catch (e, st) {
      AppLogger.log.warning('Unable to refresh emergency location.', e, st);

      if (e is LocationServiceDisabledException && mounted) {
        ColorScheme scheme = Theme.of(context).colorScheme;
        AppLocalizations local = AppLocalizations.of(context)!;

        showToast(
          scheme: scheme,
          toast: Text(local.translate("time_map_viewer.location_error"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
          gravity: ToastGravity.TOP,
          position: (context, child, gravity) {
            return Positioned(top: 300, left: 60, right: 60, child: child);
          },
          secs: 7,
        );
      }
    }
  }

  /// Handles changes reported by [EmergencyRouteTile].
  ///
  /// A route change is considered meaningful when either its number of points
  /// changes or its final coordinate changes. Meaningful changes update the
  /// displayed route, current location, and location revision.
  ///
  /// After updating the in-memory route, the encoded route is reloaded so
  /// subsequent location messages contain the latest route representation.
  Future<void> _handleRouteChanged(List<LatLng> route) async {
    if (_ending || !mounted) return;

    final changed =
        route.length != _route.length ||
        (route.isNotEmpty && _route.isNotEmpty && (route.last.latitude != _route.last.latitude || route.last.longitude != _route.last.longitude));

    if (!changed) return;

    setState(() {
      _route = route;
      if (route.isNotEmpty) {
        _currentLocation = route.last;
      }
      _locationRevision++;

      for (final row in _rows) {
        if (row.target.allowLocation) {
          row.locationUpdateDirty = row.lastLocationRevisionSent != _locationRevision;
        }
      }
    });

    await _reloadEncodedRoute();
  }

  /// Reloads the encoded representation of the current route.
  ///
  /// The encoded polyline is obtained from [LocationService] and stored in
  /// [_polyline]. The method safely ignores the result if the screen has been
  /// disposed or the emergency is already being terminated.
  Future<void> _reloadEncodedRoute() async {
    try {
      final encoded = await LocationService.instance.loadEncodedRoute();
      if (!mounted || _ending) return;
      setState(() {
        _polyline = encoded;
      });
    } catch (e, st) {
      AppLogger.log.warning('Unable to refresh encoded emergency route.', e, st);
    }
  }

  /// Reacts to changes reported by the emergency network monitor.
  ///
  /// When connectivity is lost, [_enterOfflineState] marks internet-dependent
  /// dispatches as pending and starts the emergency siren when appropriate.
  ///
  /// When connectivity returns, the UI is updated and pending dispatches are
  /// retried automatically.
  Future<void> _handleNetworkStatus(InternetStatus status) async {
    final connected = status == InternetStatus.connected;
    if (!connected) {
      await _enterOfflineState();
      return;
    }

    if (!mounted || _ending) return;

    setState(() {
      _online = true;
    });

    // Internet has returned: resume anything that was waiting.
    await _dispatchAllPending();
  }

  /// Transitions the emergency screen into its offline state.
  ///
  /// All unsent destinations that require internet connectivity are returned
  /// to [DispatchState.pending] so they can be retried when connectivity
  /// returns.
  ///
  /// Unless the user has already dismissed the siren, entering the offline
  /// state also starts the emergency siren using the device's current volume.
  Future<void> _enterOfflineState() async {
    if (_ending) return;

    if (mounted) {
      setState(() {
        _online = false;

        for (final row in _rows) {
          if (row.target.requiresInternet && row.state != DispatchState.sent) {
            row.state = DispatchState.pending;
            row.error = null;
          }
        }
      });
    }

    if (_sirenDismissed) return;

    try {
      final volume = await _adapters.volumeReader();
      await _siren.start(volumePercent: volume);
      if (!mounted || _ending) return;
      setState(() {});
    } catch (e, st) {
      AppLogger.log.warning('Could not play emergency siren.', e, st);
    }
  }

  /// Dispatches every destination that is currently eligible for sending.
  ///
  /// Pending destinations are processed sequentially. Destinations that
  /// require internet connectivity are skipped while offline and remain
  /// pending for a later connectivity transition.
  ///
  /// [_dispatchingPending] prevents concurrent invocations from processing
  /// the same set of destinations simultaneously.
  Future<void> _dispatchAllPending() async {
    if (_ending || _dispatchingPending) return;

    _dispatchingPending = true;

    try {
      for (final row in _rows) {
        if (_ending) break;
        if (row.state != DispatchState.pending) continue;

        // Internet-dependent destinations wait until connectivity returns.
        if (row.target.requiresInternet && !_online) {
          continue;
        }

        await _dispatchRow(row);
      }
    } finally {
      _dispatchingPending = false;
    }
  }

  /// Sends the initial emergency message for a single destination.
  ///
  /// The message includes the current location and route when the destination
  /// permits location sharing. The current location revision is captured
  /// before sending so that a location change occurring during the send can
  /// be detected afterward.
  ///
  /// Successful sends transition the row to [DispatchState.sent]. Failed
  /// sends transition it to [DispatchState.failed] and preserve the error so
  /// the user can retry the destination.
  Future<void> _dispatchRow(DispatchRow row) async {
    if (_ending) return;

    // Only internet-dependent transports are blocked offline.
    if (row.target.requiresInternet && !_online) {
      return;
    }

    final sendRevision = _locationRevision;

    setState(() {
      row.state = DispatchState.sending;
      row.error = null;
    });

    try {
      final timer = TimerService.instance.activeTimer;
      final payload = EmergencyLocationPayload(
        currentLocation: row.target.allowLocation ? _currentLocation : null,
        polyline: row.target.allowLocation ? _polyline : '',
      );

      final message = _dispatcher.buildInitialMessage(
        baseMessage: timer.config.message ?? '',
        target: row.target,
        payload: payload,
        audioRecorded: _audio.path != null,
      );

      final result = await _dispatcher.send(target: row.target, message: message);

      if (!mounted || _ending) return;

      setState(() {
        row.state = result.state == EmergencyDispatchState.sent ? DispatchState.sent : DispatchState.failed;
        row.error = result.error;
        if (result.state == EmergencyDispatchState.sent) {
          row.lastLocationRevisionSent = sendRevision;
          row.locationUpdateDirty = row.target.allowLocation && _locationRevision != sendRevision;
        }
      });
    } catch (e, st) {
      AppLogger.log.warning('Emergency dispatch failed.', e, st);

      if (!mounted || _ending) return;

      setState(() {
        row.state = DispatchState.failed;
        row.error = e;
      });
    }
  }

  /// Sends an updated location to a destination that already received
  /// an earlier emergency message.
  ///
  /// A location update is only allowed when the destination permits location
  /// sharing and, when required, internet connectivity is available.
  ///
  /// The location revision captured before sending is compared with the
  /// current revision afterward. If the location changed while the update
  /// was in flight, the row remains marked as dirty so another update can be
  /// sent later.
  Future<void> _dispatchLocationUpdate(DispatchRow row) async {
    if (_ending || row.sendingLocationUpdate || !row.target.allowLocation) {
      return;
    }

    if (row.target.requiresInternet && !_online) {
      return;
    }

    final sendRevision = _locationRevision;

    setState(() {
      row.sendingLocationUpdate = true;
      row.error = null;
    });

    try {
      final payload = EmergencyLocationPayload(currentLocation: _currentLocation, polyline: _polyline);

      final message = _dispatcher.buildLocationUpdate(target: row.target, payload: payload);
      if (message == null) return;

      final result = await _dispatcher.send(target: row.target, message: message);

      if (!mounted || _ending) return;

      setState(() {
        row.sendingLocationUpdate = false;
        if (result.state == EmergencyDispatchState.sent) {
          row.lastLocationRevisionSent = sendRevision;
          row.locationUpdateDirty = _locationRevision != sendRevision;
        } else {
          row.locationUpdateDirty = true;
          row.error = result.error;
        }
      });

      ColorScheme scheme = Theme.of(context).colorScheme;
      AppLocalizations local = AppLocalizations.of(context)!;

      showToast(
        scheme: scheme,
        toast: Text(local.translate("emergency_active.location.update"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
        gravity: ToastGravity.BOTTOM,
        position: (context, child, gravity) => Positioned(bottom: 150, left: 50, right: 50, child: child),
      );
    } catch (e, st) {
      AppLogger.log.warning('Emergency location update failed.', e, st);

      if (!mounted) return;
      setState(() {
        row.sendingLocationUpdate = false;
        row.locationUpdateDirty = true;
        row.error = e;
      });
    }
  }

  /// Exports the currently recorded emergency audio.
  ///
  /// The recording must have an available local path before an export can be
  /// attempted. The audio service presents the destination-selection flow to
  /// the user.
  ///
  /// When [automatic] is `true`, a failed or cancelled export is logged because
  /// the export was initiated automatically as part of stopping the emergency.
  Future<void> _exportAudio({bool automatic = false}) async {
    if (_audio.path == null) return;

    final uri = await _audio.exportToUserLocation(sourcePath: _audio.path);

    if (automatic && uri == null) {
      AppLogger.log.warning('Emergency audio export was cancelled or failed.');
    }
  }

  /// Converts a dispatch row into the history representation used by
  /// [TimerExpiredEvent].
  ///
  /// A row that is currently sending is recorded as pending because no
  /// successful delivery has been confirmed yet.
  Map<String, dynamic> _historyEntry(DispatchRow row) {
    final state = switch (row.state) {
      DispatchState.pending => EmergencyDispatchState.pending,
      DispatchState.sending => EmergencyDispatchState.pending,
      DispatchState.sent => EmergencyDispatchState.sent,
      DispatchState.failed => EmergencyDispatchState.failed,
    };

    return _dispatcher.toHistoryEntry(row.target, state, error: row.error);
  }

  /// Stops the active emergency and finalizes its history record.
  ///
  /// If the timer is password protected, the user must successfully complete
  /// the configured password verification before the emergency can be stopped.
  ///
  /// Before canceling the timer, the method captures the latest location and
  /// route because cancellation may stop the continuous location recording.
  /// It then stops the audio recording, attempts automatic audio export,
  /// stops the siren, cancels the active timer, records the final emergency
  /// history, and returns the user to [HomeScreen].
  ///
  /// The [_ignoreStop] and [_ending] flags prevent multiple simultaneous stop
  /// operations.
  Future<void> _stopEmergency() async {
    if (_ignoreStop || _ending) return;

    final passwordProtected = TimerService.instance.activeTimer.config.passwordProtected;

    bool? passwordVerified = false;
    if (passwordProtected) {
      passwordVerified = await TimerService.instance.showPasswordPrompt(context);

      if (passwordVerified == null || passwordVerified == false) {
        return;
      }
    }

    setState(() {
      _ignoreStop = true;
      _ending = true;
    });

    try {
      // Capture the last route/location BEFORE TimerService.cancelTimer()
      // stops continuous route recording.
      final finalPayload = await TimerService.instance.getLocationData();
      _currentLocation = finalPayload.currentLocation ?? _currentLocation;
      _polyline = finalPayload.polyline;

      _audioPath = await _audio.stop();
      if (_audioPath != null) {
        try {
          await _exportAudio(automatic: true);
        } catch (error, stack) {
          AppLogger.log.warning('Emergency audio export failed.', error, stack);
        }
      }

      bool sirenIsOn = _siren.isPlaying;
      await _siren.stop();
      _locationPoller?.cancel();

      final timer = TimerService.instance.activeTimer;

      // cancelTimer() is the existing reset/cancel operation and returns the
      // application to the non-active timer state.
      await TimerService.instance.cancelTimer(passwordVerified: passwordVerified, recordHistory: false);

      await HistoryService.insertHistoryRecord(
        TimerExpiredEvent(
          timerName: timer.config.name,
          startedAt: DateTime.fromMillisecondsSinceEpoch(timer.run.startedAtMs),
          endedAt: DateTime.now(),
          location: _currentLocation == null
              ? null
              : <String, dynamic>{'latitude': _currentLocation!.latitude, 'longitude': _currentLocation!.longitude},
          polyline: _polyline,
          sms: _rows.where((row) => row.target.kind == EmergencyDestinationKind.sms).map(_historyEntry).toList(),
          emails: _rows.where((row) => row.target.kind == EmergencyDestinationKind.email).map(_historyEntry).toList(),
          channels: _rows.where((row) => row.target.kind == EmergencyDestinationKind.integration).map(_historyEntry).toList(),
          alarmTriggered: sirenIsOn || _sirenDismissed,
          audioRecorded: _audioPath != null,
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(AppRoute(page: HomeScreen(), transition: AppRouteTransitionType.slideRight), (route) => false);
    } catch (e, st) {
      AppLogger.log.severe('Failed to stop emergency cleanly.', e, st);

      // The emergency should still be stoppable even if history/audio export
      // has a secondary failure.
      if (mounted) {
        setState(() {
          _ignoreStop = false;
          _ending = false;
        });
      }
    }
  }

  /// Releases subscriptions, timers, and emergency service resources.
  ///
  /// Network status listeners and the location polling timer are cancelled,
  /// while the siren and audio services are disposed to release any resources
  /// they own.
  @override
  void dispose() {
    _networkSubscription?.cancel();
    _locationPoller?.cancel();
    _siren.dispose();
    _audio.dispose();
    super.dispose();
  }

  /// Builds the status indicator and optional retry control for a dispatch row.
  ///
  /// The visual indicator reflects whether the destination is pending,
  /// currently sending, successfully sent, or failed. Failed destinations
  /// expose a retry action when retrying is currently permitted.
  Widget _buildDispatchStatus(BuildContext context, DispatchRow row) {
    final scheme = Theme.of(context).colorScheme;
    final local = AppLocalizations.of(context)!;

    final Widget status = switch (row.state) {
      DispatchState.pending => Icon(LucideIcons.clock3, size: 17, color: scheme.onSurface),
      DispatchState.sending => SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
      DispatchState.sent => Icon(LucideIcons.check, size: 17, color: scheme.tertiary),
      DispatchState.failed => Icon(LucideIcons.x, size: 17, color: scheme.error),
    };

    final canRetry = !_ending && (!row.target.requiresInternet || _online);

    return Row(
      children: [
        if (row.state == DispatchState.failed) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: local.translate("emergency_active.actions.retry"),
            icon: Icon(LucideIcons.refreshCw, size: 17, color: scheme.error),
            onPressed: canRetry
                ? () async {
                    setState(() {
                      row.state = DispatchState.pending;
                    });
                    await _dispatchRow(row);
                  }
                : null,
          ),
        ] else ...[
          status,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;
    bool passwordProtected = timer.config.passwordProtected;

    Color warning = scheme.error.withGreen(((scheme.error.g * 255.0).round().clamp(0, 255) + 80));

    return PopScope(
      canPop: false,
      child: ScreenBase(
        header: AppHeader(
          title: local.translate("emergency_active.title"),
          right: CircleIconButton(
            icon: _online ? LucideIcons.globe : LucideIcons.globeOff,
            foreground: _online ? scheme.error : warning,
            background: scheme.surface,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: EllipticalGradient(
                      colors: [_online ? scheme.error.withAlpha(38) : warning.withAlpha(38), Colors.transparent],
                      stops: const [0.0, 1],
                      ellipseRelativeCenter: const Offset(0.5, 0),
                      ellipseScale: const Scale(widthFactor: 0.45, heightFactor: 1.5),
                      backgroundColor: scheme.surface,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl),
                    child: Column(
                      children: [
                        if (_isLoading) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Padding(
                            padding: EdgeInsets.only(top: AppSpacing.lg),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
                            ),
                          ),
                        ] else ...[
                          AppCard(
                            color: _online ? scheme.error.withAlpha(26) : warning.withAlpha(26),
                            borderColor: _online ? scheme.error.withAlpha(89) : warning.withAlpha(89),
                            child: AppRow(
                              padding: EdgeInsets.zero,
                              title: _online ? local.translate("emergency_active.alert") : local.translate("emergency_active.network"),
                              subtitle: _online ? local.translate("emergency_active.mode") : local.translate("emergency_active.unsent"),
                              icon: _online ? LucideIcons.triangleAlert : LucideIcons.triangleDashed,
                              iconColor: _online ? scheme.onError : scheme.onSurface,
                              iconSize: 24,
                              iconBackground: _online ? scheme.error : warning,
                              trailing: (_siren.isPlaying) ? Icon(LucideIcons.volume2, size: 20, color: _online ? scheme.error : warning) : null,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          if (_audioUnavailable) ...[
                            AppCard(
                              color: scheme.surfaceContainer.withAlpha(150),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.micOff, size: 18, color: scheme.error),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: Text(local.translate("emergency_active.audio.permission"), style: AppText.caption(scheme))),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ] else if (_audio.path != null) ...[
                            AppCard(
                              color: scheme.surfaceContainer.withAlpha(150),
                              child: Pressable(
                                onTap: _exportAudio,
                                child: AppRow(
                                  padding: EdgeInsets.zero,
                                  title: local.translate("emergency_active.audio.title"),
                                  subtitle: _audio.isRecording
                                      ? local.translate("emergency_active.audio.running")
                                      : local.translate("emergency_active.audio.stopped"),
                                  icon: _audio.isRecording ? LucideIcons.mic : LucideIcons.micOff,
                                  iconColor: scheme.tertiary,
                                  iconBackground: scheme.tertiary.withAlpha(38),
                                  trailing: Icon(LucideIcons.download, size: 18, color: scheme.tertiary),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          if (timer.config.locationSharingEnabled || timer.config.routeSharingEnabled) ...[
                            EmergencyRouteTile(
                              route: _route.isNotEmpty ? _route : (_currentLocation == null ? const [] : [_currentLocation!]),
                              onRouteChanged: _handleRouteChanged,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          SectionTitle(local.translate("emergency_active.dispatch.title")),
                          AppCard(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                for (int i = 0; i < _rows.length; i++) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(AppRadius.sm),
                                          ),
                                          child: Icon(
                                            switch (_rows[i].target.kind) {
                                              EmergencyDestinationKind.sms => LucideIcons.messageSquareMore,
                                              EmergencyDestinationKind.email => LucideIcons.mail,
                                              EmergencyDestinationKind.integration => switch (_rows[i].target.title) {
                                                "Discord" => Icons.discord,
                                                "Telegram" => FontAwesomeIcons.telegram.data,
                                                _ => LucideIcons.webhook,
                                              },
                                            },
                                            size: 18,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_rows[i].target.title, style: AppText.bodySm(scheme)),
                                              Text(
                                                _rows[i].target.destination,
                                                style: AppText.micro(scheme),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (!_online && _rows[i].target.requiresInternet && _rows[i].state != DispatchState.sent)
                                                Text(
                                                  local.translate("emergency_active.dispatch.pending"),
                                                  style: AppText.micro(scheme).copyWith(color: warning),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (_rows[i].locationUpdateDirty &&
                                            _rows[i].target.allowLocation &&
                                            !_ending &&
                                            (!_rows[i].target.requiresInternet || _online))
                                          IconButton(
                                            tooltip: local.translate("emergency_active.actions.location"),
                                            icon: _rows[i].sendingLocationUpdate
                                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                                : Icon(LucideIcons.mapPinned, size: 24, color: scheme.primary),
                                            onPressed: () => _dispatchLocationUpdate(_rows[i]),
                                          ),
                                        _buildDispatchStatus(context, _rows[i]),
                                      ],
                                    ),
                                  ),
                                  if (i < _rows.length - 1) Divider(height: 1, color: scheme.outlineVariant),
                                ],
                              ],
                            ),
                          ),

                          if (_rows.isEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            AppCard(
                              child: Text(
                                local.translate("emergency_active.dispatch.none"),
                                style: AppText.caption(scheme),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          const SizedBox(height: 120),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!_isLoading) ...[
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.surface, scheme.surface.withAlpha(64), scheme.surface.withAlpha(0)],
                      stops: const [0.3, 0.75, 1],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          passwordProtected
                              ? local.translate("active_monitoring.pin_requirement.on")
                              : local.translate("active_monitoring.pin_requirement.off"),
                          style: AppText.micro(scheme),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: PrimaryButton(
                              onPressed: () async {
                                if (_siren.isPlaying) {
                                  await _siren.stop();
                                  if (!mounted) return;
                                  setState(() {
                                    _sirenDismissed = true;
                                  });
                                } else {
                                  final volume = await _adapters.volumeReader();
                                  await _siren.start(volumePercent: volume);
                                  setState(() {});
                                }
                              },
                              icon: (_siren.isPlaying) ? LucideIcons.megaphone : LucideIcons.megaphoneOff,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: IgnorePointer(
                              ignoring: _ignoreStop,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPress: _stopEmergency,
                                child: PrimaryButton(
                                  icon: LucideIcons.shieldBan,
                                  label: local.translate("emergency_active.actions.stop"),
                                  color: ButtonColor.warning,
                                  onPressed: () {},
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
