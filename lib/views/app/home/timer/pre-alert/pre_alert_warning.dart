import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/views/app/home/home.dart';
import 'package:still_alive/views/widgets/elliptical_gradient.dart';

import 'pre_alert_widgets.dart';
import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// Displays the warning screen shown during the timer's pre-alert period.
///
/// This screen gives the user an opportunity to safely cancel the active timer
/// before the emergency state is reached. It presents the remaining countdown,
/// the location and audio-sharing configuration, and the configured emergency
/// destinations such as contacts, custom recipients, and integrations.
///
/// If the timer is password protected, cancelling the timer requires successful
/// password verification. The screen also provides an explicit action to skip
/// the remaining warning period and immediately trigger the emergency flow.
///
/// The screen uses an immersive system UI mode and replaces the existing
/// navigation stack when transitioning either back to [HomeScreen] after a
/// successful cancellation or to the emergency screen when the timer expires.
class PreAlertWarningScreen extends StatefulWidget {
  const PreAlertWarningScreen({super.key});

  @override
  State<PreAlertWarningScreen> createState() => _PreAlertWarningScreenState();
}

/// State implementation for [PreAlertWarningScreen].
///
/// This state manages transient UI state for the pre-alert warning screen,
/// including temporarily disabling the emergency trigger controls after they
/// have been activated.
///
/// The state also configures the application for immersive system UI while the
/// warning screen is displayed. Timer state and configuration data are obtained
/// from [TimerService] rather than being stored locally, ensuring that the
/// warning screen reflects the application's active timer.
class _PreAlertWarningScreenState extends State<PreAlertWarningScreen> {
  bool _ignore = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    ActiveTimer timer = TimerService.instance.activeTimer;
    bool passwordProtected = timer.config.passwordProtected;

    Color warning = scheme.error.withGreen(((scheme.error.g * 255.0).round().clamp(0, 255) + 80));

    return ScreenBase(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: EllipticalGradient(
                    colors: [warning.withAlpha(38), Colors.transparent],
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
                  padding: const EdgeInsets.fromLTRB(0, 40, 0, AppSpacing.xl),
                  child: Column(
                    children: [
                      PulsingBadge(),
                      const SizedBox(height: AppSpacing.xl),

                      Pill(label: local.translate("pre_alert_warning.title"), backColor: warning),
                      const SizedBox(height: AppSpacing.md),

                      Text(local.translate("pre_alert_warning.question"), style: AppText.h2(scheme), textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.sm),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          local.translate("pre_alert_warning.message"),
                          textAlign: TextAlign.center,
                          style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      WarningCountdownRing(),
                      const SizedBox(height: AppSpacing.xl),

                      Builder(
                        builder: (context) {
                          String location = (timer.config.locationSharingEnabled)
                              ? (timer.config.routeSharingEnabled)
                                    ? local.translate("pre_alert_warning.location.route")
                                    : local.translate("pre_alert_warning.location.true")
                              : local.translate("pre_alert_warning.location.false");

                          String audio = (timer.config.audioRecordingEnabled)
                              ? local.translate("pre_alert_warning.audio.true")
                              : local.translate("pre_alert_warning.audio.false");

                          return AppCard(
                            color: warning.withAlpha(15),
                            borderColor: warning.withAlpha(51),
                            child: Row(
                              children: [
                                Icon(LucideIcons.triangleAlert, size: 16, color: warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text("$location\n$audio", style: AppText.caption(scheme).copyWith(color: scheme.onSurface)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      Builder(
                        builder: (context) {
                          List<String> destinations = [];

                          int contacts = timer.config.contacts.length;
                          int custom = timer.config.customSms.length + timer.config.customEmail.length;
                          int integrations = timer.config.integrations.discord.accounts.length + timer.config.integrations.telegram.accounts.length;

                          if (contacts > 0) {
                            destinations.add(
                              "• $contacts ${local.translate((contacts == 1) ? "active_monitoring.destinations.contact.0" : "active_monitoring.destinations.contact.1")}",
                            );
                          }

                          if (custom > 0) {
                            destinations.add(
                              "• $custom ${local.translate((custom == 1) ? "active_monitoring.destinations.custom.0" : "active_monitoring.destinations.custom.1")}",
                            );
                          }

                          if (integrations > 0) {
                            destinations.add(
                              "• $integrations ${local.translate((integrations == 1) ? "active_monitoring.destinations.integrations.0" : "active_monitoring.destinations.integrations.1")}",
                            );
                          }

                          return AppCard(
                            color: warning.withAlpha(15),
                            borderColor: warning.withAlpha(51),
                            child: Row(
                              children: [
                                Icon(LucideIcons.triangleAlert, size: 16, color: warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                                        child: Text(
                                          local.translate("pre_alert_warning.destinations.title"),
                                          style: AppText.caption(scheme).copyWith(color: scheme.onSurface),
                                        ),
                                      ),
                                      Text(destinations.join('\n'), style: AppText.caption(scheme).copyWith(color: scheme.onSurface)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 150),
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
                      (passwordProtected)
                          ? local.translate("active_monitoring.pin_requirement.on")
                          : local.translate("active_monitoring.pin_requirement.off"),
                      style: AppText.micro(scheme),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  IgnorePointer(
                    ignoring: _ignore,
                    child: PrimaryButton(
                      icon: LucideIcons.shieldCheck,
                      label: local.translate("pre_alert_warning.actions.safe_cancel"),
                      color: ButtonColor.tertiary,
                      onPressed: () async {
                        setState(() => _ignore = true);

                        bool? passwordVerified = false;

                        if (passwordProtected) {
                          passwordVerified = await TimerService.instance.showPasswordPrompt(context);
                        }

                        if (passwordVerified != null) {
                          await TimerService.instance.cancelTimer(passwordVerified: passwordVerified);

                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).pushAndRemoveUntil(AppRoute(page: HomeScreen(), transition: AppRouteTransitionType.slideRight), (route) => false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  IgnorePointer(
                    ignoring: _ignore,
                    child: SizedBox(
                      width: 250,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            TimerService.instance.triggerTimerExpire();
                            _ignore = true;
                          });
                        },
                        child: Text(
                          local.translate("pre_alert_warning.actions.trigger_emergency"),
                          style: AppText.bodySm(scheme).copyWith(color: scheme.error),
                        ),
                      ),
                    ),
                  ),
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
