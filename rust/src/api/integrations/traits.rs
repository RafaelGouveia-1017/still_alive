use crate::api::data::db::db;
use crate::api::integrations::discord::DiscordIntegration;
use crate::api::integrations::telegram::TelegramIntegration;
use flutter_rust_bridge::frb;

use anyhow::{anyhow, Context, Result};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};

/// Two-color linear gradient used to visually identify an integration.
///
/// Colors are encoded as Flutter-compatible ARGB values (0xAARRGGBB).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct IntegrationGradient {
    pub start: u32,
    pub end: u32,
}

/// User account connected to an integration.
///
/// For example, a Discord account or Telegram account authorized
/// to interact with the application.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationUser {
    pub id: String,
    pub username: String,
}

/// Destination that can receive messages through an integration.
///
/// Discord channels belong to a guild, while platforms without
/// guilds may leave the guild fields empty.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationChannel {
    pub guild_id: Option<String>,
    pub guild_name: Option<String>,
    pub channel_id: String,
    pub channel_name: String,
}

/// Common interface implemented by every messaging integration.
///
/// Implementations are responsible for:
///
/// - loading their configuration from the database;
/// - exposing platform metadata;
/// - exposing connected users;
/// - exposing available message destinations.
#[frb(ignore)]
pub trait Integration: Sized {
    const KEY: &'static str;

    #[frb(ignore)]
    type Config: serde::de::DeserializeOwned;

    #[frb(ignore)]
    fn from_config(config: Self::Config) -> Self;

    #[frb(ignore)]
    fn load() -> anyhow::Result<Self> {
        let config = load_config(Self::KEY)?;
        Ok(Self::from_config(config))
    }

    #[frb(ignore)]
    fn title(&self) -> &'static str;

    #[frb(ignore)]
    fn gradient(&self) -> IntegrationGradient;

    #[frb(ignore)]
    fn users(&self) -> Vec<IntegrationUser>;

    #[frb(ignore)]
    fn channels(&self) -> Vec<IntegrationChannel>;

    #[frb(ignore)]
    fn connected(&self) -> bool {
        !self.users().is_empty() || !self.channels().is_empty()
    }

    #[frb(ignore)]
    fn info(&self) -> IntegrationInfo {
        IntegrationInfo {
            key: Self::KEY.to_owned(),
            title: self.title().to_owned(),
            gradient: self.gradient(),
            connected: self.connected(),
            users: self.users(),
            channels: self.channels(),
        }
    }

    #[frb(ignore)]
    fn delete(&mut self, id: &str) -> Result<()>;

    #[frb(ignore)]
    fn test(&self, id: &str) -> Result<IntegrationTestResult>;

    #[frb(ignore)]
    fn send(&self, recipient_id: &str, message: &str) -> Result<()>;
}

/// Loads and deserializes an integration configuration from the database.
///
/// The configuration is read from the `integrations` table using the
/// provided integration key and deserialized into the requested type.
///
/// # Errors
///
/// Returns an error if:
///
/// - the integration does not exist;
/// - the configuration is invalid JSON;
/// - deserialization fails.
#[frb(ignore)]
fn load_config<T: DeserializeOwned>(key: &str) -> Result<T> {
    let db = db();

    let json: String = db
        .as_ref()
        .unwrap()
        .query_one(
            "SELECT value FROM integrations WHERE key = ?1",
            [key],
            |row| row.get(0),
        )?
        .context("integration not found")?;

    Ok(serde_json::from_str(&json)?)
}

/// Saves an integration configuration to the application database.
///
/// The configuration is serialized into JSON and stored in the `integrations`
/// table using the provided integration key.
///
/// # Arguments
///
/// * `key` - The integration identifier used as the database primary key
///   (for example, `"discord"` or `"telegram"`).
/// * `config` - The integration configuration that will be serialized and saved.
///
/// # Errors
///
/// Returns an error if:
///
/// * The configuration cannot be serialized into JSON.
/// * The database update operation fails.
///
/// # Notes
///
/// This function updates an existing integration record. It does not create a
/// new database entry if the provided key does not exist.
#[frb(ignore)]
pub fn save_config<T: Serialize>(key: &str, config: &T) -> Result<()> {
    let db = db();

    let json = serde_json::to_string(config)?;

    db.as_ref().unwrap().execute(
        "UPDATE integrations SET value = ?1 WHERE key = ?2",
        [&json, key],
    )?;

    Ok(())
}

/// Summary of an integration exposed through Flutter Rust Bridge.
///
/// This structure contains metadata together with the connected users
/// and available message destinations required by the Flutter UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationInfo {
    pub key: String,
    pub title: String,
    pub gradient: IntegrationGradient,
    pub connected: bool,
    pub users: Vec<IntegrationUser>,
    pub channels: Vec<IntegrationChannel>,
}

/// Returns information about every supported integration.
///
/// Integrations that are not configured are still returned with empty
/// user and channel lists.
pub fn load_all_integrations() -> Result<Vec<IntegrationInfo>> {
    Ok(vec![
        DiscordIntegration::load()?.info(),
        TelegramIntegration::load()?.info(),
    ])
}

/// Deletes a user or channel record from an integration configuration.
///
/// The target integration is loaded from the database, the matching record is
/// removed using the provided identifier, and the updated configuration is
/// persisted back to the database.
///
/// # Arguments
///
/// * `key` - The integration identifier (for example, `"discord"` or
///   `"telegram"`).
/// * `id` - The user or channel identifier to remove.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * The updated configuration cannot be saved.
pub fn delete_integration_record(key: String, id: String) -> Result<()> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.delete(&id),
        "telegram" => TelegramIntegration::load()?.delete(&id),
        _ => Err(anyhow!("unknown integration")),
    }
}

/// Result of testing an integration connection.
///
/// Contains whether the connection succeeded and an optional
/// human-readable message describing the result.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationTestResult {
    pub connected: bool,
    pub message: String,
}

/// Tests whether an integration connection is available.
///
/// Loads the requested integration and executes its connection test logic.
/// The returned result contains both the connection status and a descriptive
/// message explaining the outcome.
///
/// # Arguments
///
/// * `key` - The integration identifier used to select the platform
///   (for example, `"discord"` or `"telegram"`).
/// * `id` - The platform-specific user or channel identifier to test.
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
pub fn test_integration_connection(key: String, id: String) -> Result<IntegrationTestResult> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.test(&id),
        "telegram" => TelegramIntegration::load()?.test(&id),
        _ => Err(anyhow!("unknown integration")),
    }
}

/// Sends a message through an integration to a recipient.
///
/// The integration is loaded using the provided key and delegates the send
/// operation to the platform-specific implementation.
///
/// # Arguments
///
/// * `key` - The integration identifier used to select the platform.
/// * `recipient_id` - The platform-specific recipient identifier.
/// * `message` - The message content to send.
///
/// # Errors
///
/// Returns an error if:
///
/// * The integration key is unknown.
/// * The integration configuration cannot be loaded.
/// * Authentication fails.
/// * The recipient cannot be reached.
/// * Sending the message fails.
pub fn send_integration_message(key: String, recipient_id: String, message: String) -> Result<()> {
    match key.as_str() {
        "discord" => DiscordIntegration::load()?.send(&recipient_id, &message),
        "telegram" => TelegramIntegration::load()?.send(&recipient_id, &message),
        _ => Err(anyhow!("unknown integration")),
    }
}
