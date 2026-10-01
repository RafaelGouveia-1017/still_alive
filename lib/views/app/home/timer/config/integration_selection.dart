import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/integration_service.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';

import '../../../../../data/all.dart';
import '../../../../widgets/primitives.dart';

/// A summary card for configuring the integrations associated with a timer.
///
/// Displays the number of selected integration accounts and destinations and
/// opens [IntegrationSelectionScreen] when tapped.
class IntegrationSelection extends StatefulWidget {
  const IntegrationSelection({super.key, required this.integrations, required this.onChanged});

  final TimerIntegrations integrations;
  final ValueChanged<TimerIntegrations> onChanged;

  @override
  State<IntegrationSelection> createState() => _IntegrationSelectionState();
}

/// State implementation for [IntegrationSelection].
///
/// Maintains the current timer integrations and updates the summary card when
/// the selected integrations change.
class _IntegrationSelectionState extends State<IntegrationSelection> {
  late final ValueNotifier<TimerIntegrations> _integrations;

  @override
  void initState() {
    super.initState();

    _integrations = ValueNotifier(widget.integrations);
    _integrations.addListener(_onValueChanged);
  }

  void _onValueChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _integrations.removeListener(_onValueChanged);
    _integrations.dispose();
    super.dispose();
  }

  String? _getSubtitle(int plugins, int destinations) {
    AppLocalizations local = AppLocalizations.of(context)!;

    String? subtitle = '';
    if (plugins == 0) {
      return null;
    } else {
      switch (destinations) {
        case 0:
          subtitle = null;
          break;
        case 1:
          subtitle = '1 ${local.translate("timer_configuration.integrations.destination.0")}';
          break;
        default:
          subtitle = '$destinations ${local.translate("timer_configuration.integrations.destination.1")}';
          break;
      }
    }

    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final discord = _integrations.value.discord;
    final telegram = _integrations.value.telegram;

    int plugins = discord.accounts.length + telegram.accounts.length;

    int destinations = 0;
    for (var dest in discord.accounts) {
      destinations += dest.destinations.length;
    }
    for (var dest in telegram.accounts) {
      destinations += dest.destinations.length;
    }

    return AppCard(
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          AppRoute(
            page: IntegrationSelectionScreen(
              integrations: _integrations.value,
              onChanged: (value) {
                _integrations.value = value;
                widget.onChanged(value);
              },
            ),
            transition: AppRouteTransitionType.slideLeft,
          ),
        ),
        child: AppRow(
          padding: EdgeInsets.zero,
          title: switch (plugins) {
            0 => local.translate("timer_configuration.integrations.none"),
            1 =>
              '1 ${local.translate("timer_configuration.integrations.account.0")} '
                  '${local.translate("timer_configuration.integrations.selected.0")}',
            _ =>
              '$plugins ${local.translate("timer_configuration.integrations.account.1")} '
                  '${local.translate("timer_configuration.integrations.selected.1")}',
          },
          subtitle: _getSubtitle(plugins, destinations),
          icon: (plugins != 0) ? LucideIcons.blocks : LucideIcons.grid2X2X,
          iconRotateAngle: (plugins != 0) ? 0 : -math.pi / 2,
          iconColor: scheme.secondary,
          trailing: Icon(LucideIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// A screen for selecting the integration accounts and destinations
/// associated with a timer.
///
/// Displays all connected integration accounts and their available
/// destinations. Users can select or deselect individual destinations, and
/// changes are reported through [onChanged].
class IntegrationSelectionScreen extends StatefulWidget {
  const IntegrationSelectionScreen({super.key, required this.integrations, required this.onChanged});

  final TimerIntegrations integrations;
  final ValueChanged<TimerIntegrations> onChanged;

  @override
  State<IntegrationSelectionScreen> createState() => _IntegrationSelectionScreenState();
}

/// State implementation for [IntegrationSelectionScreen].
///
/// Loads connected integrations and manages the current timer integration
/// selection. It provides the logic required to select and deselect
/// individual destinations while keeping the timer configuration immutable
/// between updates.
class _IntegrationSelectionScreenState extends State<IntegrationSelectionScreen> {
  late TimerIntegrations _integrations;
  late List<IntegrationInfo> _integrationItems;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _integrations = widget.integrations;
    loadIntegrations();
  }

  void loadIntegrations() async {
    setState(() => _isLoading = true);

    List<IntegrationInfo> items = [];
    try {
      items = await loadAllIntegrations();
    } catch (e, st) {
      AppLogger.log.severe('Failed to load integrations.', e, st);
      if (!mounted) return;
      showGenericErrorMessage(context, null);
    } finally {
      setState(() {
        _integrationItems = items;
        _isLoading = false;
      });
    }
  }

  int _getNumberofAccountsInTimer() {
    final discord = _integrations.discord;
    final telegram = _integrations.telegram;
    return discord.accounts.length + telegram.accounts.length;
  }

  int _getNumberofDestinationsInTimer() {
    final discord = _integrations.discord;
    final telegram = _integrations.telegram;

    int destinations = 0;
    for (var dest in discord.accounts) {
      destinations += dest.destinations.length;
    }
    for (var dest in telegram.accounts) {
      destinations += dest.destinations.length;
    }

    return destinations;
  }

  String? _getSubtitle() {
    AppLocalizations local = AppLocalizations.of(context)!;

    int plugins = _getNumberofAccountsInTimer();

    String subtitle = '';
    if (plugins == 0) {
      return null;
    } else {
      String part1, part2;

      int destinations = _getNumberofDestinationsInTimer();

      switch (plugins) {
        case 1:
          part1 = '1 ${local.translate("timer_configuration.integrations.account.0")}';
          break;
        default:
          part1 =
              '$plugins '
              '${local.translate("timer_configuration.integrations.account.1")}';
          break;
      }

      switch (destinations) {
        case 0:
          part2 = '';
          break;
        case 1:
          part2 = ' • 1 ${local.translate("timer_configuration.integrations.destination.0")}';
          break;
        default:
          part2 =
              ' • $destinations '
              '${local.translate("timer_configuration.integrations.destination.1")}';
          break;
      }

      subtitle = part1 + part2;
    }

    return subtitle;
  }

  TimerIntegration _getTimerIntegrationByProvider(IntegrationProvider provider) {
    switch (provider) {
      case IntegrationProvider.discord:
        return _integrations.discord;
      case IntegrationProvider.telegram:
        return _integrations.telegram;
    }
  }

  TimerIntegrationAccount? _getIntegrationAccountInTimer(TimerIntegration integration, String accountID) {
    return integration.accounts.firstWhereOrNull((account) => account.id == accountID);
  }

  bool _isAccountDestinationInTimer(TimerIntegrationAccount account, String destinationID) {
    return account.destinations.any((dest) => dest == destinationID);
  }

  void _selectAccountDestination({required IntegrationProvider provider, required String accountID, required String destinationID}) {
    final integration = _getTimerIntegrationByProvider(provider);
    final existingAccount = _getIntegrationAccountInTimer(integration, accountID);

    final updatedAccount = (existingAccount == null)
        ? TimerIntegrationAccount(id: accountID, destinations: [destinationID])
        : TimerIntegrationAccount(
            id: existingAccount.id,
            destinations: [...existingAccount.destinations, if (!_isAccountDestinationInTimer(existingAccount, destinationID)) destinationID],
          );

    if (existingAccount != null && _isAccountDestinationInTimer(existingAccount, destinationID)) {
      return;
    }

    final updatedIntegration = TimerIntegration(accounts: [...integration.accounts.where((account) => account.id != accountID), updatedAccount]);

    _setTimerIntegration(provider, updatedIntegration);
  }

  void _deselectAccountDestination({required IntegrationProvider provider, required String accountID, required String destinationID}) {
    final integration = _getTimerIntegrationByProvider(provider);

    final existingAccount = _getIntegrationAccountInTimer(integration, accountID);

    if (existingAccount == null || !_isAccountDestinationInTimer(existingAccount, destinationID)) {
      return;
    }

    final destinations = existingAccount.destinations.where((id) => id != destinationID).toList();

    final accounts = integration.accounts.where((account) => account.id != accountID).toList();

    if (destinations.isNotEmpty) {
      accounts.add(TimerIntegrationAccount(id: existingAccount.id, destinations: destinations));
    }

    _setTimerIntegration(provider, TimerIntegration(accounts: accounts));
  }

  void _setTimerIntegration(IntegrationProvider provider, TimerIntegration integration) {
    _integrations = TimerIntegrations(
      discord: provider == IntegrationProvider.discord ? integration : _integrations.discord,
      telegram: provider == IntegrationProvider.telegram ? integration : _integrations.telegram,
    );

    _updateTimerIntegrations();
  }

  void _updateTimerIntegrations() {
    widget.onChanged(_integrations);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<IntegrationInfo> connectedIntegrations = [];
    if (!_isLoading) {
      connectedIntegrations = _integrationItems.where((integration) => integration.accounts.isNotEmpty).toList();
    }

    return ScreenBase(
      header: AppHeader(
        title: local.translate("timer_configuration.integrations.title"),
        subtitle: _getSubtitle(),
        left: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
              children: [
                if (_isLoading) ...[
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
                    ),
                  ),
                ] else if (connectedIntegrations.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xxxxl),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(LucideIcons.webhookOff, size: 36, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Text(
                      local.translate("timer_configuration.integrations.no_integrations"),
                      style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  SectionTitle(local.translate("integrations.connected")),
                  AppExpandableGroup(
                    children: [
                      for (final it in connectedIntegrations)
                        for (final entry in it.groupDestinationsByAccount.entries)
                          _buildAccountCard(scheme: scheme, local: local, integration: it, account: entry.key, destinationGroups: entry.value),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppExpandableCard _buildAccountCard({
    required ColorScheme scheme,
    required AppLocalizations local,
    required IntegrationInfo integration,
    required IntegrationAccount account,
    required Map<String, List<MessageDestination>> destinationGroups,
  }) {
    final timerIntegration = _getTimerIntegrationByProvider(integration.provider);

    final timerAccount = _getIntegrationAccountInTimer(timerIntegration, account.id);

    int totalDestinations = destinationGroups.values.fold<int>(0, (total, destinations) => total + destinations.length);

    int selectedDestinations = destinationGroups.values
        .expand((destinations) => destinations)
        .where((destination) => timerAccount != null && _isAccountDestinationInTimer(timerAccount, destination.id))
        .length;

    return AppExpandableCard(
      title: integration.title,
      subtitle: account.name,
      icon: integration.iconData,
      iconGradient: integration.colors,
      trailing: Text(
        '$selectedDestinations / ${(totalDestinations > 0) ? totalDestinations : '-'}',
        style: AppText.caption(scheme),
        textAlign: TextAlign.center,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          children: [
            if (totalDestinations == 0)
              Text(local.translate("timer_configuration.integrations.no_destinations"), style: AppText.bodySm(scheme), textAlign: TextAlign.center)
            else
              for (final entry in destinationGroups.entries) ...[
                if (entry.key.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(entry.key, style: AppText.caption(scheme)),
                    ),
                  ),

                for (final destination in entry.value)
                  _buildDestinationRow(
                    scheme: scheme,
                    provider: integration.provider,
                    accountID: account.id,
                    destination: destination,
                    timerAccount: timerAccount,
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationRow({
    required ColorScheme scheme,
    required IntegrationProvider provider,
    required String accountID,
    required MessageDestination destination,
    required TimerIntegrationAccount? timerAccount,
  }) {
    final selected = timerAccount != null && _isAccountDestinationInTimer(timerAccount, destination.id);

    return Pressable(
      onTap: () {
        if (selected) {
          _deselectAccountDestination(provider: provider, accountID: accountID, destinationID: destination.id);
        } else {
          _selectAccountDestination(provider: provider, accountID: accountID, destinationID: destination.id);
        }
      },
      child: AppRow(
        title: destination.name,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppRadius.lg),
        trailing: Icon(selected ? LucideIcons.squareCheck : LucideIcons.square, size: 20, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
