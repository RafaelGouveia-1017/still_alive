import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/services/timer_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:still_alive/data/all.dart';
import 'package:still_alive/src/rust/api/integrations/traits.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';
import 'package:still_alive/views/widgets/primitives.dart';

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

  /// Returns all accounts belonging to the integration.
  List<IntegrationAccount> get integrationAccounts {
    return accounts;
  }

  /// Returns accounts that have at least one selected destination.
  List<IntegrationAccount> get connectedAccounts {
    return accounts
        .where((account) => account.destinations.isNotEmpty)
        .toList();
  }

  /// Returns all channels across all accounts.
  ///
  /// The account association is not preserved in this flattened view.
  List<MessageDestination> get destinations {
    return accounts.expand((account) => account.destinations).toList();
  }

  /// Groups destinations by account and guild/server.
  ///
  /// Channels without a guild name are grouped under an empty string.
  ///
  /// Each account mapping uses the guild name as its key and contains all
  /// channels belonging to that guild as its value.
  Map<IntegrationAccount, Map<String, List<MessageDestination>>>
  get groupDestinationsByAccount {
    final result =
        <IntegrationAccount, Map<String, List<MessageDestination>>>{};
    for (final account in accounts) {
      final groups = <String, List<MessageDestination>>{};
      for (final destination in account.destinations) {
        final guildName = destination.parentName ?? '';
        groups.putIfAbsent(guildName, () => []);
        groups[guildName]!.add(destination);
      }
      // Sort each guild/server by channel name.
      for (final destinations in groups.values) {
        destinations.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      }
      result[account] = groups;
    }
    return result;
  }
}

/// Provides utility methods for managing external integrations.
///
/// [IntegrationService] centralizes integration-related operations such as
/// displaying account summaries, discovering available destinations, testing
/// accounts and destinations, connecting and removing accounts, managing
/// destinations, and presenting provider-specific setup flows.
///
/// The service delegates persistence and provider-specific operations to the
/// underlying generic integration API while keeping the local
/// [IntegrationInfo] state synchronized with successful changes.
class IntegrationService {
  const IntegrationService();

