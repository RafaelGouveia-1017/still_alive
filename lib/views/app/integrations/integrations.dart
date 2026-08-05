import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

extension IntegrationInfoExtension on IntegrationInfo {
  List<Color> get colors {
    return [Color(gradient.start), Color(gradient.end)];
  }

  IconData get iconData {
    switch (key) {
      case 'discord':
        return Icons.discord;
      case 'telegram':
        return Icons.telegram;
      default:
        return LucideIcons.webhook;
    }
  }

  Map<String, List<IntegrationChannel>> get groupChannels {
    final result = <String, List<IntegrationChannel>>{};

    for (final channel in channels) {
      final guild = channel.guildName ?? '';

      result.putIfAbsent(guild, () => []);
      result[guild]!.add(channel);
    }

    return result;
  }
}

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

/// State implementation for [IntegrationsScreen].
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

    List<IntegrationInfo> items = await loadAllIntegrations();

    if (!mounted) return;
    setState(() {
      _integrationItems = items;
      _isLoading = false;
    });
  }

  /*
  static const _items2 = [
    _Integration('Webhook', '1 channel', [
      Color(0xFF2A2E3A),
      Color(0xFF1C1F28),
    ], LucideIcons.webhook),
  ];*/

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    if (!_isLoading) {}

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
                                onTap: () {
                                  Navigator.pop(context);
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
                  onTap: () {},
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
                ] else ...[
                  if (_integrationItems.isEmpty) ...[
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
                      ),
                    ),
                  ] else ...[
                    AppExpandableGroup(
                      children: [
                        for (final it in _integrationItems)
                          AppExpandableCard(
                            title: it.title,
                            subtitle: _subtitle(it, context),
                            icon: it.iconData,
                            iconGradient: it.colors,
                            child: Column(
                              children: [
                                for (final user in it.users)
                                  AppRow(
                                    title: user.username,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.flaskConical,
                                          ),
                                          onPressed: () async {
                                            final result =
                                                await testIntegrationConnection(
                                                  key: it.key,
                                                  id: user.id,
                                                );

                                            showToast(
                                              scheme: scheme,
                                              toast: Text(result.message),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2),
                                          onPressed: () =>
                                              deleteIntegrationRecord(
                                                key: it.key,
                                                id: user.id,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                for (final entry
                                    in it.groupChannels.entries) ...[
                                  for (final channel in entry.value)
                                    AppRow(
                                      title: channel.channelName,
                                      subtitle: entry.key,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              LucideIcons.flaskConical,
                                            ),
                                            onPressed: () async {
                                              final result =
                                                  await testIntegrationConnection(
                                                    key: it.key,
                                                    id: channel.channelId,
                                                  );

                                              showToast(
                                                scheme: scheme,
                                                toast: Text(result.message),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                deleteIntegrationRecord(
                                                  key: it.key,
                                                  id: channel.channelId,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _subtitle(IntegrationInfo it, BuildContext context) {
  AppLocalizations local = AppLocalizations.of(context)!;

  final users = it.users.length;
  final channels = it.channels.length;

  String countLabel(int count, String singularKey, String pluralKey) {
    return '$count ${local.translate(count == 1 ? singularKey : pluralKey)}';
  }

  if (users == 0) {
    return countLabel(
      channels,
      "integrations.channel",
      "integrations.channels",
    );
  }

  if (channels == 0) {
    return countLabel(users, "integrations.user", "integrations.users");
  }

  return '${countLabel(users, "integrations.user", "integrations.users")} • '
      '${countLabel(channels, "integrations.channel", "integrations.channels")}';
}
