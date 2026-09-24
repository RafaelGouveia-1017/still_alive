import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/countdown_ring.dart';

/// Displays the remaining duration of the active timer's pre-alert warning
/// period as an animated countdown ring.
///
/// The widget periodically rebuilds its UI so that the displayed duration is
/// updated approximately once per second. The initial duration is retained as
/// the total depletion period used by [CountdownRing] to render the progress
/// animation.
///
/// When the warning period reaches zero, the widget schedules the timer
/// expiration handling after the current frame. This transitions the active
/// timer into its expired state and allows the application's emergency flow to
/// take over.
///
/// The periodic UI timer is cancelled when the widget is disposed.
class WarningCountdownRing extends StatefulWidget {
  const WarningCountdownRing({super.key});

  @override
  State<WarningCountdownRing> createState() => _WarningCountdownRingState();
}

/// State implementation for [WarningCountdownRing].
///
/// This state owns the periodic timer used to refresh the countdown display
/// while the widget remains mounted. It also stores the initial warning
/// duration so that [CountdownRing] can calculate its depletion animation.
///
/// When the remaining duration reaches zero, the state schedules
/// [TimerService.timerHasExpired] to run after the current frame. Deferring the
/// expiration call prevents the timer transition from occurring directly
/// during the widget's build phase.
///
/// The periodic timer is cancelled during disposal to avoid callbacks after
/// the widget has been removed from the widget tree.
class _WarningCountdownRingState extends State<WarningCountdownRing> {
  Timer? _uiTimer;

  late Duration _depleteOver;

  @override
  void initState() {
    super.initState();

    _depleteOver = TimerService.instance.activeTimer.remaining();

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
    final parts = <String>[];

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0) {
      parts.add(minutes.toString());
    }

    if (seconds >= 0) {
      parts.add('${((minutes > 0)) ? seconds.toString().padLeft(2, '0') : seconds}');
    }

    if (parts.isEmpty) {
      return '0';
    }

    return parts.join(':');
  }

  void _checkWarningExpiration(Duration duration) {
    if (duration != Duration.zero) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TimerService.instance.timerHasExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;

    Duration remaining = timer.remaining();

    _checkWarningExpiration(remaining);

    Color warning = scheme.error.withGreen(((scheme.error.g * 255.0).round().clamp(0, 255) + 80));

    return CountdownRing(
      time: _formatDuration(remaining),
      label: switch (remaining.inSeconds) {
        >= 60 => local.translate("pre_alert_warning.labels.time_left"),
        1 => local.translate("pre_alert_warning.labels.second_left"),
        _ => local.translate("pre_alert_warning.labels.seconds_left"),
      },
      labelBottom: true,
      color: warning,
      diameter: MediaQuery.of(context).size.width - 200,
      strokeWidth: 10,
      depleteOver: _depleteOver,
    );
  }
}

/// Displays an animated warning indicator for the pre-alert emergency state.
///
/// The badge combines a warning icon with a continuously pulsing scale and
/// expanding glow effect to visually indicate that the timer is approaching
/// its emergency state.
///
/// The animation runs continuously while the widget is mounted and is driven
/// by an [AnimationController] using this state object as its
/// [TickerProvider]. The controller is disposed when the widget is removed
/// from the widget tree.
class PulsingBadge extends StatefulWidget {
  const PulsingBadge({super.key});

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

/// State implementation for [PulsingBadge].
///
/// This state owns the [AnimationController] responsible for the badge's
/// repeating pulse animation. The controller drives both the scale of the
/// warning icon and the size and opacity of its surrounding glow.
///
/// [SingleTickerProviderStateMixin] supplies the ticker required by the
/// animation controller while keeping the widget lightweight because it only
/// requires a single animation ticker.
///
/// The animation controller is disposed when the state is removed from the
/// widget tree to release its ticker resources.
class _PulsingBadgeState extends State<PulsingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.pulse)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    Color warning = scheme.error.withGreen(((scheme.error.g * 255.0).round().clamp(0, 255) + 80));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1 + 0.08 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        final ringSpread = 18 * t;
        final ringOpacity = (1 - t) * 0.45;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: warning.withValues(alpha: ringOpacity),
                spreadRadius: ringSpread,
              ),
            ],
          ),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: warning.withAlpha(38),
          shape: BoxShape.circle,
          border: Border.all(color: warning.withAlpha(102)),
        ),
        child: Icon(LucideIcons.triangleAlert, size: 40, color: warning),
      ),
    );
  }
}
