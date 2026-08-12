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

/// Displays the integrations management screen.
///
/// This screen loads the available integrations and presents their connected
/// destinations. Each integration is displayed as an expandable
/// group, with individual destinations represented by [IntegrationRow].
///
/// The screen is also responsible for:
/// - Loading integration data.
/// - Testing individual integration destinations.
/// - Deleting individual destinations.
/// - Updating the local integration state after a deletion.
/// - Providing navigation and UI actions for adding integrations.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

/// State implementation for [IntegrationsScreen].
///
/// Maintains the currently loaded integrations and the loading state while
/// integration data is being retrieved.
class _IntegrationsScreenState extends State<IntegrationsScreen> {
  List<IntegrationInfo> _integrationItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadIntegrations();
  }

  void loadIntegrations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<IntegrationInfo> items = await loadAllIntegrations();

      if (!mounted) return;
      setState(() {
        _integrationItems = items;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.log.severe('Failed to load integrations.', e, st);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      showGenericErrorMessage(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    List<IntegrationInfo> connectedIntegrations = [];
    if (!_isLoading) {
      connectedIntegrations = _integrationItems
          .where((integration) => integration.accounts.isNotEmpty)
          .toList();
    }

    return ScreenBase(
      bottomNavDestination: 'integrations',
      header: AppHeader(
        title: local.translate("integrations.title"),
        right: (_isLoading)
            ? SizedBox(
                width: 25,
                height: 25,
                child: Center(
                  child: CircularProgressIndicator(color: scheme.tertiary),
                ),
              )
            : CircleIconButton(
                icon: LucideIcons.plus,
                onTap: () => showBlurredBottomSheet(
                  scheme: scheme,
                  context: context,
                  marginHorizontal: 50,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: _integrationItems.map((item) {
                            return SizedBox(
                              width: 85,
                              height: 85,
                              child: Pressable(
                                factory: InkSparkle.splashFactory,
                                onTap: () async {
                                  setState(() => _isLoading = true);
                                  Navigator.of(context).pop();

                                  try {
                                    final items =
                                        await IntegrationService.connectAccount(
                                          context: context,
                                          integrationItems: _integrationItems,
                                          integrationKey: item.key,
                                        );

                                    if (items == null) return;
                                    setState(() => _integrationItems = items);

                                    showToast(
                                      scheme: scheme,
                                      toast: Text(
                                        local.translate(
                                          "integrations.account_added",
                                        ),
                                        style: AppText.bodySm(scheme),
                                        textAlign: TextAlign.center,
                                      ),
                                      gravity: ToastGravity.BOTTOM,
                                      position: (context, child, gravity) =>
                                          Positioned(
                                            bottom: 170,
                                            left: 50,
                                            right: 50,
                                            child: child,
                                          ),
                                    );
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.iconData,
                                      size: 50,
                                      color: item.colors[0],
                                    ),
                                    const SizedBox(width: AppSpacing.xl),
                                    Text(
                                      item.title,
                                      style: AppText.caption(
                                        scheme,
                                      ).copyWith(color: scheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.ms,
                        ),
                        child: Text(
                          local.translate("integrations.soon"),
                          style: AppText.bodySm(
                            scheme,
                          ).copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      child: Column(
        children: [
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
                Pressable(
                  onTap: () async {
                    final result = await Navigator.of(context).push<String>(
                      AppRoute(
                        page: QRScannerScreen(),
                        transition: AppRouteTransitionType.slideRight,
                      ),
                    );
                    if (result == null || !context.mounted) return;

                    setState(() => _isLoading = true);
                    try {
                      Map<String, dynamic> json = jsonDecode(result);

                      //TODO make sure QR code works
                      /*
                        Expected JSON in QR Code:
                        {
                          "integrationKey": "discord",
                          "accountId": "DVSLk8utVw",
                          "destination": {
                            "id": "",
                            "name": "",
                            "kind": "direct_message",
                            "parentId": null,
                            "parentName": null
                          }
                        }
                      */
                      final items = await IntegrationService.selectDestination(
                        context: context,
                        integrationItems: _integrationItems,
                        integrationKey: json["integrationKey"],
                        accountId: json["accountId"],
                        destination: MessageDestination(
                          id: json["destination"]["id"],
                          name: json["destination"]["name"],
                          kind: switch (json["destination"]["kind"]) {
                            "direct_message" => DestinationKind.directMessage,
                            "group" => DestinationKind.group,
                            "server_channel" => DestinationKind.serverChannel,
                            _ => DestinationKind.channel,
                          },
                          parentId: json["destination"]["parentId"],
                          parentName: json["destination"]["parentName"],
                        ),
                      );

                      if (items == null) return;
                      setState(() => _integrationItems = items);

                      showToast(
                        scheme: scheme,
                        toast: Text(
                          local.translate("integrations.destination_added"),
                          style: AppText.bodySm(scheme),
                          textAlign: TextAlign.center,
                        ),
                        gravity: ToastGravity.BOTTOM,
                        position: (context, child, gravity) => Positioned(
                          bottom: 170,
                          left: 50,
                          right: 50,
                          child: child,
                        ),
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  child: AppCard(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x263D6FFF), Color(0x1A6C63FF)],
                    ),
                    borderColor: const Color(0x406C63FF),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 0,
                    ),
                    child: AppRow(
                      title: local.translate("integrations.qr_title"),
                      subtitle: local.translate("integrations.qr_note"),
                      icon: LucideIcons.qrCode,
                      iconSize: 30,
                      iconBackground: Colors.transparent,
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                SectionTitle(local.translate("integrations.connected")),
                if (_isLoading) ...[
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                ] else if (connectedIntegrations.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(
                        LucideIcons.webhookOff,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Text(
                      local.translate("integrations.not_found"),
                      style: AppText.bodySm(
                        scheme,
                      ).copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  AppExpandableGroup(
                    children: [
                      for (final it in connectedIntegrations)
                        for (final entry
                            in it.groupDestinationsByAccount.entries)
                          AppExpandableCard(
                            title: entry.key.name,
                            subtitle: IntegrationService.subtitle(it, context),
                            icon: it.iconData,
                            iconGradient: it.colors,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (entry.key.destinations.isNotEmpty) ...[
                                  for (final dest
                                      in entry.key.destinations) ...[
                                    IntegrationRow(
                                      title: dest.name,
                                      subtitle: dest.parentName,
                                      integrationKey: it.key,
                                      channelId: dest.id,
                                      onTest: () =>
                                          IntegrationService.testDestination(
                                            context: context,
                                            integrationKey: it.key,
                                            accountId: entry.key.id,
                                            destinationId: dest.id,
                                            scheme: scheme,
                                          ),
                                      onDelete: () async {
                                        final result =
                                            await IntegrationService.deselectDestination(
                                              context: context,
                                              integrationItems:
                                                  _integrationItems,
                                              integrationKey: it.key,
                                              accountId: entry.key.id,
                                              destinationId: dest.id,
                                            );
                                        if (result == null) return;
                                        setState(
                                          () => _integrationItems = result,
                                        );
                                      },
                                    ),
                                  ],
                                ] else ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                    ),
                                    child: Text(
                                      local.translate(
                                        "integrations.account_empty",
                                      ),
                                      style: AppText.caption(scheme),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.md,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      PrimaryButton(
                                        icon: LucideIcons.plus,
                                        width: 80,
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                              AppRoute(
                                                page:
                                                    IntegrationDestinationsScreen(
                                                      integration: it,
                                                      account: entry.key,
                                                    ),
                                                transition:
                                                    AppRouteTransitionType
                                                        .slideLeft,
                                              ),
                                            ),
                                      ),
                                      PrimaryButton(
                                        icon: LucideIcons.trash,
                                        color: ButtonColor.warning,
                                        width: 80,
                                        onPressed: () {
                                          showBlurredBottomSheet(
                                            context: context,
                                            scheme: scheme,
                                            marginHorizontal: 50,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  local.translate(
                                                    "integrations.delete_account.1",
                                                  ),
                                                  style: AppText.body(scheme),
                                                  textAlign: TextAlign.center,
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: AppSpacing.xl,
                                                        bottom: AppRadius.lg,
                                                      ),
                                                  child: PrimaryButton(
                                                    label: local.translate(
                                                      "integrations.delete_account.0",
                                                    ),
                                                    color: ButtonColor.warning,
                                                    onPressed: () async {
                                                      setState(
                                                        () => _isLoading = true,
                                                      );
                                                      Navigator.of(
                                                        context,
                                                      ).pop();

                                                      try {
                                                        final items =
                                                            await IntegrationService.deleteAccount(
                                                              context: context,
                                                              integrationItems:
                                                                  _integrationItems,
                                                              integrationKey:
                                                                  it.key,
                                                              accountId:
                                                                  entry.key.id,
                                                            );

                                                        if (items == null) {
                                                          return;
                                                        }
                                                        setState(
                                                          () =>
                                                              _integrationItems =
                                                                  items,
                                                        );

                                                        showToast(
                                                          scheme: scheme,
                                                          toast: Text(
                                                            local.translate(
                                                              "integrations.account_deleted",
                                                            ),
                                                            style:
                                                                AppText.bodySm(
                                                                  scheme,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                          gravity: ToastGravity
                                                              .BOTTOM,
                                                          position:
                                                              (
                                                                context,
                                                                child,
                                                                gravity,
                                                              ) => Positioned(
                                                                bottom: 170,
                                                                left: 50,
                                                                right: 50,
                                                                child: child,
                                                              ),
                                                        );
                                                      } finally {
                                                        setState(
                                                          () => _isLoading =
                                                              false,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
    );
  }
}