  /// Builds the subtitle displayed for an integration account.
  ///
  /// The subtitle describes the number of connected users and channels,
  /// automatically selecting singular or plural localization keys based on
  /// their respective counts.
  ///
  /// If no destinations are connected, returns `null`.
  /// If only users or only channels are present, only that count is displayed.
  /// When both are present, the two counts are separated by a bullet.
  ///
  /// A destination is considered a user when both [MessageDestination.parentId]
  /// and [MessageDestination.parentName] are `null`. All other destinations
  /// are considered channels.
  static String? subtitle(IntegrationAccount ac, BuildContext context) {
    AppLocalizations local = AppLocalizations.of(context)!;

    int destinations = ac.destinations.length;
    int users = ac.destinations
        .where(
          (test) =>
              (test.parentId == null &&
              test.parentName == null &&
              test.kind == DestinationKind.directMessage),
        )
        .length;
    int channels = destinations - users;

    String countLabel(int count, String singularKey, String pluralKey) {
      return '$count ${local.translate(count == 1 ? singularKey : pluralKey)}';
    }

    if (users == 0 && channels == 0) return null;

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

  /// Discovers destinations available to an integration account.
  ///
  /// Discovery does not persist any changes. The returned destinations can be
  /// presented to the user for selection before calling [selectDestination].
  ///
  /// [integrationKey] identifies the integration provider.
  /// [accountId] identifies the account whose destinations should be
  /// discovered.
  ///
  /// Returns an empty list if discovery fails. When an error occurs, it is
  /// logged and a generic error message is displayed if [context] is still
  /// mounted.
  static Future<List<MessageDestination>> discoverDestinations({
    required BuildContext context,
    required String integrationKey,
    required String accountId,
  }) async {
    try {
      List<MessageDestination> destinations =
          await discoverIntegrationDestinations(
            key: integrationKey,
            accountId: accountId,
          );

      await TimerService.instance
          .removeDeletedAccountDestinationFromActiveTimer(
            integrationKey,
            accountId,
          );

      return destinations;
    } catch (e, st) {
      AppLogger.log.severe(
        'Failed to discover integration destinations.',
        e,
        st,
      );
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return [];
    }
  }

  /// Sorts integration destinations by parent name and then destination name.
  ///
  /// Destinations are sorted case-insensitively. Destinations without a parent
  /// are treated as having an empty parent name and therefore appear before
  /// destinations with parent names.
  ///
  /// The original [destinations] list is not modified. A new sorted list is
  /// returned.
  static List<MessageDestination> sortedDestinations(
    List<MessageDestination> destinations,
  ) {
    final result = [...destinations];
    result.sort((a, b) {
      final guildComparison = (a.parentName ?? '').toLowerCase().compareTo(
        (b.parentName ?? '').toLowerCase(),
      );
      if (guildComparison != 0) {
        return guildComparison;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  /// Tests whether a destination can receive messages.
  ///
  /// Calls [testIntegrationDestination] using the supplied integration,
  /// account, and destination identifiers.
  ///
  /// If the destination cannot receive messages, the returned message is
  /// displayed to the user as a toast notification.
  ///
  /// Returns a record containing:
  /// - `canSend`: whether the destination can receive a message.
  /// - `message`: the message returned by the integration test.
  ///
  /// If the test throws an exception, the error is logged, a generic error
  /// message is displayed when possible, and `(canSend: false, message: "")`
  /// is returned.
  static Future<({bool canSend, String message})> testDestination({
    required BuildContext context,
    required String integrationKey,
    required String accountId,
    required String destinationId,
    required ColorScheme scheme,
  }) async {
    AppLocalizations local = AppLocalizations.of(context)!;
    try {
      DestinationTestResult result = await testIntegrationDestination(
        key: integrationKey,
        accountId: accountId,
        destinationId: destinationId,
      );
      showToast(
        scheme: scheme,
        toast: Text(
          (result.canSend)
              ? local.translate("integration_destinations.test_result.0")
              : local.translate("integration_destinations.test_result.1"),
          style: AppText.bodySm(scheme),
          textAlign: TextAlign.center,
        ),
        gravity: ToastGravity.BOTTOM,
        position: (context, child, gravity) =>
            Positioned(bottom: 170, left: 80, right: 80, child: child),
      );
      return (canSend: result.canSend, message: result.message);
    } catch (e, st) {
      AppLogger.log.severe('Failed to test integration destination.', e, st);
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return (canSend: false, message: "");
    }
  }

  /// Tests whether an integration account is accessible.
  ///
  /// Calls [testIntegrationAccount] using the supplied integration key and
  /// account ID.
  ///
  /// Returns a record containing:
  /// - `canSend`: whether the account is accessible.
  /// - `message`: the message returned by the integration test.
  ///
  /// If the test throws an exception, the error is logged, a generic error
  /// message is displayed when possible, and `(canSend: false, message: "")`
  /// is returned.
  static Future<({bool canSend, String message})> testAccount({
    required BuildContext context,
    required String integrationKey,
    required String accountId,
  }) async {
    try {
      DestinationTestResult result = await testIntegrationAccount(
        key: integrationKey,
        accountId: accountId,
      );

      return (canSend: result.canSend, message: result.message);
    } catch (e, st) {
      AppLogger.log.severe('Failed to test integration account.', e, st);
      return (canSend: false, message: "");
    }
  }

  /// Connects a new account to an integration.
  ///
  /// Sends [integrationCredentials] to the generic integration API using
  /// [integrationKey]. When the account is successfully connected, the
  /// returned account is added to the corresponding [IntegrationInfo].
  ///
  /// The updated integration list is returned without modifying the original
  /// list in place.
  ///
  /// If the connection fails, the error is logged, a generic error message is
  /// displayed when possible, and `null` is returned.
  static Future<List<IntegrationInfo>?> connectAccount({
    required BuildContext context,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
    required Map<String, String> integrationCredentials,
  }) async {
    try {
      IntegrationAccount account = await connectIntegrationAccount(
        key: integrationKey,
        credentials: integrationCredentials,
      );
      integrationItems = integrationItems.map((integration) {
        if (integration.key != integrationKey) {
          return integration;
        }
        return IntegrationInfo(
          key: integration.key,
          title: integration.title,
          gradient: integration.gradient,
          provider: integration.provider,
          connected: integration.connected,
          accounts: [...integration.accounts, account],
        );
      }).toList();
      return integrationItems;
    } catch (e, st) {
      AppLogger.log.severe('Failed to add integration account.', e, st);

      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        showToast(
          secs: 6,
          scheme: scheme,
          toast: Text(
            e.toString(),
            style: AppText.bodySm(scheme),
            textAlign: TextAlign.center,
          ),
          gravity: ToastGravity.BOTTOM,
          position: (context, child, gravity) =>
              Positioned(bottom: 170, left: 40, right: 40, child: child),
        );
      }
      return null;
    }
  }

  /// Deletes an integration account and all of its destinations.
  ///
  /// The account is first removed through [deleteIntegrationAccount].
  /// When the operation succeeds, the account is also removed from the local
  /// [integrationItems] state.
  ///
  /// [integrationKey] identifies the integration provider.
  /// [accountId] identifies the account to delete.
  ///
  /// Returns the updated integration list on success.
  ///
  /// If the deletion fails, the error is logged, a generic error message is
  /// displayed when possible, and `null` is returned.
  static Future<List<IntegrationInfo>?> deleteAccount({
    required BuildContext context,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
    required String accountId,
  }) async {
    try {
      await deleteIntegrationAccount(key: integrationKey, accountId: accountId);

      integrationItems = integrationItems.map((integration) {
        if (integration.key != integrationKey) {
          return integration;
        }

        final updatedAccounts = integration.accounts
            .where((account) => account.id != accountId)
            .toList();

        return IntegrationInfo(
          key: integration.key,
          title: integration.title,
          gradient: integration.gradient,
          provider: integration.provider,
          connected: updatedAccounts.isNotEmpty,
          accounts: updatedAccounts,
        );
      }).toList();

      await TimerService.instance
          .removeDeletedIntegrationAccountFromActiveTimer(
            integrationKey,
            accountId,
          );

      return integrationItems;
    } catch (e, st) {
      AppLogger.log.severe('Failed to delete integration account.', e, st);
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return null;
    }
  }

  /// Sends a message to an integration destination.
  ///
  /// Calls [sendIntegrationMessage] using the supplied integration provider,
  /// account, destination, and message content.
  ///
  /// [integrationKey] identifies the integration provider.
  /// [accountId] identifies the account that owns the destination.
  /// [destinationId] identifies the destination where the message should be
  /// sent.
  /// [message] contains the text to send.
  ///
  /// Returns the [SentMessage] returned by the integration API when the
  /// message is sent successfully.
  ///
  /// If sending fails, the error is logged and `null` is returned.
  static Future<SentMessage?> sendMessage({
    required String integrationKey,
    required String accountId,
    required String destinationId,
    required String message, //TODO will this just be string?
  }) async {
    try {
      return await sendIntegrationMessage(
        key: integrationKey,
        accountId: accountId,
        destinationId: destinationId,
        message: message,
      );
    } catch (e, st) {
      AppLogger.log.severe('Failed to send message.', e, st);
      return null;
    }
  }

  /// Displays the Discord bot setup flow.
  ///
  /// Opens a blurred bottom sheet containing instructions for obtaining
  /// a Discord bot token, a link to the Discord Developer Portal, and
  /// a text field for entering the token.
  ///
  /// When a non-empty token is submitted, it is passed to
  /// [connectAccount] using [integrationKey] and the token as the
  /// integration credentials.
  ///
  /// Returns the updated list of [IntegrationInfo] objects when the account
  /// is successfully connected, or `null` when the setup is cancelled or the
  /// connection fails.
  static Future<List<IntegrationInfo>?> discordSetup({
    required BuildContext context,
    required ColorScheme scheme,
    required AppLocalizations local,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
  }) async {
    String credentialToken = '';

    return await showBlurredBottomSheet<List<IntegrationInfo>?>(
      context: context,
      scheme: scheme,
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                local.translate("integrations.setup.discord.0"),
                style: AppText.title(
                  scheme,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              local.translate("integrations.setup.discord.1"),
              style: AppText.body(scheme),
            ),

            const SizedBox(height: AppSpacing.xl),

            Text(
              local.translate("integrations.setup.discord.2"),
              style: AppText.bodySm(scheme),
            ),

            const SizedBox(height: AppSpacing.md),

            _InstructionStep(
              number: 1,
              text: local.translate("integrations.setup.discord.3"),
            ),

            _InstructionStep(
              number: 2,
              text: local.translate("integrations.setup.discord.4"),
            ),

            _InstructionStep(
              number: 3,
              text: local.translate("integrations.setup.discord.5"),
            ),

            _InstructionStep(
              number: 4,
              text: local.translate("integrations.setup.discord.6"),
            ),

            _InstructionStep(
              number: 5,
              text: local.translate("integrations.setup.discord.7"),
            ),

            const SizedBox(height: AppSpacing.sm),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://discord.com/developers/applications',
                  );

                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: Icon(
                  LucideIcons.externalLink,
                  size: 20,
                  color: scheme.tertiary,
                ),
                label: Text(
                  local.translate("integrations.setup.discord.8"),
                  style: AppText.bodySm(
                    scheme,
                  ).copyWith(color: scheme.tertiary),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            TextField(
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: local.translate("integrations.setup.discord.9"),
                hintText: local.translate("integrations.setup.discord.10"),
                border: OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxs,
                  vertical: AppSpacing.xxxs,
                ),
                prefixIcon: Icon(LucideIcons.keyRound),
                filled: false,
                fillColor: Colors.transparent,
              ),
              onChanged: (text) {
                credentialToken = text.trim();
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            PrimaryButton(
              label: local.translate("integrations.account_add"),
              onPressed: () async {
                if (credentialToken.isEmpty) return;

                final items = await connectAccount(
                  context: context,
                  integrationItems: integrationItems,
                  integrationKey: integrationKey,
                  integrationCredentials: {"token": credentialToken},
                );

                if (context.mounted) {
                  if (items == null) {
                    Navigator.pop(context, null);
                  } else {
                    launchUrl(
                      Uri.parse(
                        "https://discord.com/oauth2/authorize?client_id=${items.where((i) => i.provider == IntegrationProvider.discord).first.accounts.last.appId}&scope=bot&permissions=3072",
                      ),
                      mode: LaunchMode.inAppBrowserView,
                    );
                    Navigator.pop(context, items);
                  }
                }
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            Center(
              child: Text(
                local.translate("integrations.setup.discord.11"),
                textAlign: TextAlign.center,
                style: AppText.micro(scheme).copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the Telegram bot setup flow.
  ///
  /// Opens a blurred bottom sheet containing instructions for obtaining
  /// a Telegram bot token through BotFather, a link that attempts to open
  /// BotFather in the Telegram app and falls back to the web version, and
  /// a text field for entering the bot token.
  ///
  /// When a non-empty token is submitted, it is passed to
  /// [connectAccount] using [integrationKey] and the token as the
  /// integration credentials.
  ///
  /// Returns the updated list of [IntegrationInfo] objects when the account
  /// is successfully connected, or `null` when the setup is cancelled or the
  /// connection fails.
  static Future<List<IntegrationInfo>?> telegramSetup({
    required BuildContext context,
    required ColorScheme scheme,
    required AppLocalizations local,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
  }) async {
    String credentialToken = '';
    return await showBlurredBottomSheet<List<IntegrationInfo>?>(
      context: context,
      scheme: scheme,
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                local.translate("integrations.setup.telegram.0"),
                style: AppText.title(
                  scheme,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              local.translate("integrations.setup.telegram.1"),
              style: AppText.body(scheme),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              local.translate("integrations.setup.telegram.2"),
              style: AppText.bodySm(scheme),
            ),
            const SizedBox(height: AppSpacing.md),
            _InstructionStep(
              number: 1,
              text: local.translate("integrations.setup.telegram.3"),
            ),
            _InstructionStep(
              number: 2,
              text: local.translate("integrations.setup.telegram.4"),
            ),
            _InstructionStep(
              number: 3,
              text: local.translate("integrations.setup.telegram.5"),
            ),
            _InstructionStep(
              number: 4,
              text: local.translate("integrations.setup.telegram.6"),
            ),

            const SizedBox(height: AppSpacing.sm),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final telegramUri = Uri.parse(
                    'tg://resolve?domain=BotFather',
                  );
                  final webUri = Uri.parse('https://t.me/BotFather');

                  if (await canLaunchUrl(telegramUri)) {
                    await launchUrl(telegramUri);
                  } else {
                    await launchUrl(
                      webUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                icon: Icon(
                  LucideIcons.externalLink,
                  size: 20,
                  color: scheme.tertiary,
                ),
                label: Text(
                  local.translate("integrations.setup.telegram.7"),
                  style: AppText.bodySm(
                    scheme,
                  ).copyWith(color: scheme.tertiary),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            TextField(
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: local.translate("integrations.setup.telegram.8"),
                hintText: local.translate("integrations.setup.telegram.9"),
                border: OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxs,
                  vertical: AppSpacing.xxxs,
                ),
                prefixIcon: Icon(LucideIcons.keyRound),
                filled: false,
                fillColor: Colors.transparent,
              ),
              onChanged: (text) {
                credentialToken = text.trim();
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            PrimaryButton(
              label: local.translate("integrations.account_add"),
              onPressed: () async {
                if (credentialToken.isEmpty) return;

                final items = await connectAccount(
                  context: context,
                  integrationItems: integrationItems,
                  integrationKey: integrationKey,
                  integrationCredentials: {"token": credentialToken},
                );

                if (context.mounted) {
                  if (items == null) {
                    Navigator.pop(context, null);
                  } else {
                    Navigator.pop(context, items);
                  }
                }
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            Center(
              child: Text(
                local.translate("integrations.setup.telegram.10"),
                textAlign: TextAlign.center,
                style: AppText.micro(scheme).copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget that displays a numbered instruction step.
///
/// The step consists of a numbered circular indicator followed by
/// the corresponding instruction text.
class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  /// The step number displayed to the user.
  final int number;

  /// The instruction text displayed for this step.
  final String text;

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.ms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppText.body(
                scheme,
              ).copyWith(color: scheme.onPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppText.bodySm(scheme))),
        ],
      ),
    );
  }
}
