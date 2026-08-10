import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

import '../../../services/history_service.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

class _Group {
  const _Group(this.day, this.items);
  final String day;
  final List<HistoryEvent> items;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// State implementation for [HistoryScreen].
class _HistoryScreenState extends State<HistoryScreen> {
  late List<AppFilterBarOption> _filters = [];
  late List<List<String>> filterLabels = [];
  late List<_Group> _groups = [];

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
    loadHistory();
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

  void loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    String jsonStr = await select(
      sql:
          "SELECT * FROM history WHERE created_at >= date('now', '-3 months') ORDER BY created_at DESC",
    );
    List<dynamic> results = jsonDecode(jsonStr);

    List<_Group> groups = results.map<_Group>((row) {
      List<HistoryEvent> events = HistoryService.listFromJson(row["value"]);
      return _Group(row["created_at"] as String, events);
    }).toList();

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;
    bool is24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;

    List<_Group> groupsFiltered = [];

    if (!_isLoading) {
      final activeFilters = _filters
          .where((f) => f.active)
          .map((f) => f.id)
          .toSet();

      bool is24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;

      groupsFiltered = _groups
          .map((group) {
            List<HistoryEvent> items = group.items.where((event) {
              // Search query
              bool matchesSearch =
                  searchQuery.isEmpty ||
                  event.timerName.toLowerCase().contains(searchQuery) ||
                  event.getTitle(local).toLowerCase().contains(searchQuery) ||
                  event
                      .getSubtitle(is24HourFormat, local)
                      .toLowerCase()
                      .contains(searchQuery);

              // Active filters
              bool matchesFilter =
                  activeFilters.contains('all') ||
                  activeFilters.contains(event.type.toLowerCase());

              return matchesSearch && matchesFilter;
            }).toList();

            return _Group(group.day, items);
          })
          .where((group) => group.items.isNotEmpty)
          .toList();
    }

    return ScreenBase(
      bottomNavDestination: 'history',
      header: AppHeader(
        title: local.translate("history_logs.title"),
        searchBar: AppSearchBar(
          hint: local.translate("history_logs.search"),
          onChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase();
            });
          },
        ),
        filterBar: AppFilterBar(filters: _filters),
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
                if (groupsFiltered.isEmpty) ...[
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
                      LucideIcons.archiveX,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    local.translate("history_logs.not_found"),
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
                        for (final g in groupsFiltered) ...[
                          SizedBox(height: AppRadius.lg),
                          Builder(
                            builder: (context) {
                              DateTime date = DateTime.parse(g.day);
                              return SectionTitle(
                                '${local.translate("history_logs.sections.months.${date.month}")} ${date.day}',
                              );
                            },
                          ),
                          AppCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < g.items.length; i++) ...[
                                  Pressable(
                                    onTap: () {
                                      showBlurredBottomSheet(
                                        context: context,
                                        scheme: scheme,
                                        child: g.items[i].toTable(context),
                                      );
                                    },
                                    child: AppRow(
                                      title: g.items[i].getTitle(local),
                                      subtitle: g.items[i].getSubtitle(
                                        is24HourFormat,
                                        local,
                                      ),
                                      icon: g.items[i].icon,
                                      iconColor: g.items[i].tone.foreground(
                                        context,
                                      ),
                                      iconBackground: g.items[i].tone
                                          .background(context),
                                      trailing: Icon(
                                        LucideIcons.chevronRight,
                                        size: 18,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (i < g.items.length - 1)
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
