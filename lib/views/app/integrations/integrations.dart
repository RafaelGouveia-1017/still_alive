import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';

import 'integration_row.dart';
import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// Provides presentation and grouping helpers for [IntegrationInfo].
///
/// This extension exposes derived values used by the integrations UI,
/// including the integration's display colors, platform icon, and channels
/// grouped by guild.
extension IntegrationInfoExtension on IntegrationInfo {
  /// Returns the two colors used to visually represent the integration.
  ///
  /// The colors are created from the ARGB values stored in
  /// [IntegrationInfo.gradient].
  List<Color> get colors {
    return [Color(gradient.start), Color(gradient.end)];
  }

  /// Returns the icon associated with the integration platform.
  ///
  /// Recognized integrations use their corresponding platform icons.
  /// Integrations with an unrecognized key use a generic webhook icon.
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

  /// Groups the integration's channels by guild name.
  ///
  /// Channels without a guild name are grouped under an empty string.
  ///
  /// The returned map uses the guild name as its key and contains all
  /// channels belonging to that guild as its value.
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

/// Displays the integrations management screen.
///
/// This screen loads the available integrations and presents their connected
/// users and message channels. Each integration is displayed as an expandable
/// group, with individual users and channels represented by [IntegrationRow].
///
/// The screen is also responsible for:
/// - Loading integration data.
/// - Testing individual integration connections.
/// - Deleting individual users or channels.
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

    List<IntegrationInfo> items = await loadAllIntegrations();

    if (!mounted) return;
    setState(() {
      _integrationItems = items;
      _isLoading = false;
    });
  }

  /// Builds the subtitle displayed for an integration.
  ///
  /// The subtitle describes the number of connected users and channels,
  /// automatically selecting singular or plural localization keys based on
  /// their respective counts.
  ///
  /// If only users or only channels are present, only that count is displayed.
  /// When both are present, the two counts are separated by a bullet.
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

  /// Tests the connection for an individual integration record.
  ///
  /// Calls [testIntegrationConnection] using the provided integration key
  /// and record ID. When the connection test fails, the returned message is
  /// displayed to the user as a toast notification.
  ///
  /// Returns a record containing the connection status and the message
  /// returned by the integration test.
  Future<({bool connected, String message})> _testIntegrationChannel({
    required String integrationKey,
    required String channelId,
    required ColorScheme scheme,
  }) async {
    final result = await testIntegrationConnection(
      key: integrationKey,
      id: channelId,
    );
    if (!result.connected) {
      showToast(
        scheme: scheme,
        toast: Text(
          result.message,
          style: AppText.bodySm(scheme),
          textAlign: TextAlign.center,
        ),
      );
    }
    return (connected: result.connected, message: result.message);
  }

  /// Deletes an individual integration user or channel.
  ///
  /// The corresponding record is first removed through
  /// [deleteIntegrationRecord]. After the operation succeeds, the local
  /// [_integrationItems] state is updated to remove the matching user and
  /// channel from the integration.
  ///
  /// If the deletion fails, the error is logged and a generic error message
  /// is displayed to the user.
  Future<void> _deleteIntegrationChannel({
    required String integrationKey,
    required String channelId,
  }) async {
    try {
      await deleteIntegrationRecord(key: integrationKey, id: channelId);
      if (!mounted) return;
      setState(() {
        _integrationItems = _integrationItems.map((integration) {
          if (integration.key != integrationKey) {
            return integration;
          }

          final updatedUsers = integration.users
              .where((user) => user.id != channelId)
              .toList();

          final updatedChannels = integration.channels
              .where((channel) => channel.channelId != channelId)
              .toList();

          return IntegrationInfo(
            key: integration.key,
            title: integration.title,
            gradient: integration.gradient,
            connected: integration.connected,
            users: updatedUsers,
            channels: updatedChannels,
          );
        }).toList();
      });
    } catch (e, st) {
      AppLogger.log.severe('SQL failed', e, st);
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
    }
  }

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
                  onTap: () {
                    //TODO: QR Code Page
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
                ] else ...[
                  if (_integrationItems.every(
                    (integration) =>
                        (integration.groupChannels.isEmpty &&
                        integration.users.isEmpty),
                  )) ...[
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
                          if (it.groupChannels.isNotEmpty ||
                              it.users.isNotEmpty)
                            AppExpandableCard(
                              title: it.title,
                              subtitle: _subtitle(it, context),
                              icon: it.iconData,
                              iconGradient: it.colors,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final user in it.users)
                                    IntegrationRow(
                                      title: user.username,
                                      subtitle: null,
                                      integrationKey: it.key,
                                      channelId: user.id,
                                      onTest: () => _testIntegrationChannel(
                                        integrationKey: it.key,
                                        channelId: user.id,
                                        scheme: scheme,
                                      ),
                                      onDelete: () => _deleteIntegrationChannel(
                                        integrationKey: it.key,
                                        channelId: user.id,
                                      ),
                                    ),

                                  for (final entry
                                      in it.groupChannels.entries) ...[
                                    for (final channel in entry.value)
                                      IntegrationRow(
                                        title: channel.channelName,
                                        subtitle: entry.key == ''
                                            ? null
                                            : entry.key,
                                        integrationKey: it.key,
                                        channelId: channel.channelId,
                                        onTest: () => _testIntegrationChannel(
                                          integrationKey: it.key,
                                          channelId: channel.channelId,
                                          scheme: scheme,
                                        ),
                                        onDelete: () =>
                                            _deleteIntegrationChannel(
                                              integrationKey: it.key,
                                              channelId: channel.channelId,
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
