import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/location_service.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/views/widgets/tile_map_viewer.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';
import '../../../../widgets/countdown_ring.dart';

/// Displays a live countdown for the currently active monitoring timer.
///
/// The countdown is updated once per second and is represented visually by a
/// progress ring whose progress corresponds to the elapsed portion of the
/// active timer's configured duration.
///
/// When the timer reaches its final seconds, the widget automatically returns
/// the application to the root route after the current frame has completed.
/// The countdown is also wrapped in a [Hero] animation so it can transition
/// smoothly from other timer-related screens.
class MonitoringCountdownRing extends StatefulWidget {
  const MonitoringCountdownRing({super.key});

  @override
  State<MonitoringCountdownRing> createState() => _MonitoringCountdownRingState();
}

/// State implementation for [MonitoringCountdownRing].
///
/// The state owns a one-second periodic timer that triggers rebuilds while the
/// widget is mounted. The timer is cancelled during disposal to prevent
/// callbacks from continuing after the widget has been removed.
class _MonitoringCountdownRingState extends State<MonitoringCountdownRing> {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();

    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _checkTimerExpiration(Duration duration) {
    if (duration.inSeconds > 10) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;

    double progress = 1.0;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    Duration remaining = timer.remaining();

    progress = ((now - timer.run.startedAtMs) / (timer.run.expiresAtMs - timer.run.startedAtMs)).clamp(0.0, 1.0);

    _checkTimerExpiration(remaining);

    return Hero(
      tag: 'timer-countdown',
      flightShuttleBuilder: (context, animation, direction, from, to) => AppHeader.flight(context, animation, direction, from, to),
      child: Column(
        children: [
          Center(
            child: Pill(label: local.translate("home.active"), backColor: scheme.tertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          CountdownRing(
            time: _formatDuration(remaining),
            label: timer.config.name,
            color: scheme.primary,
            progress: progress,
            diameter: MediaQuery.of(context).size.width - 90,
          ),
        ],
      ),
    );
  }
}

/// Manages the live route subscription, update counter, and status animation
/// for [MonitoringTileMap].
///
/// The state owns three resources that require explicit cleanup:
///
/// - An [AnimationController] for the live tracking pulse.
/// - A [StreamSubscription] for location route updates.
/// - A periodic [Timer] for updating the elapsed-time counter.
///
/// All three resources are released in [dispose].
class MonitoringTileMap extends StatefulWidget {
  const MonitoringTileMap({super.key});

  @override
  State<MonitoringTileMap> createState() => _MonitoringTileMapState();
}

/// State implementation for [MonitoringTileMap].
class _MonitoringTileMapState extends State<MonitoringTileMap> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  List<LatLng> _route = [];
  StreamSubscription<List<LatLng>>? _routeSubscription;

  Timer? _counterTimer;
  final ValueNotifier<int> _counter = ValueNotifier(0);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _counterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _counter.value++;
    });

    _route = LocationService.instance.currentRoute;

    _routeSubscription = LocationService.instance.routeStream.listen((route) {
      if (!mounted) return;
      setState(() {
        _route = route;
      });
      _counter.value = 0;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _routeSubscription?.cancel();
    _counterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;

    return AppCard(
      child: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _counter,
            builder: (context, counter, child) {
              return AppRow(
                padding: EdgeInsets.zero,
                title: local.translate("active_monitoring.location.location_tracking"),
                subtitle:
                    '${local.translate("active_monitoring.location.updated")}'
                    ' ${TimerService.formatDuration(Duration(seconds: counter))} '
                    '${local.translate("active_monitoring.location.ago")}'
                    ' ${TimerService.formatDuration(Duration(seconds: timer.config.locationCollectionIntervalSecs!))} '
                    '${local.translate("active_monitoring.location.interval")}',
                icon: LucideIcons.route,
                iconSize: 20,
                iconColor: scheme.tertiary,
                iconBackground: scheme.tertiary.withAlpha(38),
                trailing: Pill(
                  leading: FadeTransition(
                    opacity: _pulseAnimation,
                    child: CircleAvatar(radius: 3, backgroundColor: scheme.tertiary),
                  ),
                  label: local.translate("active_monitoring.location.live"),
                  backColor: scheme.tertiary,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: TileMapViewer(route: _route, height: 300, showEndMarker: false),
          ),
        ],
      ),
    );
  }
}

/// Provides the user controls for an active monitoring session.
///
/// The widget exposes actions for pausing and cancelling the active timer.
/// When the timer is configured to require password protection, the user must
/// successfully complete the password prompt before either action is
/// performed.
///
/// Both actions delegate the actual timer state changes to [TimerService].
/// Once the operation completes, the current monitoring screen is removed from
/// the navigation stack by popping the current route.
class MonitoringControls extends StatelessWidget {
  const MonitoringControls({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;
    bool passwordProtected = timer.config.passwordProtected;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: BlurActionTile(
                icon: LucideIcons.pause,
                label: local.translate("active_monitoring.actions.pause"),
                background: scheme.surfaceContainerHigh,
                border: scheme.outlineVariant,
                foreground: scheme.onSurface,
                onTap: () async {
                  bool? passwordVerified = false;

                  if (passwordProtected) {
                    passwordVerified = await TimerService.instance.showPasswordPrompt(context);
                  }

                  if (passwordVerified != null) {
                    await TimerService.instance.pauseTimer(passwordVerified: passwordVerified);

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: BlurActionTile(
                icon: LucideIcons.ban,
                label: local.translate("active_monitoring.actions.cancel"),
                background: scheme.error,
                border: scheme.errorContainer.withAlpha(77),
                foreground: scheme.onError,
                onTap: () async {
                  bool? passwordVerified = false;

                  if (passwordProtected) {
                    passwordVerified = await TimerService.instance.showPasswordPrompt(context);
                  }

                  if (passwordVerified != null) {
                    await TimerService.instance.cancelTimer(passwordVerified: passwordVerified);

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Center(
          child: Text(
            (passwordProtected) ? local.translate("active_monitoring.pin_requirement.on") : local.translate("active_monitoring.pin_requirement.off"),
            style: AppText.micro(scheme),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
