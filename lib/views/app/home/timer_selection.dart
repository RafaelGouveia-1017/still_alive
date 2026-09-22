import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/main.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';

import 'timer/config/timer_config.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Screen that displays the available timer configurations and allows the user
/// to select, create, or edit a timer.
class TimerSelectionScreen extends StatefulWidget {
  const TimerSelectionScreen({super.key});

  @override
  State<TimerSelectionScreen> createState() => _TimerSelectionScreenState();
}

/// State implementation for [TimerSelectionScreen].
///
/// Manages loading, searching, displaying, and selecting timer configurations.
/// Also observes route changes to refresh the timer list when returning to this
/// screen.
class _TimerSelectionScreenState extends State<TimerSelectionScreen> with RouteAware {
  List<_TimerConfigData> _timerList = [];

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadTimers();
  }

  /// Loads timer configurations from the local database.
  ///
  /// Parses the stored JSON configuration for each timer and converts it into
  /// the corresponding [TimerConfig], [Contact], and integration models.
  ///
  /// The timer list is refreshed after loading completes. If the database
  /// operation fails, a generic error message is displayed to the user.
  void loadTimers() async {
    setState(() {
      _isLoading = true;
    });

    List<_TimerConfigData> list = [];

    try {
      String timersJsonString = await select(sql: "SELECT * FROM timers WHERE key <> 'timer0'");

      List<dynamic> data = jsonDecode(timersJsonString);
      for (var timer in data) {
        Map<String, dynamic> timerData = jsonDecode(timer["value"]);

        final List<Contact> contacts = (timerData["contacts"] as List)
            .map(
              (contact) => Contact(id: contact["id"], sms: List<String>.from(contact["sms"] ?? []), email: List<String>.from(contact["email"] ?? [])),
            )
            .toList();

        final TimerIntegrations integrations = TimerIntegrations(
          discord: TimerIntegration(
            accounts: (timerData["integrations"]["discord"]["accounts"] as List? ?? [])
                .map((account) => TimerIntegrationAccount(id: account["id"], destinations: List<String>.from(account["destinations"])))
                .toList(),
          ),
          telegram: TimerIntegration(
            accounts: (timerData["integrations"]["telegram"]["accounts"] as List? ?? [])
                .map((account) => TimerIntegrationAccount(id: account["id"], destinations: List<String>.from(account["destinations"])))
                .toList(),
          ),
        );

        final timerConfig = TimerConfig(
          name: timerData["name"],
          durationSecs: timerData["duration_secs"],
          gracePeriodSecs: timerData["grace_period_secs"],
          passwordProtected: timerData["password_protected"],
          passwordHash: timerData["password_hash"],
          locationSharingEnabled: timerData["location_sharing_enabled"],
          routeSharingEnabled: timerData["route_sharing_enabled"],
          locationCollectionIntervalSecs: timerData["location_collection_interval_secs"],
          audioRecordingEnabled: timerData["audio_recording_enabled"],

          contacts: contacts,
          customSms: List<String>.from(timerData["custom_sms"] ?? []),
          customEmail: List<String>.from(timerData["custom_email"] ?? []),
          integrations: integrations,

          createdAt: timerData["created_at"],
          updatedAt: timerData["updated_at"],
        );

        list.add(_TimerConfigData(timer["key"], timerConfig));
      }

      list.sort((a, b) => a.timerData.name.toLowerCase().compareTo(b.timerData.name.toLowerCase()));
    } catch (e, st) {
      AppLogger.log.severe('SQL failed', e, st);
      if (!mounted) return;
      showGenericErrorMessage(context, null);
    } finally {
      setState(() {
        _timerList = list;
        _isLoading = false;
      });
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
  void didPopNext() {
    loadTimers();
    super.didPopNext();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<_TimerConfigData> filteredTimers = [];

    final state = TimerService.instance.timerRunCurrentState;
    bool active = (state == TimerState.running || state == TimerState.paused);

    if (!_isLoading) {
      for (var timer in _timerList) {
        bool matchesSearch =
            _searchQuery.isEmpty || timer.timerData.name.toLowerCase().contains(_searchQuery) || timer.key.toLowerCase().contains(_searchQuery);

        if (matchesSearch) filteredTimers.add(timer);
      }
    }

    return ScreenBase(
      header: AppHeader(
        title: local.translate("timer_selection.title"),
        left: (_isLoading)
            ? SizedBox(
                width: 40,
                height: 40,
                child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
              )
            : CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
        right: (_isLoading)
            ? SizedBox(
                width: 40,
                height: 40,
                child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
              )
            : CircleIconButton(
                icon: LucideIcons.plus,
                onTap: () {
                  Navigator.of(context).push(AppRoute(page: TimerConfigScreen.newTimer(), transition: AppRouteTransitionType.slideLeft));
                },
              ),
        searchBar: AppSearchBar(
          hint: local.translate("timer_selection.search"),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
      child: (_isLoading)
          ? SizedBox(
              width: 56,
              height: 56,
              child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
            )
          : (filteredTimers.isEmpty)
          ? Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            border: Border.all(color: const Color(0x0DFFFFFF)),
                          ),
                          child: Icon((_searchQuery.isNotEmpty) ? LucideIcons.searchX : LucideIcons.timerOff, size: 36, color: scheme.error),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          (_searchQuery.isNotEmpty) ? local.translate("timer_selection.not_found") : local.translate("timer_selection.message"),
                          style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppExpandableGroup(
                children: [
                  for (var timer in filteredTimers)
                    timer.buildExpandableCardRow(
                      context,
                      active,
                      startLoading: () => setState(() => _isLoading = true),
                      endLoading: () => setState(() => _isLoading = false),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Contains the data required to display and interact with a timer
/// configuration in the timer selection screen.
///
/// Associates the timer's database key with its parsed [TimerConfig].
class _TimerConfigData {
  const _TimerConfigData(this.key, this.timerData);

  /// Database key that uniquely identifies the timer configuration.
  final String key;

  /// Parsed configuration associated with the timer.
  final TimerConfig timerData;

  /// Builds a row displaying a detail [title] and its corresponding [detail].
  ///
  /// The [scheme] is used to apply the current application's color scheme.
  Row buildDetailRow(String title, String detail, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.body(scheme)),
        Text(detail, style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  /// Builds a divider with the standard vertical spacing used between details.
  ///
  /// The [scheme] is used to determine the divider color.
  Padding paddingWithDivider(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.ms),
      child: Divider(height: 1, color: scheme.outlineVariant),
    );
  }

  /// Builds an expandable card for displaying and interacting with this timer
  /// configuration.
  ///
  /// The card displays the timer name, duration, grace period, configuration
  /// details, contacts, custom messages, integrations, and timestamps. It also
  /// provides actions for activating or editing the timer.
  ///
  /// The activation action is disabled when [hasTimerActive] is `true` or when
  /// this timer is already active. When activation begins, [startLoading] is
  /// called to indicate that the screen should display a loading state. If the
  /// activation does not cause navigation away from the screen, [endLoading]
  /// should be called to restore the normal UI state.
  ///
  /// The edit action navigates to the timer configuration screen for this timer.
  ///
  /// * [context] is the build context used to access the theme, localization,
  ///   and navigation state.
  /// * [hasTimerActive] indicates whether another timer is currently active.
  /// * [startLoading] is called immediately before activating the timer.
  /// * [endLoading] is called when activation finishes without navigating away
  ///   from the screen.
  ///
  /// Returns an [AppExpandableCard] containing the timer configuration and
  /// available actions.
  AppExpandableCard buildExpandableCardRow(
    BuildContext context,
    bool hasTimerActive, {
    required VoidCallback startLoading,
    required VoidCallback endLoading,
  }) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final String timerDuration = TimerService.formatDuration(Duration(seconds: timerData.durationSecs));

    String timerGraceDuration = '';
    if (timerData.gracePeriodSecs != null) {
      timerGraceDuration = TimerService.formatDuration(Duration(seconds: timerData.gracePeriodSecs!));
    }

    String subtitle = timerDuration;
    if (timerData.gracePeriodSecs != null) {
      subtitle = '$timerDuration • $timerGraceDuration';
    }

    String locationCollectionIntervalDuration = '';
    if (timerData.locationCollectionIntervalSecs != null) {
      locationCollectionIntervalDuration = TimerService.formatDuration(Duration(seconds: timerData.locationCollectionIntervalSecs!));
    }

    int integrations = 0;
    if (timerData.integrations.discord.accounts.isNotEmpty) integrations++;
    if (timerData.integrations.telegram.accounts.isNotEmpty) integrations++;

    bool isSelected = (key == TimerService.instance.activeTimer.key);

    return AppExpandableCard(
      title: timerData.name,
      subtitle: subtitle,
      trailing: isSelected ? Pill(label: local.translate("themes.status"), backColor: scheme.tertiary) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (hasTimerActive || isSelected) ...[
                  PrimaryButton(icon: LucideIcons.shieldOff, color: ButtonColor.muted, onPressed: null, width: 80),
                ] else ...[
                  PrimaryButton(
                    icon: LucideIcons.shieldCheck,
                    color: ButtonColor.tertiary,
                    onPressed: () async {
                      startLoading();
                      await TimerService.instance.activeTimer.replaceActiveTimer(
                        key: key,
                        config: timerData,
                        nowMs: DateTime.now().toUtc().millisecondsSinceEpoch,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      } else {
                        endLoading();
                      }
                    },
                    width: 80,
                  ),
                ],

                if (hasTimerActive && isSelected) ...[
                  PrimaryButton(icon: LucideIcons.pencilOff, color: ButtonColor.muted, onPressed: null, width: 80),
                ] else ...[
                  PrimaryButton(
                    icon: LucideIcons.pencil,
                    color: ButtonColor.primary,
                    onPressed: () async {
                      Navigator.of(context).push(
                        AppRoute(
                          page: TimerConfigScreen.existingTimer(timerKey: key, timerData: timerData),
                          transition: AppRouteTransitionType.slideLeft,
                        ),
                      );
                    },
                    width: 80,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            buildDetailRow(local.translate("timer_selection.details.duration"), timerDuration, scheme),
            paddingWithDivider(scheme),
            buildDetailRow(local.translate("timer_selection.details.grace"), (timerData.gracePeriodSecs == null) ? "-" : timerGraceDuration, scheme),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.password_protected"),
              (timerData.passwordProtected) ? local.translate("timer_selection.bool.true") : local.translate("timer_selection.bool.false"),
              scheme,
            ),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.location_sharing_enabled"),
              (timerData.locationSharingEnabled) ? local.translate("timer_selection.bool.true") : local.translate("timer_selection.bool.false"),
              scheme,
            ),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.route_sharing_enabled"),
              (timerData.routeSharingEnabled) ? local.translate("timer_selection.bool.true") : local.translate("timer_selection.bool.false"),
              scheme,
            ),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.location_collection_interval_secs"),
              (timerData.locationCollectionIntervalSecs != null) ? locationCollectionIntervalDuration : "-",
              scheme,
            ),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.audio_recording_enabled"),
              (timerData.audioRecordingEnabled) ? local.translate("timer_selection.bool.true") : local.translate("timer_selection.bool.false"),
              scheme,
            ),
            paddingWithDivider(scheme),
            buildDetailRow(local.translate("timer_selection.details.contacts"), timerData.contacts.length.toString(), scheme),
            paddingWithDivider(scheme),
            buildDetailRow(local.translate("timer_selection.details.custom_sms"), timerData.customSms.length.toString(), scheme),
            paddingWithDivider(scheme),
            buildDetailRow(local.translate("timer_selection.details.custom_email"), timerData.customEmail.length.toString(), scheme),
            paddingWithDivider(scheme),
            buildDetailRow(local.translate("timer_selection.details.integrations"), integrations.toString(), scheme),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.created_at"),
              timerData.createdAt.substring(0, timerData.createdAt.length - 7).replaceFirst('T', ' - '),
              scheme,
            ),
            paddingWithDivider(scheme),
            buildDetailRow(
              local.translate("timer_selection.details.updated_at"),
              timerData.updatedAt.substring(0, timerData.updatedAt.length - 7).replaceFirst('T', ' - '),
              scheme,
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
        ),
      ),
    );
  }
}
