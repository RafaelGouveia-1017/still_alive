import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/contact_service.dart';
import 'package:still_alive/services/integration_service.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';

import 'monitoring_widgets.dart';
import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';
import '../../../../widgets/elliptical_gradient.dart';

/// Displays the active monitoring session and its current configuration.
///
/// This screen provides an overview of the currently running timer, including
/// its start and trigger times, configured notification destinations, optional
/// location sharing route, and custom message recipients.
///
/// The screen also exposes controls for pausing or cancelling the active
/// monitoring session through [MonitoringControls].
///
/// Contact information is loaded asynchronously from the device's contacts
/// database and displayed alongside the SMS and email destinations configured
/// for the timer. Integration destinations such as Discord and Telegram are
/// resolved through the application's integration services.
class ActiveMonitoringScreen extends StatefulWidget {
  const ActiveMonitoringScreen({super.key});

  @override
  State<ActiveMonitoringScreen> createState() => _ActiveMonitoringScreenState();
}

/// State implementation for [ActiveMonitoringScreen].
class _ActiveMonitoringScreenState extends State<ActiveMonitoringScreen> {
  late Map<int, Contact> _timerContacts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadInfo();
  }

  void loadInfo() async {
    setState(() {
      _isLoading = true;
    });

    ActiveTimer timer = TimerService.instance.activeTimer;

    Map<int, Contact> data = {};
    for (int i = 0; i < timer.config.contacts.length; i++) {
      Contact? c = await FlutterContacts.get(timer.config.contacts[i].id, properties: {ContactProperty.name, ContactProperty.photoThumbnail});
      if (c == null) continue;

      data[i] = c;
    }

    setState(() {
      _isLoading = false;
      _timerContacts = data;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatTime(DateTime dateTime, bool is24HourFormat) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    if (is24HourFormat) {
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
  }

  String _getDestinationsSubtitle(ActiveTimer timer) {
    AppLocalizations local = AppLocalizations.of(context)!;

    String subtitle = '';

    String part1 = '', part2 = '', part3 = '';
    int contactsLength = timer.config.contacts.length;
    int customLength = timer.config.customSms.length + timer.config.customEmail.length;
    int integrationsLength = timer.config.integrations.discord.accounts.length + timer.config.integrations.telegram.accounts.length;

    switch (contactsLength) {
      case 0:
        part1 = '';
        break;
      case 1:
        part1 = '1 ${local.translate("active_monitoring.destinations.contact.0")}';
        break;
      default:
        part1 =
            '$contactsLength '
            '${local.translate("active_monitoring.destinations.contact.1")}';
        break;
    }
    if (customLength > 0) part1 += " • ";

    switch (customLength) {
      case 0:
        part2 = '';
        break;
      case 1:
        part2 = '1 ${local.translate("active_monitoring.destinations.custom.0")}';
        break;
      default:
        part2 =
            '$customLength '
            '${local.translate("active_monitoring.destinations.custom.1")}';
        break;
    }
    if (integrationsLength > 0) part2 += " • ";

    switch (integrationsLength) {
      case 0:
        part3 = '';
        break;
      case 1:
        part3 = '1 ${local.translate("active_monitoring.destinations.integrations.0")}';
        break;
      default:
        part3 =
            '$integrationsLength '
            '${local.translate("active_monitoring.destinations.integrations.1")}';
        break;
    }

    subtitle = part1 + part2 + part3;

    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    bool use24hour = MediaQuery.of(context).alwaysUse24HourFormat;

    ActiveTimer timer = TimerService.instance.activeTimer;

    DateTime startedAt = DateTime.fromMillisecondsSinceEpoch(timer.run.startedAtMs, isUtc: true).toLocal();
    String startedAtString =
        "${local.translate("active_monitoring.time.started")} "
        "${_formatTime(startedAt, use24hour)} "
        "(${local.translate("history_logs.sections.months.${startedAt.month - 1}")} ${startedAt.day})";

    DateTime endsAt = DateTime.fromMillisecondsSinceEpoch(timer.run.expiresAtMs, isUtc: true).toLocal();
    String endsAtString =
        "${local.translate("active_monitoring.time.trigger_time")} "
        "${_formatTime(endsAt, use24hour)} "
        "(${local.translate("history_logs.sections.months.${endsAt.month - 1}")} ${endsAt.day})";

    String destinationsSubtitle = _getDestinationsSubtitle(timer);

    return ScreenBase(
      header: AppHeader(
        title: local.translate("active_monitoring.title"),
        left: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
        right: CircleIconButton(icon: LucideIcons.shield, foreground: scheme.tertiary, background: scheme.surface),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: EllipticalGradient(
                    colors: [scheme.tertiary.withAlpha(38), Colors.transparent],
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
                  padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xl),
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
                        MonitoringCountdownRing(),
                        const SizedBox(height: AppSpacing.xxl),

                        if (timer.config.routeSharingEnabled) ...[MonitoringTileMap(), const SizedBox(height: AppSpacing.md)],

                        AppCard(
                          child: AppRow(
                            padding: EdgeInsets.zero,
                            title: endsAtString,
                            subtitle: startedAtString,
                            icon: LucideIcons.clipboardClock,
                            iconSize: 20,
                            iconColor: scheme.secondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        AppCard(
                          child: Column(
                            children: [
                              AppRow(
                                padding: EdgeInsets.zero,
                                title: local.translate("active_monitoring.destinations.sending_to"),
                                subtitle: destinationsSubtitle,
                                icon: LucideIcons.send,
                                iconSize: 20,
                                iconColor: scheme.primary,
                              ),
                              const SizedBox(height: AppSpacing.md),

                              if (_timerContacts.isNotEmpty) ...[
                                AppCard(
                                  padding: EdgeInsets.all(AppSpacing.ms),
                                  child: Column(
                                    children: [
                                      for (int i = 0; i <= _timerContacts.keys.last; i++) ...[
                                        if (_timerContacts.containsKey(i)) ...[
                                          Builder(
                                            builder: (context) {
                                              Contact data = _timerContacts[i]!;

                                              String letter = (data.displayName == null || data.displayName == '') ? '?' : data.displayName![0];
                                              bool hasImage = data.photo?.thumbnail != null;

                                              List<({List<Color> gradient, Color text})> colorOpts = ContactService.colorOptions(context);
                                              final colors = colorOpts[Random().nextInt(colorOpts.length)];

                                              String dests = "";
                                              List<String> sms = timer.config.contacts[i].sms;
                                              if (sms.isNotEmpty) {
                                                for (int i = 0; i < sms.length; i++) {
                                                  dests += sms[i];
                                                  if (i < sms.length - 1) {
                                                    dests += "\n";
                                                  }
                                                }
                                              }
                                              List<String> emails = timer.config.contacts[i].email;
                                              if (emails.isNotEmpty) {
                                                if (sms.isNotEmpty) {
                                                  dests += "\n";
                                                }
                                                for (int i = 0; i < emails.length; i++) {
                                                  dests += emails[i];
                                                  if (i < emails.length - 1) {
                                                    dests += "\n";
                                                  }
                                                }
                                              }

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: Stack(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Material(
                                                              type: MaterialType.transparency,
                                                              child: Container(
                                                                width: 38,
                                                                height: 38,
                                                                clipBehavior: Clip.antiAlias,
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                    colors: colors.gradient,
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                                                ),
                                                                alignment: Alignment.center,
                                                                child: (hasImage)
                                                                    ? Image.memory(data.photo!.thumbnail!, filterQuality: FilterQuality.high)
                                                                    : Text(letter, style: AppText.bodySm(scheme).copyWith(color: colors.text)),
                                                              ),
                                                            ),
                                                            const SizedBox(width: AppSpacing.md),
                                                            Expanded(
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          data.displayName ?? '?',
                                                                          style: AppText.caption(scheme).copyWith(color: scheme.onSurface),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          softWrap: false,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Text(dests, style: AppText.micro(scheme)),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),

                                          if (i != _timerContacts.keys.last) ...[
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                              child: Divider(height: 1, color: scheme.outlineVariant),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],

                              if (timer.config.customSms.isNotEmpty || timer.config.customEmail.isNotEmpty) ...[
                                AppCard(
                                  padding: EdgeInsets.all(AppSpacing.ms),
                                  child: Builder(
                                    builder: (context) {
                                      List<String> customSms = timer.config.customSms;
                                      List<String> customEmail = timer.config.customEmail;

                                      return Column(
                                        children: [
                                          if (customSms.isNotEmpty)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Stack(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Material(
                                                            type: MaterialType.transparency,
                                                            child: Container(
                                                              width: 38,
                                                              height: 38,
                                                              clipBehavior: Clip.antiAlias,
                                                              decoration: BoxDecoration(
                                                                color: scheme.surfaceContainerHigh,
                                                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                                              ),
                                                              alignment: Alignment.center,
                                                              child: Icon(LucideIcons.phone, size: 16, color: scheme.onSurface),
                                                            ),
                                                          ),
                                                          const SizedBox(width: AppSpacing.md),
                                                          Expanded(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                for (var sms in customSms) ...[
                                                                  Row(
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          sms,
                                                                          style: AppText.micro(scheme),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          softWrap: false,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (customSms.isNotEmpty && customEmail.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                              child: Divider(height: 1, color: scheme.outlineVariant),
                                            ),
                                          if (customEmail.isNotEmpty)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Stack(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Material(
                                                            type: MaterialType.transparency,
                                                            child: Container(
                                                              width: 38,
                                                              height: 38,
                                                              clipBehavior: Clip.antiAlias,
                                                              decoration: BoxDecoration(
                                                                color: scheme.surfaceContainerHigh,
                                                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                                              ),
                                                              alignment: Alignment.center,
                                                              child: Icon(LucideIcons.mail, size: 16, color: scheme.onSurface),
                                                            ),
                                                          ),
                                                          const SizedBox(width: AppSpacing.md),
                                                          Expanded(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                for (var email in customEmail) ...[
                                                                  Row(
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          email,
                                                                          style: AppText.micro(scheme),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          softWrap: false,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],

                              if (timer.config.integrations.discord.accounts.isNotEmpty ||
                                  timer.config.integrations.telegram.accounts.isNotEmpty) ...[
                                FutureBuilder<List<IntegrationInfo>>(
                                  future: loadAllIntegrations(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return SizedBox.shrink();
                                    }

                                    final discord = snapshot.data!.firstWhere((i) => i.key == 'discord');
                                    final telegram = snapshot.data!.firstWhere((i) => i.key == 'telegram');

                                    final discordTimerAccounts = timer.config.integrations.discord.accounts;
                                    final telegramTimerAccounts = timer.config.integrations.telegram.accounts;

                                    Map<String?, String> discordAccountsInTimer = {};
                                    for (var timerAccount in discordTimerAccounts) {
                                      final account = discord.accounts.firstWhereOrNull((a) => a.id == timerAccount.id);
                                      if (account == null) continue;

                                      final destinations = account.destinations.where((d) {
                                        for (var id in timerAccount.destinations) {
                                          if (d.id == id) return true;
                                        }
                                        return false;
                                      }).toList();

                                      for (var d in IntegrationService.sortedDestinations(destinations)) {
                                        if (discordAccountsInTimer.containsKey(d.parentName)) {
                                          discordAccountsInTimer[d.parentName] = "${discordAccountsInTimer[d.parentName]!}\n${d.name}";
                                        } else {
                                          discordAccountsInTimer[d.parentName] = d.name;
                                        }
                                      }
                                    }

                                    List<String> telegramAccountsInTimer = [];
                                    for (var timerAccount in telegramTimerAccounts) {
                                      final account = telegram.accounts.firstWhereOrNull((a) => a.id == timerAccount.id);
                                      if (account == null) continue;

                                      final destinations = account.destinations.where((d) {
                                        for (var id in timerAccount.destinations) {
                                          if (d.id == id) return true;
                                        }
                                        return false;
                                      }).toList();

                                      for (var d in IntegrationService.sortedDestinations(destinations)) {
                                        telegramAccountsInTimer.add(d.name);
                                      }
                                    }

                                    return AppCard(
                                      padding: EdgeInsets.all(AppSpacing.ms),
                                      child: Column(
                                        children: [
                                          if (discordAccountsInTimer.isNotEmpty)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Stack(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Material(
                                                            type: MaterialType.transparency,
                                                            child: Container(
                                                              width: 38,
                                                              height: 38,
                                                              clipBehavior: Clip.antiAlias,
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  begin: Alignment.topLeft,
                                                                  end: Alignment.bottomRight,
                                                                  colors: discord.colors,
                                                                ),
                                                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                                              ),
                                                              alignment: Alignment.center,
                                                              child: Icon(FontAwesomeIcons.discord.data, size: 16, color: scheme.onSurface),
                                                            ),
                                                          ),
                                                          const SizedBox(width: AppSpacing.md),
                                                          Expanded(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                for (var account in discordAccountsInTimer.entries) ...[
                                                                  Row(
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          account.key ?? '',
                                                                          style: AppText.caption(scheme).copyWith(color: scheme.onSurface),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          softWrap: false,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Text(account.value, style: AppText.micro(scheme)),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (discordAccountsInTimer.isNotEmpty && telegramAccountsInTimer.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                              child: Divider(height: 1, color: scheme.outlineVariant),
                                            ),
                                          if (telegramAccountsInTimer.isNotEmpty)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Stack(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Material(
                                                            type: MaterialType.transparency,
                                                            child: Container(
                                                              width: 38,
                                                              height: 38,
                                                              clipBehavior: Clip.antiAlias,
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  begin: Alignment.topLeft,
                                                                  end: Alignment.bottomRight,
                                                                  colors: telegram.colors,
                                                                ),
                                                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                                              ),
                                                              alignment: Alignment.center,
                                                              child: Icon(FontAwesomeIcons.telegram.data, size: 16, color: scheme.onSurface),
                                                            ),
                                                          ),
                                                          const SizedBox(width: AppSpacing.md),
                                                          Expanded(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                for (var dest in telegramAccountsInTimer) ...[
                                                                  Row(
                                                                    children: [
                                                                      Flexible(
                                                                        child: Text(
                                                                          dest,
                                                                          style: AppText.micro(scheme),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          softWrap: false,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        AppCard(
                          child: Column(
                            children: [
                              AppRow(
                                padding: EdgeInsets.zero,
                                title: local.translate("active_monitoring.message"),
                                icon: LucideIcons.messageSquare,
                                iconSize: 20,
                                iconColor: scheme.secondary,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                "message will appear here", //TODO show timer custom message
                                style: AppText.caption(scheme).copyWith(color: scheme.onSurface),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 110),
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
              child: MonitoringControls(),
            ),
          ),
        ],
      ),
    );
  }
}
