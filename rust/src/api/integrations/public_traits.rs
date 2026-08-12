use crate::api::integrations::discord::DiscordIntegration;
use crate::api::integrations::telegram::TelegramIntegration;
use crate::api::integrations::traits::*;

use anyhow::{anyhow, Result};

/// Returns information about every supported integration.
pub fn load_all_integrations() -> Result<Vec<IntegrationInfo>> {
    Ok(vec![
        DiscordIntegration::load()?.info(),
        TelegramIntegration::load()?.info(),
    ])
}

/// Discovers destinations currently available to an account.
///
/// Discovery does NOT persist anything.
pub fn discover_integration_destinations(
    key: String,
    account_id: String,
) -> Result<Vec<MessageDestination>> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.discover_destinations(&account_id),
        "telegram" => TelegramIntegration::load()?.discover_destinations(&account_id),
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Fetches a selected destination from the external API and returns the
/// updated account.
///
/// This is the operation that changes application authorization state.
///
/// # Arguments
///
/// * `key` - The integration identifier (for example, `"discord"` or
///   `"telegram"`).
/// * `account_id` - The account identifier.
/// * `destination` - The destination record metadata to insert.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * The updated configuration cannot be saved.
pub fn select_integration_destination(
    key: String,
    account_id: String,
    destination: MessageDestination,
) -> Result<IntegrationAccount> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.add_destination(&account_id, destination),
        "telegram" => TelegramIntegration::load()?.add_destination(&account_id, destination),
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Fetches the currently authenticated account from the external API,
/// inserts it into the integration configuration, and returns the newly
/// created account.
///
/// The returned account is persisted with no selected destinations.
///
/// The external API call is performed by the integration implementation.
///
/// # Arguments
///
/// * `key` - The integration identifier (for example, `"discord"` or
///   `"telegram"`).
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * The updated configuration cannot be saved.
pub fn connect_integration_account(key: String) -> Result<IntegrationAccount> {
    match key.as_str() {
        "discord" => {
            let mut integration = DiscordIntegration::load()?;

            let mut account = integration.authenticate_account()?;
            account.destinations.clear();

            integration.add_account(account.clone())?;

            Ok(account)
        }

        "telegram" => {
            let mut integration = TelegramIntegration::load()?;

            let mut account = integration.authenticate_account()?;
            account.destinations.clear();

            integration.add_account(account.clone())?;

            Ok(account)
        }

        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Removes a selected destination record from the specified account in an
/// integration configuration.
///
/// The target account is loaded from the database, the matching record is
/// removed using the provided identifier, and the updated configuration is
/// persisted back to the database.
///
/// # Arguments
///
/// * `key` - The integration identifier (for example, `"discord"` or
///   `"telegram"`).
/// * `account_id` - The account identifier with the record.
/// * `destination_id` - The destination identifier to remove.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * The updated configuration cannot be saved.
pub fn deselect_integration_destination(
    key: String,
    account_id: String,
    destination_id: String,
) -> Result<IntegrationAccount> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.remove_destination(&account_id, &destination_id),
        "telegram" => TelegramIntegration::load()?.remove_destination(&account_id, &destination_id),
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Deletes a connected integration account.
///
/// All destinations belonging to the account are removed together with
/// the account itself.
///
/// # Arguments
///
/// * `key` - The integration identifier (for example, `"discord"` or
///   `"telegram"`).
/// * `account_id` - The account identifier to remove.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * The updated configuration cannot be saved.
pub fn delete_integration_account(key: String, account_id: String) -> Result<()> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.remove_account(&account_id),
        "telegram" => TelegramIntegration::load()?.remove_account(&account_id),
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Tests whether a selected destination can receive a message.
///
/// This checks the destination itself rather than merely checking whether
/// the integration account is connected.
///
/// # Arguments
///
/// * `key` - The integration identifier used to select the platform
///   (for example, `"discord"` or `"telegram"`).
/// * `account_id` - The account identifier.
/// * `destination_id` - The destination identifier to test.
///
/// # Returns
///
/// Returns an [`IntegrationTestResult`] containing:
///
/// * Whether the integration is connected.
/// * A human-readable status message.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * The integration test fails.
pub fn test_integration_destination(
    key: String,
    account_id: String,
    destination_id: String,
) -> Result<DestinationTestResult> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.test_destination(&account_id, &destination_id),
        "telegram" => TelegramIntegration::load()?.test_destination(&account_id, &destination_id),
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Sends a message to an explicitly selected destination.
///
/// The provider implementation is responsible for refusing to send to
/// destinations that aren't selected for the account.
///
/// # Arguments
///
/// * `key` - The integration identifier used to select the platform.
/// * `account_id` - The account identifier.
/// * `destination_id` - The destination identifier.
/// * `message` - The message content to send.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * Authentication fails.
/// * The destination cannot be reached.
/// * Sending the message fails.
pub fn send_integration_message(
    key: String,
    account_id: String,
    destination_id: String,
    message: String,
) -> Result<SentMessage> {
    match key.as_str() {
        "discord" => {
            DiscordIntegration::load()?.send_message(&account_id, &destination_id, &message)
        }
        "telegram" => {
            TelegramIntegration::load()?.send_message(&account_id, &destination_id, &message)
        }
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}
