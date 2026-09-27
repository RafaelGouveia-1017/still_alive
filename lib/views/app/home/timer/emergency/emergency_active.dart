import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// emergency session, including dispatch progress, the latest route and
/// location, audio-recording state, network connectivity, siren state, and
/// the revision number used to determine whether a destination has received
/// the newest location information.
///
/// It also coordinates the lifecycle of the emergency-specific services:
/// [EmergencyDispatchService], [EmergencyAudioService],
/// [EmergencySirenService], and [EmergencyNetworkMonitor]. Resources owned by
/// these services and by this state are released in [dispose].
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
  bool _audioUnavailable = false;
  bool _sirenDismissed = false;
  String? _audioPath;
  int _locationRevision = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _adapters = EmergencyAdapters();
    _dispatcher = EmergencyDispatchService(_adapters);
    _audio = EmergencyAudioService();
    _siren = EmergencySirenService();
    _network = EmergencyNetworkMonitor();

    _initialize();
  }

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

      _networkSubscription = _network.statusStream.listen((status) {
        _handleNetworkStatus(status);
      });

      if (timer.config.locationSharingEnabled && !timer.config.routeSharingEnabled) {
        final interval = timer.config.locationCollectionIntervalSecs?.toInt() ?? 10;
        _locationPoller = Timer.periodic(Duration(seconds: interval.clamp(1, 3600).toInt()), (_) => _refreshSingleLocation());
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!_online) {
        await _enterOfflineState();
      } else {
        await _dispatchAllPending();
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

  Future<void> _refreshSingleLocation() async {
    if (_ending || !mounted) return;

    try {
      final next = await LocationService.instance.getCurrentLocation();
      if (_sameLocation(_currentLocation, next)) return;

      setState(() {
        _currentLocation = next;
        _locationRevision++;
        for (final row in _rows) {
          if (row.target.allowLocation) {
            row.locationUpdateDirty = row.lastLocationRevisionSent != _locationRevision;
          }
        }
      });
    } catch (error, stack) {
      AppLogger.log.warning('Unable to refresh emergency location.', error, stack);
    }
  }

  void _handleRouteChanged(List<LatLng> route) {
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

    // Keep the encoded route in sync with the live route stream so a manual
    // destination update contains the latest route, not the initial snapshot.
    unawaited(_reloadEncodedRoute());
  }

  Future<void> _reloadEncodedRoute() async {
    if (!_route.isNotEmpty) return;
    try {
      final encoded = await LocationService.instance.loadEncodedRoute();
      if (!mounted || _ending) return;
      setState(() {
        _polyline = encoded;
      });
    } catch (error, stack) {
      AppLogger.log.warning('Unable to refresh encoded emergency route.', error, stack);
    }
  }

  bool _sameLocation(LatLng? a, LatLng b) {
    if (a == null) return false;
    return a.latitude == b.latitude && a.longitude == b.longitude;
  }

  Future<void> _handleNetworkStatus(InternetStatus status) async {
    final connected = status == InternetStatus.connected;
    if (!connected) {
      await _enterOfflineState();
      return;
    }

    if (!mounted) return;
    setState(() {
      _online = true;
    });
  }

  Future<void> _enterOfflineState() async {
    if (_ending) return;

    if (mounted) {
      setState(() {
        _online = false;
        for (final row in _rows) {
          if (row.state != DispatchState.sent) {
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
      setState(() {});
    } catch (error, stack) {
      AppLogger.log.warning('Could not play emergency siren.', error, stack);
    }
  }

  Future<void> _dispatchAllPending() async {
    if (!_online || _ending) return;

    for (final row in _rows) {
      if (_ending || !_online) break;
      if (row.state != DispatchState.pending) continue;
      await _dispatchRow(row);
    }
  }

  Future<void> _dispatchRow(DispatchRow row) async {
    if (_ending || !_online) return;

    final sendRevision = _locationRevision;

    setState(() {
      row.state = DispatchState.sending;
      row.error = null;
    });

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

    // A network transition during an in-flight helper call is treated as
    // pending, not successful. The destination can be retried deliberately.
    if (!_online) {
      setState(() {
        row.state = DispatchState.pending;
        row.error = null;
      });
      return;
    }

    setState(() {
      row.state = result.state == EmergencyDispatchState.sent ? DispatchState.sent : DispatchState.failed;
      row.error = result.error;
      if (result.state == EmergencyDispatchState.sent) {
        row.lastLocationRevisionSent = sendRevision;
        row.locationUpdateDirty = row.target.allowLocation && _locationRevision != sendRevision;
      }
    });
  }

  Future<void> _dispatchLocationUpdate(DispatchRow row) async {
    if (_ending || !_online || !row.target.allowLocation) return;

    final sendRevision = _locationRevision;

    setState(() {
      row.sendingLocationUpdate = true;
      row.error = null;
    });

    try {
      final payload = EmergencyLocationPayload(currentLocation: _currentLocation, polyline: _polyline);

      final message = _dispatcher.buildLocationUpdate(target: row.target, payload: payload);

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
    } catch (error, stack) {
      AppLogger.log.warning('Emergency location update failed.', error, stack);

      if (!mounted) return;
      setState(() {
        row.sendingLocationUpdate = false;
        row.locationUpdateDirty = true;
        row.error = error;
      });
    }
  }

  Future<void> _exportAudio({bool automatic = false}) async {
    if (_audio.path == null) return;

    final uri = await _audio.exportToUserLocation(sourcePath: _audio.path);

    if (automatic && uri == null) {
      AppLogger.log.warning('Emergency audio export was cancelled or failed.');
    }
  }

  Map<String, dynamic> _historyEntry(DispatchRow row) {
    final state = switch (row.state) {
      DispatchState.pending => EmergencyDispatchState.pending,
      DispatchState.sending => EmergencyDispatchState.pending,
      DispatchState.sent => EmergencyDispatchState.sent,
      DispatchState.failed => EmergencyDispatchState.failed,
    };

    return _dispatcher.toHistoryEntry(row.target, state, error: row.error);
  }

  Future<void> _stopEmergency() async {
    if (_ignoreStop || _ending) return;

    final passwordProtected = TimerService.instance.activeTimer.config.passwordProtected;

    bool? passwordVerified = false;
    if (passwordProtected) {
      passwordVerified = await TimerService.instance.showPasswordPrompt(context);
    }

    if (passwordVerified == null) {
      return;
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

      // Required by the UX: stopping the emergency automatically starts an
      // export flow to a location chosen by the user.
      if (_audioPath != null) {
        await _exportAudio(automatic: true);
      }

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
          alarmTriggered: _siren.isPlaying || _sirenDismissed,
          audioRecorded: _audioPath != null,
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(AppRoute(page: HomeScreen(), transition: AppRouteTransitionType.slideRight), (route) => false);
    } catch (error, stack) {
      AppLogger.log.severe('Failed to stop emergency cleanly.', error, stack);

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

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _locationPoller?.cancel();
    _siren.dispose();
    _audio.dispose();
    super.dispose();
  }

  Widget _buildDispatchStatus(BuildContext context, DispatchRow row) {
    final scheme = Theme.of(context).colorScheme;

    final Widget status = switch (row.state) {
      DispatchState.pending => Icon(LucideIcons.clock3, size: 17, color: scheme.onSurfaceVariant),
      DispatchState.sending => SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
      DispatchState.sent => Icon(LucideIcons.check, size: 17, color: scheme.tertiary),
      DispatchState.failed => Icon(LucideIcons.x, size: 17, color: scheme.error),
    };

    return Row(
      children: [
        status,
        if (row.state == DispatchState.failed) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Retry',
            icon: Icon(LucideIcons.refreshCw, size: 17, color: scheme.error),
            onPressed: _online && !_ending
                ? () async {
                    setState(() {
                      row.state = DispatchState.pending;
                    });
                    await _dispatchRow(row);
                  }
                : null,
          ),
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

    return ScreenBase(
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
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(color: _online ? scheme.error : warning, borderRadius: BorderRadius.circular(AppRadius.lg)),
                                child: Icon(
                                  _online ? LucideIcons.triangleAlert : LucideIcons.triangleDashed,
                                  size: 24,
                                  color: _online ? scheme.onError : scheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _online ? local.translate("emergency_active.alert") : local.translate("emergency_active.network"),
                                      style: AppText.title(scheme),
                                    ),
                                    Text(
                                      _online ? local.translate("emergency_active.mode") : local.translate("emergency_active.unsent"),
                                      style: AppText.caption(scheme),
                                    ),
                                  ],
                                ),
                              ),
                              if (_siren.isPlaying) Icon(LucideIcons.volume2, size: 20, color: _online ? scheme.error : warning),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        if (timer.config.locationSharingEnabled || timer.config.routeSharingEnabled) ...[
                          EmergencyRouteTile(
                            route: _route.isNotEmpty ? _route : (_currentLocation == null ? const [] : [_currentLocation!]),
                            onRouteChanged: _handleRouteChanged,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        if (_audioUnavailable) ...[
                          AppCard(
                            color: scheme.error.withAlpha(18),
                            borderColor: scheme.error.withAlpha(70),
                            child: Row(
                              children: [
                                Icon(LucideIcons.micOff, size: 18, color: scheme.error),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(local.translate("emergency_active.audio.permission"), style: AppText.caption(scheme))),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        if (_audio.path != null) ...[
                          AppCard(
                            child: AppRow(
                              padding: EdgeInsets.zero,
                              title: local.translate("emergency_active.audio.title"),
                              subtitle: _audio.isRecording
                                  ? local.translate("emergency_active.audio.running")
                                  : local.translate("emergency_active.audio.stopped"),
                              icon: LucideIcons.mic,
                              iconSize: 20,
                              iconColor: scheme.error,
                              trailing: IconButton(
                                tooltip: 'Export',
                                icon: Icon(LucideIcons.download, size: 18, color: scheme.primary),
                                onPressed: () => _exportAudio(),
                              ),
                            ),
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
                                            if (!_online && _rows[i].state != DispatchState.sent)
                                              Text(
                                                local.translate("emergency_active.dispatch.pending"),
                                                style: AppText.micro(scheme).copyWith(color: warning),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (_rows[i].locationUpdateDirty && _rows[i].target.allowLocation)
                                        IconButton(
                                          tooltip: local.translate("emergency_active.actions.location"),
                                          icon: _rows[i].sendingLocationUpdate
                                              ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                                              : Icon(LucideIcons.mapPinned, size: 17, color: scheme.primary),
                                          onPressed: _online && !_ending ? () => _dispatchLocationUpdate(_rows[i]) : null,
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
      ),
    );
  }
}
