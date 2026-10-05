use crate::api::integrations::discord::DiscordIntegration;
use crate::api::integrations::telegram::TelegramIntegration;
use crate::api::integrations::traits::*;

use anyhow::{anyhow, Result};
use std::collections::HashMap;

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
pub async fn discover_integration_destinations(
    key: String,
    account_id: String,
) -> Result<Vec<MessageDestination>> {
    match key.as_str() {
        "discord" => {
            let mut integration = DiscordIntegration::load()?;
            integration.discover_destinations(&account_id).await
        }
        "telegram" => {
            let mut integration = TelegramIntegration::load()?;
            integration.discover_destinations(&account_id).await
        }
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Authenticates an account with the external integration API, adds the
/// account to the integration configuration, and returns the newly created
/// account.
///
/// The returned account is persisted with no selected destinations.
///
/// The authentication request is performed by the integration
/// implementation.
///
/// # Arguments
///
/// * `key` - The integration identifier, for example, `"discord"` or
///   `"telegram"`.
/// * `credentials` - Credentials required to authenticate with the integration.
///   Must contain a non-empty `"token"` value.
///
/// # Errors
///
/// Returns an error if:
///
/// * `credentials` does not contain a non-empty `"token"`.
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * Authentication with the external API fails.
/// * The authenticated account cannot be added to the integration
///   configuration.
pub async fn connect_integration_account(
    key: String,
    credentials: HashMap<String, String>,
) -> Result<IntegrationAccount> {
    let token = credentials
        .get("token")
        .filter(|token| !token.trim().is_empty())
        .ok_or_else(|| anyhow!("integration token cannot be empty"))?;

    match key.as_str() {
        "discord" => {
            let mut integration = DiscordIntegration::load()?;

            let mut account = integration.authenticate_account(token).await?;
            account.destinations.clear();

            integration.add_account(account.clone())?;

            Ok(account)
        }

        "telegram" => {
            let mut integration = TelegramIntegration::load()?;

            let mut account = integration.authenticate_account(token).await?;
            account.destinations.clear();

            integration.add_account(account.clone())?;

            Ok(account)
        }

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
/// Returns an [DestinationTestResult] containing:
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
pub async fn test_integration_destination(
    key: String,
    account_id: String,
    destination_id: String,
) -> Result<DestinationTestResult> {
    match key.as_str() {
        "discord" => {
            DiscordIntegration::load()?
                .test_destination(&account_id, &destination_id)
                .await
        }
        "telegram" => {
            TelegramIntegration::load()?
                .test_destination(&account_id, &destination_id)
                .await
        }
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

/// Tests whether a selected account is accessible.
///
/// # Arguments
///
/// * `key` - The integration identifier used to select the platform
///   (for example, `"discord"` or `"telegram"`).
/// * `account_id` - The account identifier to test.
///
/// # Returns
///
/// Returns an [DestinationTestResult] containing:
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
pub async fn test_integration_account(
    key: String,
    account_id: String,
) -> Result<DestinationTestResult> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.test_account(&account_id).await,
        "telegram" => TelegramIntegration::load()?.test_account(&account_id).await,
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
pub async fn send_integration_message(
    key: String,
    account_id: String,
    destination_id: String,
    message: String,
) -> Result<SentMessage> {
    match key.as_str() {
        "discord" => {
            DiscordIntegration::load()?
                .send_message(&account_id, &destination_id, &message)
                .await
        }
        "telegram" => {
            TelegramIntegration::load()?
                .send_message(&account_id, &destination_id, &message)
                .await
        }
        _ => Err(anyhow!("unknown integration: {}", key)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[tokio::test]
    async fn connect_integration_account_rejects_missing_token() {
        let credentials: HashMap<String, String> = HashMap::new();
        let result = connect_integration_account("discord".to_string(), credentials).await;
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("integration token cannot be empty"),
            "Expected 'integration token cannot be empty', got: {}",
            err
        );
    }

    #[tokio::test]
    async fn connect_integration_account_rejects_empty_token() {
        let mut credentials = HashMap::new();
        credentials.insert("token".to_string(), "".to_string());
        let result = connect_integration_account("discord".to_string(), credentials).await;
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("integration token cannot be empty"),
            "Expected 'integration token cannot be empty', got: {}",
            err
        );
    }

    #[tokio::test]
    async fn connect_integration_account_rejects_whitespace_token() {
        let mut credentials = HashMap::new();
        credentials.insert("token".to_string(), "   ".to_string());
        let result = connect_integration_account("discord".to_string(), credentials).await;
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("integration token cannot be empty"),
            "Expected 'integration token cannot be empty', got: {}",
            err
        );
    }

    #[tokio::test]
    async fn connect_integration_account_rejects_unknown_integration() {
        let mut credentials = HashMap::new();
        credentials.insert("token".to_string(), "valid-token".to_string());
        let result = connect_integration_account("unknown_service".to_string(), credentials).await;
        assert!(result.is_err());
        let err = result.unwrap_err().to_string();
        assert!(
            err.contains("unknown integration"),
            "Expected 'unknown integration', got: {}",
            err
        );
        assert!(
            err.contains("unknown_service"),
            "Expected error to name the offending key, got: {}",
            err
        );
    }
}
