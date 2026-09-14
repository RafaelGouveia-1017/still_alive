import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';
import 'package:still_alive/services/integration_service.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'integration_destinations.dart';
import 'qr_scanner.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A screen for managing the application's external integrations.
///
/// Displays connected integration accounts, allows new integrations to be
/// connected, provides account-level testing and deletion actions, and
/// provides access to QR code scanning and integration destinations.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

/// State implementation for [IntegrationsScreen].
class _IntegrationsScreenState extends State<IntegrationsScreen> {
  List<IntegrationInfo> _integrationItems = [];
  final Map<String, bool> _pressedTestAccounts = {};
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
                onTap: () async {
                  if (await InternetConnection().hasInternetAccess) {
                    if (!context.mounted) return;
                    showBlurredBottomSheet(
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
                                      Navigator.of(context).pop();

                                      try {
                                        List<IntegrationInfo>? items;
                                        switch (item.provider) {
                                          case IntegrationProvider.discord:
                                            items =
                                                await IntegrationService.discordSetup(
                                                  context: context,
                                                  scheme: scheme,
                                                  local: local,
                                                  integrationItems:
                                                      _integrationItems,
                                                  integrationKey: item.key,
                                                );
                                            break;
                                          case IntegrationProvider.telegram:
                                            items =
                                                await IntegrationService.telegramSetup(
                                                  context: context,
                                                  scheme: scheme,
                                                  local: local,
                                                  integrationItems:
                                                      _integrationItems,
                                                  integrationKey: item.key,
                                                );
                                            break;
                                        }

                                        if (items == null) return;
                                        setState(() {
                                          _isLoading = true;
                                          _integrationItems = items!;
                                        });

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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                          textAlign: TextAlign.center,
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
                    );
                  } else {
                    showToast(
                      scheme: scheme,
                      toast: Text(
                        local.translate("integrations.no_internet"),
                        style: AppText.bodySm(scheme),
                        textAlign: TextAlign.center,
                      ),
                      gravity: ToastGravity.BOTTOM,
                      position: (context, child, gravity) => Positioned(
                        bottom: 170,
                        left: 80,
                        right: 80,
                        child: child,
                      ),
                    );
                  }
                },
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
                        transition: AppRouteTransitionType.slideLeft,
                      ),
                    );
                    if (result == null || !context.mounted) return;

                    /*
                      Expected JSON in QR Code:
                      {
                        "app": "StillAlive",
                        "link": "https://link-to-group.com"
                      }
                    */
                    Map<String, dynamic> json = jsonDecode(result);

                    if (json.containsKey("app") && json.containsKey("link")) {
                      if (json["app"] != "StillAlive") return;
                      try {
                        Uri link = Uri.parse(json["link"]);
                        launchUrl(link, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        AppLogger.log.info("JSON in QR code: $json", e);
                        return;
                      }
                    }
                  },
                  child: AppCard(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withAlpha(38),
                        scheme.secondary.withAlpha(26),
                      ],
                    ),
                    borderColor: scheme.secondary.withAlpha(64),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 0,
                    ),
                    child: AppRow(
                      title: local.translate("integrations.qr_title"),
                      subtitle: local.translate("integrations.qr_note"),
                      icon: LucideIcons.scanQrCode,
                      iconSize: 32,
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
                  SectionTitle(local.translate("integrations.connected")),
                  AppExpandableGroup(
                    children: [
                      for (final it in connectedIntegrations)
                        for (final entry
                            in it.groupDestinationsByAccount.entries)
                          AppExpandableCard(
                            title: it.title,
                            subtitle: entry.key.name,
                            icon: it.iconData,
                            iconGradient: it.colors,
                            trailing:
                                _pressedTestAccounts.keys.contains(entry.key.id)
                                ? (_pressedTestAccounts[entry.key.id] == true)
                                      ? Pill(
                                          label: local.translate(
                                            "integrations.account_test.2",
                                          ),
                                          backColor: scheme.tertiary,
                                          leading: Icon(
                                            LucideIcons.check,
                                            size: 12,
                                            color: scheme.tertiary,
                                          ),
                                        )
                                      : Pill(
                                          label: local.translate(
                                            "integrations.account_test.3",
                                          ),
                                          backColor: scheme.error,
                                          leading: Icon(
                                            LucideIcons.x,
                                            size: 12,
                                            color: scheme.error,
                                          ),
                                        )
                                : Text(
                                    (entry.key.destinations.isNotEmpty)
                                        ? entry.key.destinations.length
                                              .toString()
                                        : '-',
                                    style: AppText.caption(scheme),
                                    textAlign: TextAlign.center,
                                  ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.md,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      PrimaryButton(
                                        icon: LucideIcons.messagesSquare,
                                        width: 80,
                                        onPressed: () async {
                                          if (await InternetConnection()
                                              .hasInternetAccess) {
                                            if (!context.mounted) return;

                                            await Navigator.of(context).push(
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
                                            );
                                          } else {
                                            showToast(
                                              scheme: scheme,
                                              toast: Text(
                                                local.translate(
                                                  "integrations.no_internet",
                                                ),
                                                style: AppText.bodySm(scheme),
                                                textAlign: TextAlign.center,
                                              ),
                                              gravity: ToastGravity.BOTTOM,
                                              position:
                                                  (context, child, gravity) =>
                                                      Positioned(
                                                        bottom: 170,
                                                        left: 80,
                                                        right: 80,
                                                        child: child,
                                                      ),
                                            );
                                          }
                                        },
                                      ),
                                      PrimaryButton(
                                        icon:
                                            _pressedTestAccounts.keys.contains(
                                              entry.key.id,
                                            )
                                            ? LucideIcons.flaskConicalOff
                                            : LucideIcons.flaskConical,
                                        color:
                                            _pressedTestAccounts.keys.contains(
                                              entry.key.id,
                                            )
                                            ? ButtonColor.muted
                                            : ButtonColor.tertiary,
                                        width: 80,
                                        onPressed:
                                            _pressedTestAccounts.keys.contains(
                                              entry.key.id,
                                            )
                                            ? null
                                            : () async {
                                                if (await InternetConnection()
                                                    .hasInternetAccess) {
                                                  if (!context.mounted) return;

                                                  setState(
                                                    () => _isLoading = true,
                                                  );
                                                  try {
                                                    final result =
                                                        await IntegrationService.testAccount(
                                                          context: context,
                                                          integrationKey:
                                                              it.key,
                                                          accountId:
                                                              entry.key.id,
                                                        );

                                                    setState(() {
                                                      _pressedTestAccounts[entry
                                                              .key
                                                              .id] =
                                                          result.canSend;
                                                    });

                                                    showToast(
                                                      scheme: scheme,
                                                      secs: 5,
                                                      toast: Text(
                                                        '${entry.key.name} ${(result.canSend) ? local.translate("integrations.account_test.0") : local.translate("integrations.account_test.1")}',
                                                        style: AppText.bodySm(
                                                          scheme,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      gravity:
                                                          ToastGravity.BOTTOM,
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
                                                      () => _isLoading = false,
                                                    );
                                                  }
                                                } else {
                                                  showToast(
                                                    scheme: scheme,
                                                    toast: Text(
                                                      local.translate(
                                                        "integrations.no_internet",
                                                      ),
                                                      style: AppText.bodySm(
                                                        scheme,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    gravity:
                                                        ToastGravity.BOTTOM,
                                                    position:
                                                        (
                                                          context,
                                                          child,
                                                          gravity,
                                                        ) => Positioned(
                                                          bottom: 170,
                                                          left: 80,
                                                          right: 80,
                                                          child: child,
                                                        ),
                                                  );
                                                }
                                              },
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
