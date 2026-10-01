import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:still_alive/data/all.dart';
import 'package:still_alive/services/location_service.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/views/widgets/tile_map_viewer.dart';

import '../../../../widgets/primitives.dart';
import 'emergency_helpers.dart';

enum DispatchState { pending, sending, sent, failed }

/// Stores the current dispatch state for one configured emergency destination.
///
/// A row represents an independently addressable destination such as an SMS
/// number, email address, or integration channel. In addition to the primary
/// dispatch state, the row tracks whether a newer location revision is waiting
/// to be sent and whether a location-update request is currently in progress.
class DispatchRow {
  DispatchRow({required this.target});

  final EmergencyDispatchTarget target;

  DispatchState state = DispatchState.pending;
  Object? error;

  bool locationUpdateDirty = false;
  bool sendingLocationUpdate = false;
  int lastLocationRevisionSent = -1;
}

/// Displays the live emergency route and, when available, the current
/// location on a map.
///
/// The widget listens to [LocationService]'s route stream so the displayed
/// polyline remains synchronized with GPS updates while the emergency is
/// active. It also exposes a small live-status indicator and an elapsed
/// update counter to communicate that location tracking is still running.
///
/// Route changes are forwarded to the parent through [onRouteChanged], which
/// allows the emergency screen to mark affected destinations as requiring a
/// new location update.
class EmergencyRouteTile extends StatefulWidget {
  const EmergencyRouteTile({required this.route, required this.onRouteChanged, super.key});

  final List<LatLng> route;
  final ValueChanged<List<LatLng>> onRouteChanged;

  @override
  State<EmergencyRouteTile> createState() => _EmergencyRouteTileState();
}

/// State implementation for [EmergencyRouteTile].
///
/// This state subscribes to the live route stream and owns the animation and
/// periodic counter used by the route-tracking UI. The subscription and
/// periodic timer are cancelled and the animation controller is disposed when
/// the widget leaves the tree.
class _EmergencyRouteTileState extends State<EmergencyRouteTile> with SingleTickerProviderStateMixin {
  StreamSubscription<List<LatLng>>? _subscription;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

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

    _subscription = LocationService.instance.routeStream.listen((route) {
      if (!mounted) return;

      _counter.value = 0;
      widget.onRouteChanged(route);
    });
  }

  @override
  void didUpdateWidget(covariant EmergencyRouteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route.length < 2) {
      _counter.value = 0;
    }
  }

  @override
  void dispose() {
    _counter.dispose();
    _pulseController.dispose();
    _subscription?.cancel();
    _counterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;

    return AppCard(
      color: scheme.surfaceContainer.withAlpha(150),
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
                    ' ${TimerService.formatDuration(Duration(seconds: timer.config.locationCollectionIntervalSecs?.toInt() ?? 10))} '
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
            child: TileMapViewer(route: widget.route, height: 200, showEndMarker: true),
          ),
        ],
      ),
    );
  }
}
