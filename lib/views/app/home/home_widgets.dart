import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';

import 'timer/config/timer_config.dart';
import '../../../main.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';
import '../../widgets/countdown_ring.dart';

/// Displays the active timer's current countdown and progress.
///
/// The countdown is refreshed once per second while an active timer is
/// running. The widget listens to [TimerService] for timer changes and
/// temporarily stops its periodic UI updates when another route is pushed
/// on top of the current route.
///
/// When the active timer reaches its expiration time, the expiration is
/// scheduled to run after the current frame so that the timer state is not
/// modified directly during the widget's build phase.
///
/// Tapping the countdown navigates to the existing timer configuration screen
/// for the currently active timer.
class TimerCountdownRing extends StatefulWidget {
  const TimerCountdownRing({super.key});

  @override
  State<TimerCountdownRing> createState() => _TimerCountdownRingState();
}

/// State implementation for [TimerCountdownRing].
///
/// Maintains the periodic timer responsible for refreshing the countdown UI
/// and observes route changes through [RouteAware] to pause and resume those
/// updates when navigating between routes.
///
/// The state also monitors the active timer's expiration time and schedules
/// [TimerService.timerHasExpired] after the current frame when the timer
/// reaches its expiration.
class _TimerCountdownRingState extends State<TimerCountdownRing>
    with RouteAware {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();

    TimerService.instance.addListener(_configPeriodicTimer);

    _configPeriodicTimer();
  }

  void _configPeriodicTimer() async {
    bool active = await TimerService.instance.hasActiveTimer;

    if (active) {
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      setState(() {});
      _uiTimer?.cancel();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _uiTimer?.cancel();
    super.didPushNext();
  }

  @override
  void didPopNext() async {
    setState(() {});
    _configPeriodicTimer();
    super.didPopNext();
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_configPeriodicTimer);

    _uiTimer?.cancel();

    routeObserver.unsubscribe(this);
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

  bool _expirationScheduled = false;

  void _checkTimerExpiration() {
    final timer = TimerService.instance.activeTimer;

    if (timer.run.state != TimerState.running || _expirationScheduled) {
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (now < timer.run.expiresAtMs) {
      return;
    }

    _expirationScheduled = true;

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
    bool timerIsActive = (timer.run.state == TimerState.running);

    Duration remaining;
    double progress = 1.0;
    if (timerIsActive) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      remaining = timer.remaining();

      progress =
          ((now - timer.run.startedAtMs) /
                  (timer.run.expiresAtMs - timer.run.startedAtMs))
              .clamp(0.0, 1.0);
    } else {
      remaining = Duration(seconds: timer.config.durationSecs);
    }

    _checkTimerExpiration();

    return Column(
      children: [
        Center(
          child: FutureBuilder<bool>(
            future: TimerService.instance.hasActiveTimer,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data!) {
                  return Pill(
                    label: local.translate("home.active"),
                    backColor: scheme.tertiary,
                  );
                } else {
                  return Pill(
                    label: local.translate("home.inactive"),
                    backColor: scheme.onSurfaceVariant,
                  );
                }
              } else {
                return SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.tertiary),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CountdownRing(
          time: _formatDuration(remaining),
          label: timer.config.name,
          color: scheme.primary,
          progress: progress,
          caption: local.translate("home.tap_to_configure"),
          onTap: () => Navigator.of(context).push(
            AppRoute(
              page: TimerConfigScreen.existingTimer(
                timerKey: timer.key,
                timerData: timer.config,
              ),
              transition: AppRouteTransitionType.slideRight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Provides controls for starting, pausing, resuming, and cancelling the
/// active timer.
///
/// The controls displayed by this widget depend on the current
/// [TimerState]:
///
/// * [TimerState.running] displays pause and cancel controls.
/// * [TimerState.paused] displays a resume control.
/// * Any other state displays a start control.
///
/// Operations that require authentication, such as pausing or cancelling a
/// password-protected timer, display a password prompt before the requested
/// action is performed.
///
/// While a timer operation is in progress, the controls are replaced with a
/// loading indicator to prevent additional actions from being triggered.
class TimerControls extends StatefulWidget {
  const TimerControls({super.key});

  @override
  State<TimerControls> createState() => _TimerControlsState();
}

/// State implementation for [TimerControls].
///
/// Listens to [TimerService] for changes to the active timer and rebuilds the
/// controls whenever the timer state changes.
///
/// Maintains a local loading state while asynchronous timer operations such
/// as starting, pausing, resuming, or cancelling are being performed.
class _TimerControlsState extends State<TimerControls> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    TimerService.instance.addListener(_onTimerChanged);
  }

  void _onTimerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void setLoading(bool value) {
    if (mounted) {
      setState(() => _isLoading = value);
    }
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_onTimerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;
    TimerState currentState = timer.run.state;

    if (_isLoading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
      );
    }

    switch (currentState) {
      case TimerState.running:
        return Row(
          children: [
            SizedBox(
              width: 64,
              child: PrimaryButton(
                icon: LucideIcons.pause,
                color: ButtonColor.tertiary,
                onPressed: () async {
                  setLoading(true);
                  bool? passwordVerified = false;
                  if (timer.config.passwordProtected) {
                    passwordVerified = await TimerService.instance
                        .showPasswordPrompt(context);
                  }
                  if (passwordVerified != null) {
                    await TimerService.instance.pauseTimer(
                      passwordVerified: passwordVerified,
                    );
                  }
                  setLoading(false);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: PrimaryButton(
                label: local.translate("home.buttons.cancel"),
                icon: LucideIcons.ban,
                onPressed: () async {
                  setLoading(true);
                  bool? passwordVerified = false;
                  if (timer.config.passwordProtected) {
                    passwordVerified = await TimerService.instance
                        .showPasswordPrompt(context);
                  }
                  if (passwordVerified != null) {
                    await TimerService.instance.cancelTimer(
                      passwordVerified: passwordVerified,
                    );
                  }
                  setLoading(false);
                },
              ),
            ),
          ],
        );

      case TimerState.paused:
        return PrimaryButton(
          label: local.translate("home.buttons.resume"),
          icon: LucideIcons.play,
          onPressed: () async {
            setLoading(true);
            await TimerService.instance.resumeTimer();
            setLoading(false);
          },
        );

      default:
        return PrimaryButton(
          label: local.translate("home.buttons.start"),
          icon: LucideIcons.play,
          onPressed: () async {
            setLoading(true);
            await TimerService.instance.startTimer();
            setLoading(false);
          },
        );
    }
  }
}
