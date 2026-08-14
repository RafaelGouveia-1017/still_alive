import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/services/integration_service.dart';

import 'integration_row.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

class IntegrationDestinationsScreen extends StatefulWidget {
  const IntegrationDestinationsScreen({
    super.key,
    required this.integration,
    required this.account,
  });

  final IntegrationInfo integration;
  final IntegrationAccount account;

  @override
  State<IntegrationDestinationsScreen> createState() =>
      _IntegrationDestinationsScreenState();
}

/// State implementation for [IntegrationDestinationsScreen].
class _IntegrationDestinationsScreenState
    extends State<IntegrationDestinationsScreen> {
  List<MessageDestination> _destinationItems = [];
  Set<String> _selectedIds = {};

  late List<AppFilterBarOption> _filters = [];
  late List<List<String>> filterLabels = [];

  bool _isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (filterLabels.isNotEmpty) return;
    loadDestinations();
  }

  void loadFilters(int index) async {
    if (_filters.isEmpty) {
      setState(() {
        _filters = List.generate(
          filterLabels.length,
          (i) => AppFilterBarOption(
            id: filterLabels[i][0],
            label: filterLabels[i][1],
            active: i == index,
            onPressed: () => loadFilters(i),
          ),
        );
      });
      return;
    }

    if (index == 0) {
      if (_filters[0].active) return;
      setState(() {
        _filters = _filters.asMap().entries.map((entry) {
          return entry.value.copyWith(active: entry.key == index);
        }).toList();
      });
    } else {
      bool active = !_filters[index].active;
      List<AppFilterBarOption> updated = _filters.asMap().entries.map((entry) {
        return entry.value.copyWith(
          active: (entry.key == index)
              ? active
              : (entry.key == 0)
              ? false
              : entry.value.active,
        );
      }).toList();

      bool allActive = updated.every(
        (filter) => (filter.id == "all") ? true : filter.active,
      );
      if (allActive) {
        for (int i = 0; i < updated.length; i++) {
          updated[i] = updated[i].copyWith(active: false);
        }
      }
      bool allInactive = updated.every((filter) => !filter.active);
      if (allInactive) {
        updated[0] = updated[0].copyWith(active: true);
      }

      setState(() {
        _filters = updated;
      });
    }
  }

  void loadDestinations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<MessageDestination> destinations =
          await IntegrationService.discoverDestinations(
            context: context,
            integrationKey: widget.integration.key,
            accountId: widget.account.id,
          );

      if (!mounted || destinations.isEmpty) return;

      final selectedIds = widget.account.destinations
          .map((destination) => destination.id)
          .toSet();

      final sorted = IntegrationService.sortedDestinations(destinations);

      // Build filters from destination parent names.
      final parentNames = sorted
          .map((destination) => destination.parentName)
          .toSet()
          .toList();

      parentNames.sort((a, b) {
        // Keep destinations without a parent at the end.
        if (a == null) return 1;
        if (b == null) return -1;

        return a.toLowerCase().compareTo(b.toLowerCase());
      });

      AppLocalizations local = AppLocalizations.of(context)!;

      filterLabels = [
        ['all', local.translate("integration_destinations.filters.0")],
        ...parentNames.map(
          (name) => [
            name?.toLowerCase() ?? '__no_parent__',
            name ?? local.translate("integration_destinations.filters.1"),
          ],
        ),
      ];

      loadFilters(0);

      setState(() {
        _selectedIds = selectedIds;
        _destinationItems = sorted;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    Map<String, List<MessageDestination>> groupedDestinations =
        <String, List<MessageDestination>>{};

    String? subtitle;

    if (!_isLoading) {
      Set<String> activeFilters = (_filters.isNotEmpty)
          ? _filters.where((f) => f.active).map((f) => f.id).toSet()
          : {};

      List<MessageDestination> destinationsFiltered = _destinationItems.where((
        group,
      ) {
        // Search query
        bool matchesSearch =
            searchQuery.isEmpty ||
            group.name.toLowerCase().contains(searchQuery) ||
            (group.parentName != null &&
                group.parentName!.toLowerCase().contains(searchQuery));

        // Active filters
        bool matchesFilter = (_filters.isNotEmpty)
            ? activeFilters.contains('all') ||
                  activeFilters.contains(
                    group.parentName?.toLowerCase() ?? '__no_parent__',
                  )
            : true;

        return matchesSearch && matchesFilter;
      }).toList();

      for (final destination in destinationsFiltered) {
        final parentName =
            destination.parentName ??
            local.translate("integration_destinations.filters.1");
        groupedDestinations.putIfAbsent(parentName, () => []).add(destination);
      }

      subtitle = IntegrationService.subtitle(
        IntegrationAccount(
          id: widget.account.id,
          name: widget.account.name,
          destinations: _destinationItems,
        ),
        context,
      );
    }

    return ScreenBase(
      header: AppHeader(
        title:
            '${widget.account.name} • ${local.translate("integration_destinations.title")}',
        subtitle: (_isLoading)
            ? "..."
            : subtitle ?? local.translate("integration_destinations.not_found"),
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
        searchBar: (groupedDestinations.isNotEmpty)
            ? AppSearchBar(
                hint: local.translate("integration_destinations.search"),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              )
            : null,
        filterBar: (_filters.isEmpty) ? null : AppFilterBar(filters: _filters),
      ),
      child: (_isLoading)
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: CircularProgressIndicator(color: scheme.tertiary),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (groupedDestinations.isEmpty) ...[
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      LucideIcons.searchX,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    (searchQuery.isNotEmpty)
                        ? local.translate("integration_destinations.not_found")
                        : local.translate("integration_destinations.warning"),
                    style: AppText.bodySm(
                      scheme,
                    ).copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      children: [
                        for (final entry in groupedDestinations.entries) ...[
                          SizedBox(height: AppRadius.lg),
                          SectionTitle(entry.key),
                          AppCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxs,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Column(
                              children: [
                                for (final d in entry.value)
                                  IntegrationRow(
                                    title: d.name,
                                    subtitle: null,
                                    integrationKey: widget.integration.key,
                                    channelId: d.id,
                                    selected: _selectedIds.contains(d.id),
                                    listMode: true,
                                    onAdd: () async {
                                      final result =
                                          await IntegrationService.selectDestination(
                                            context: context,
                                            integrationItems: [],
                                            integrationKey:
                                                widget.integration.key,
                                            accountId: widget.account.id,
                                            destination: d,
                                          );
                                      if (result == null) return;
                                      setState(() {
                                        _selectedIds.add(d.id);
                                      });
                                    },
                                    onTest: () =>
                                        IntegrationService.testDestination(
                                          context: context,
                                          integrationKey:
                                              widget.integration.key,
                                          accountId: widget.account.id,
                                          destinationId: d.id,
                                          scheme: scheme,
                                        ),
                                    onDelete: () async {
                                      final result =
                                          await IntegrationService.deselectDestination(
                                            context: context,
                                            integrationItems: [],
                                            integrationKey:
                                                widget.integration.key,
                                            accountId: widget.account.id,
                                            destinationId: d.id,
                                          );
                                      if (result == null) return;
                                      setState(() {
                                        _selectedIds.removeWhere(
                                          (id) => id == d.id,
                                        );
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
