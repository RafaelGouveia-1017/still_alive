import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

class IntegrationService {
  const IntegrationService();

  /// Builds the subtitle displayed for an integration.
  ///
  /// The subtitle describes the number of connected users and channels,
  /// automatically selecting singular or plural localization keys based on
  /// their respective counts.
  ///
  /// If only users or only channels are present, only that count is displayed.
  /// When both are present, the two counts are separated by a bullet.
  static String? subtitle(IntegrationInfo it, BuildContext context) {
    AppLocalizations local = AppLocalizations.of(context)!;

    int destinations = it.destinations.length;
    int users = it.destinations
        .where((test) => (test.parentId == null && test.parentName == null))
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

  /// Discovers destinations that are available to an account.
  ///
  /// Discovery does not persist anything. The caller can use the returned
  /// destinations to present a selection UI before calling
  /// [selectDestination].
  static Future<List<MessageDestination>> discoverDestinations({
    required BuildContext context,
    required String integrationKey,
    required String accountId,
  }) async {
    try {
      return await discoverIntegrationDestinations(
        key: integrationKey,
        accountId: accountId,
      );
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

  /// Returns destinations sorted by guild/server and then channel name.
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

  /// Tests whether a destination can receive a message.
  ///
  /// Calls [testIntegrationDestination] using the provided integration key,
  /// account ID and destination ID. When the connection test fails, the
  /// returned message is displayed to the user as a toast notification.
  ///
  /// Returns a record containing the connection status and the message
  /// returned by the integration test.
  static Future<({bool canSend, String message})> testDestination({
    required BuildContext context,
    required String integrationKey,
    required String accountId,
    required String destinationId,
    required ColorScheme scheme,
  }) async {
    try {
      DestinationTestResult result = await testIntegrationDestination(
        key: integrationKey,
        accountId: accountId,
        destinationId: destinationId,
      );

      if (!result.canSend) {
        showToast(
          scheme: scheme,
          toast: Text(
            result.message,
            style: AppText.bodySm(scheme),
            textAlign: TextAlign.center,
          ),
        );
      }
      return (canSend: result.canSend, message: result.message);
    } catch (e, st) {
      AppLogger.log.severe('Failed to test integration destination.', e, st);
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return (canSend: false, message: "");
    }
  }

  /// Connects a new account for an integration.
  ///
  /// The account data is gathered by the generic Rust integration API.
  /// After the account is successfully persisted, the local
  /// [integrationItems] state is updated with the returned account.
  static Future<List<IntegrationInfo>?> connectAccount({
    required BuildContext context,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
  }) async {
    try {
      IntegrationAccount account = await connectIntegrationAccount(
        key: integrationKey,
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
        showGenericErrorMessage(context, null);
      }
      return null;
    }
  }

  /// Adds a destination to an existing account.
  ///
  /// The destination is already discovered/selected by the caller and is
  /// persisted by Rust.
  ///
  /// The record is gathered and persisted by the generic Rust integration API.
  /// After the operation succeeds, the returned account replaces the existing
  /// account in [integrationItems].
  static Future<List<IntegrationInfo>?> selectDestination({
    required BuildContext context,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
    required String accountId,
    required MessageDestination destination,
  }) async {
    try {
      IntegrationAccount updatedAccount = await selectIntegrationDestination(
        key: integrationKey,
        accountId: accountId,
        destination: destination,
      );

      integrationItems = integrationItems.map((integration) {
        if (integration.key != integrationKey) {
          return integration;
        }

        final updatedAccounts = integration.accounts.map((account) {
          if (account.id != accountId) {
            return account;
          }

          return updatedAccount;
        }).toList();

        return IntegrationInfo(
          key: integration.key,
          title: integration.title,
          gradient: integration.gradient,
          provider: integration.provider,
          connected: updatedAccounts.isNotEmpty,
          accounts: updatedAccounts,
        );
      }).toList();
      return integrationItems;
    } catch (e, st) {
      AppLogger.log.severe('Failed to select integration destination.', e, st);
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return null;
    }
  }

  /// Removes a selected destination from an account.
  ///
  /// The corresponding record is first removed through
  /// [deselectIntegrationDestination]. After the operation succeeds, the local
  /// [integrationItems] state is updated to remove the matching user and
  /// channel from the integration.
  ///
  /// If the deletion fails, the error is logged and a generic error message
  /// is displayed to the user.
  static Future<List<IntegrationInfo>?> deselectDestination({
    required BuildContext context,
    required List<IntegrationInfo> integrationItems,
    required String integrationKey,
    required String accountId,
    required String destinationId,
  }) async {
    try {
      await deselectIntegrationDestination(
        key: integrationKey,
        accountId: accountId,
        destinationId: destinationId,
      );

      integrationItems = integrationItems.map((integration) {
        if (integration.key != integrationKey) {
          return integration;
        }
        final updatedAccounts = integration.accounts.map((account) {
          if (account.id != accountId) {
            return account;
          }

          final updatedDestinations = account.destinations
              .where((dest) => dest.id != destinationId)
              .toList();

          return IntegrationAccount(
            id: account.id,
            name: account.name,
            destinations: updatedDestinations,
          );
        }).toList();

        return IntegrationInfo(
          key: integration.key,
          title: integration.title,
          gradient: integration.gradient,
          provider: integration.provider,
          connected: updatedAccounts.isNotEmpty,
          accounts: updatedAccounts,
        );
      }).toList();
      return integrationItems;
    } catch (e, st) {
      AppLogger.log.severe(
        'Failed to deselect integration destination.',
        e,
        st,
      );
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return null;
    }
  }

  /// Deletes an entire integration account and all of its destinations.
  ///
  /// The corresponding account and all of its destinations are first
  /// removed through [deleteIntegrationAccount]. After the operation succeeds,
  /// the local [integrationItems] state is updated to remove the account.
  ///
  /// If the deletion fails, the error is logged and a generic error message
  /// is displayed to the user.
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
      return integrationItems;
    } catch (e, st) {
      AppLogger.log.severe('Failed to delete integration account.', e, st);
      if (context.mounted) {
        showGenericErrorMessage(context, null);
      }
      return null;
    }
  }
}
