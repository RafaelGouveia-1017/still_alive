import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';
import 'package:still_alive/services/integration_service.dart';

import 'integration_row.dart';
import 'integration_destinations.dart';
import 'qr_scanner.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';
  

class IntegrationDestinationsScreen extends StatefulWidget {
  const IntegrationDestinationsScreen({
    super.key,
    required this.integration,
    required this.account
  });

  final IntegrationInfo integration;
  final IntegrationAccount account;

  @override
  State<IntegrationDestinationsScreen> createState() => _IntegrationDestinationsScreenState();
}

/// State implementation for [IntegrationDestinationsScreen].
class _IntegrationDestinationsScreenState extends State<IntegrationDestinationsScreen> {
  List<MessageDestination> _destinationItems = [];

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

    AppLocalizations local = AppLocalizations.of(context)!;
    filterLabels = [
      ['all', local.translate("history_logs.events.filters.0")],
      ['started', local.translate("history_logs.events.filters.1")],
      ['warning', local.translate("history_logs.events.filters.2")],
      ['paused', local.translate("history_logs.events.filters.3")],
      ['cancelled', local.translate("history_logs.events.filters.4")],
      ['expired', local.translate("history_logs.events.filters.5")],
    ];
    filterLabels.sort((a, b) => a[0].compareTo(b[0]));

    loadFilters(0);
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
      List<MessageDestination> destinations = await IntegrationService.discoverDestinations(
        context: context,
        integrationKey: widget.integration.key,
        accountId: widget.account.id,
      );

      if (!context.mounted || destinations.isEmpty) return;

      final selectedIds = widget.account.destinations
          .map((destination) => destination.id)
          .toSet();
      final available = destinations
          .where((destination) => !selectedIds.contains(destination.id))
          .toList();

      if (available.isEmpty) {
        return;
      }

      final sorted = IntegrationService.sortedDestinations(available);

      if (!mounted) return;
      setState(() => _destinationItems = sorted);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<MessageDestination> destinationsFiltered = [];

    if (!_isLoading) {
      final activeFilters = _filters
          .where((f) => f.active)
          .map((f) => f.id)
          .toSet();

      destinationsFiltered = _destinationItems
          .where((group) {
              // Search query
              bool matchesSearch =
                  searchQuery.isEmpty ||
                  group.name.toLowerCase().contains(searchQuery) ||
                  (group.parentName != null && group.parentName!.toLowerCase().contains(searchQuery));

              // Active filters
              bool matchesFilter =
                  activeFilters.contains('all') ||
                  activeFilters.contains(group.parentName?.toLowerCase());

              return matchesSearch && matchesFilter;
          })
          .toList();
    }

    return ScreenBase(
      header: AppHeader(
        title: '${widget.account.name} • ${local.translate("integration_destinations.title")}',
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
        searchBar: AppSearchBar(
          hint: local.translate("integration_destinations.search"),
          onChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase();
            });
          },
        ),
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
                if (destinationsFiltered.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      LucideIcons.navigationOff,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    local.translate("integration_destinations.not_found"),
                    style: AppText.bodySm(
                      scheme,
                    ).copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        AppSpacing.lg,
                        0,
                        AppSpacing.xl,
                      ),
                      children: [
                        for (final d in destinationsFiltered) ...[
                          Pressable(
                            onTap: () async {
                              Navigator.of(context).pop();
                              await selectDestination(
                                context: context,
                                integrationItems: ,
                                integrationKey: widget.integration.key,
                                accountId: widget.account.id,
                                destination: d,
                              );
                            },
                            child: AppRow(
                              title: d.name,
                              subtitle: d.parentName,
                              icon: widget.integration.iconData,
                              iconSize: 24,
                              iconBackground: Colors.transparent,
                              trailing: Icon(
                                LucideIcons.plus,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),

                          //TODO change integration_row to only display the test button
                          //TODO move delete button from integration_row to this page for each selected row
                          //TODO if row not selected, trailing icon will be a plus sign that calls selectDestination(...)

                          //TODO move current selectDestination(...) list logic to QR implementation (after it runs)
                          //TODO change selectDestination(...) to return List<MessageDestination> instead 
                          //TODO fix QR implementation after selectDestination(...) changes

                          //TODO divide page by guild sections and appcards with the respective guild channels
                          //TODO fix filters labels and all of it really (good luck brother :( )


                          SizedBox(height: AppRadius.lg),
                          SectionTitle(
                                '${local.translate("history_logs.sections.months.${date.month}")} ${date.day}',
                              ),
                          AppCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < d.items.length; i++) ...[
                                  Pressable(
                                    onTap: () {
                                      showBlurredBottomSheet(
                                        context: context,
                                        scheme: scheme,
                                        child: d.items[i].toTable(context),
                                      );
                                    },
                                    child: AppRow(
                                      title: d.items[i].getTitle(local),
                                      subtitle: d.items[i].getSubtitle(
                                        is24HourFormat,
                                        local,
                                      ),
                                      icon: d.items[i].icon,
                                      iconColor: d.items[i].tone.foreground(
                                        context,
                                      ),
                                      iconBackground: d.items[i].tone
                                          .background(context),
                                      trailing: Icon(
                                        LucideIcons.chevronRight,
                                        size: 18,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (i < d.items.length - 1)
                                    Divider(
                                      height: 1,
                                      color: scheme.outlineVariant,
                                    ),
                                ],
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

