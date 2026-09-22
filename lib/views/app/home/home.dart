import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';
import 'package:still_alive/views/app/home/timer_selection.dart';

import 'quick_contacts.dart';
import 'home_widgets.dart';
import 'phone_status.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Displays the application's main home screen.
///
/// The home screen provides an overview of the currently selected timer,
/// including its countdown, phone status, available controls, and quick
/// contacts.
///
/// The screen header displays the application name and indicates whether an
/// active timer is currently protecting the device. It also provides access
/// to the timer selection screen.
///
/// The main content includes:
///
/// * [TimerCountdownRing] for displaying the active timer's countdown.
/// * [PhoneStatus] for displaying the number of configured contacts and
/// integrations.
/// * [TimerControls] for starting, pausing, resuming, or cancelling the
/// timer.
/// * [QuickContacts] for accessing configured emergency contacts.
///
/// The system UI is configured for edge-to-edge display when the screen is
/// initialized.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State implementation for [HomeScreen].
///
/// Configures the system UI for edge-to-edge display when the screen is
/// initialized and builds the home screen using the currently selected
/// timer's configuration.
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final timer = TimerService.instance.activeTimer;
    final timerData = timer.config;

    int contacts = timerData.contacts.length;
    int integrations = 0;
    TimerIntegration discord = timerData.integrations.discord;
    TimerIntegration telegram = timerData.integrations.telegram;
    if (discord.accounts.isNotEmpty) {
      integrations += discord.accounts.length;
    }
    if (telegram.accounts.isNotEmpty) {
      integrations += telegram.accounts.length;
    }

    return ScreenBase(
      bottomNavDestination: 'home',
      header: AppHeader(
        title: local.translate('app_name'),
        left: ListenableBuilder(
          listenable: TimerService.instance,
          builder: (context, child) {
            final state = TimerService.instance.timerRunCurrentState;

            return CircleIconButton(
              icon: switch (state) {
                TimerState.running || TimerState.paused => LucideIcons.shield,
                TimerState.warning => LucideIcons.shieldAlert,
                TimerState.expired => LucideIcons.shieldX,
                _ => LucideIcons.shieldOff,
              },
              foreground: switch (state) {
                TimerState.warning || TimerState.expired => scheme.error,
                _ => scheme.tertiary,
              },
              background: scheme.surface,
            );
          },
        ),
        right: CircleIconButton(
          icon: LucideIcons.clockPlus,
          onTap: () => Navigator.of(context).push(
            AppRoute(
              page: TimerSelectionScreen(),
              transition: AppRouteTransitionType.slideLeft,
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ListView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  TimerCountdownRing(),
                  const SizedBox(height: AppSpacing.xxl),
                  PhoneStatus(contacts: contacts, integrations: integrations),
                  const SizedBox(height: AppSpacing.xl),
                  TimerControls(),
                  const SizedBox(height: AppSpacing.xl),
                  QuickContacts(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
