import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/services/integration_service.dart';

import 'qr_display.dart';
import 'integration_row.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A screen that displays the message destinations available for an
/// integration account.
///
/// Destinations can be searched and filtered by their parent group. Each
/// destination also provides actions for testing the connection and
/// generating a QR code for the destination.
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

      final sorted = IntegrationService.sortedDestinations(destinations);

      // Build filters from destination parent names.
      List<String?> parentNames = sorted
          .map((destination) => destination.parentName)
          .toSet()
          .toList();

      parentNames.sort((a, b) {
        // Keep destinations without a parent at the end.
        if (a == null) return 1;
        if (b == null) return -1;

        return a.toLowerCase().compareTo(b.toLowerCase());
      });

      if (parentNames.length == 1 && parentNames[0] == null) parentNames = [];

      AppLocalizations local = AppLocalizations.of(context)!;

      // Build filters from destination type.
      final destinationKind = sorted
          .map((destination) => destination.kind)
          .toSet()
          .toList();

      final destinationTypes = destinationKind
          .map((kind) {
            switch (kind) {
              case DestinationKind.directMessage:
                return [
                  kind.name.toLowerCase(),
                  local.translate("integration_destinations.kinds.0"),
                ];
              case DestinationKind.group:
                return [
                  kind.name.toLowerCase(),
                  local.translate("integration_destinations.kinds.1"),
                ];
              case DestinationKind.channel:
                return [
                  kind.name.toLowerCase(),
                  local.translate("integration_destinations.kinds.2"),
                ];
              case DestinationKind.serverChannel:
                return [
                  kind.name.toLowerCase(),
                  local.translate("integration_destinations.kinds.3"),
                ];
            }
          })
          .toSet()
          .toList();

      destinationTypes.sort((a, b) {
        return a[1].toLowerCase().compareTo(b[1].toLowerCase());
      });

      filterLabels = [
        ['all', local.translate("integration_destinations.filters.0")],

        if (parentNames.isNotEmpty)
          ...parentNames.map(
            (name) => [
              name?.toLowerCase() ?? '__no_parent__',
              name ?? local.translate("integration_destinations.filters.1"),
            ],
          ),

        ...destinationTypes,
      ];

      loadFilters(0);

      setState(() {
        _destinationItems = sorted;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _handleJSONForQR(IntegrationAccount account) {
    String link = '';

    switch (widget.integration.provider) {
      case IntegrationProvider.discord:
        link =
            "https://discord.com/oauth2/authorize?client_id=${account.id}&scope=bot&permissions=3072";
      case IntegrationProvider.telegram:
        link = "https://t.me/${account.name.substring(1, account.name.length)}";
    }

    /*
      Expected JSON in QR Code:
      {
        "app": "StillAlive",
        "link": "https://link-to-group.com"
      }
    */

    Map<String, String> data = {"app": "StillAlive", "link": link};
    String json = jsonEncode(data);
    return base64UrlEncode(utf8.encode(json));
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
                  ) ||
                  activeFilters.contains(group.kind.name.toLowerCase())
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
        title: widget.account.name,
        subtitle: (_isLoading)
            ? "..."
            : subtitle ?? local.translate("integration_destinations.not_found"),
        left: CircleIconButton(
          icon: LucideIcons.chevronLeft,
          onTap: () => Navigator.pop(context),
        ),
        right: CircleIconButton(
          icon: LucideIcons.qrCode,
          onTap: () {
            Navigator.of(context).push(
              AppRoute(
                page: QrCodeScreen(
                  integrationTitle: widget.integration.title,
                  accountName: widget.account.name,
                  qrData: _handleJSONForQR(widget.account),
                ),
                transition: AppRouteTransitionType.slideLeft,
              ),
            );
          },
        ),
        searchBar: (groupedDestinations.isEmpty && searchQuery.isEmpty)
            ? null
            : AppSearchBar(
                hint: local.translate("integration_destinations.search"),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
        filterBar: (_filters.length <= 2)
            ? null
            : AppFilterBar(filters: _filters),
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
                  if (searchQuery.isEmpty) ...[
                    SizedBox(height: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (widget.integration.provider) {
                            IntegrationProvider.telegram => local.translate(
                              "integration_destinations.solutions.telegram.0",
                            ),
                            _ => local.translate(
                              "integration_destinations.solutions.discord.0",
                            ),
                          },
                          style: AppText.bodySm(scheme).copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          switch (widget.integration.provider) {
                            IntegrationProvider.telegram => local.translate(
                              "integration_destinations.solutions.telegram.1",
                            ),
                            _ => local.translate(
                              "integration_destinations.solutions.discord.1",
                            ),
                          },
                          style: AppText.bodySm(
                            scheme,
                          ).copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      children: [
                        for (final entry in groupedDestinations.entries) ...[
                          SizedBox(height: AppSpacing.lg),
                          if (_filters.any((opt) => opt.id == "__no_parent__"))
                            SectionTitle(entry.key),
                          AppCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxs,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Column(
                              children: [
                                for (final d in entry.value) ...[
                                  IntegrationRow(
                                    title: d.name,
                                    subtitle: null,
                                    onTest: () =>
                                        IntegrationService.testDestination(
                                          context: context,
                                          integrationKey:
                                              widget.integration.key,
                                          accountId: widget.account.id,
                                          destinationId: d.id,
                                          scheme: scheme,
                                        ),
                                    getExtLink: () {
                                      switch (widget.integration.provider) {
                                        case IntegrationProvider.discord:
                                          if (d.parentId == null) {
                                            return Uri.parse(
                                              "discord://-/channels/@me/${d.id}",
                                            );
                                          } else {
                                            return Uri.parse(
                                              "discord://-/channels/${d.parentId}/${d.id}",
                                            );
                                          }
                                        case IntegrationProvider.telegram:
                                          return Uri.parse("tg://");
                                      }
                                    },
                                  ),
                                  PrimaryButton(
                                    label: "send example message",
                                    color: ButtonColor.muted,
                                    width: 230,
                                    icon: LucideIcons.send,
                                    onPressed: () {
                                      IntegrationService.sendMessage(
                                        integrationKey: widget.integration.key,
                                        accountId: widget.account.id,
                                        destinationId: d.id,
                                        message:
                                            "hello sissel, this is a test message.",
                                      );
                                    },
                                  ),
                                  SizedBox(height: 12),
                                  //TODO delete this primarybutton & sizedbox when testing messages is no longer needed
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
