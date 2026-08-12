use crate::api::data::db::db;
use flutter_rust_bridge::frb;

use anyhow::{Context, Result};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};

/// Supported messaging providers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum IntegrationProvider {
    Discord,
    Telegram,
}

/// Two-color linear gradient used to visually identify an integration.
///
/// Colors are encoded as Flutter-compatible ARGB values (0xAARRGGBB).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct IntegrationGradient {
    pub start: u32,
    pub end: u32,
}

/// Kind of resource that can receive a message.
///
/// This deliberately describes the application's messaging model rather
/// than mirroring a provider's API types.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DestinationKind {
    DirectMessage,
    Group,
    Channel,
    ServerChannel,
}

/// A message destination discovered from a messaging provider.
///
/// `parent_id` and `parent_name` are optional metadata. For example, a
/// Discord server channel has its guild as its parent, while a DM does not.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageDestination {
    pub id: String,
    pub name: String,
    pub kind: DestinationKind,

    pub parent_id: Option<String>,
    pub parent_name: Option<String>,
}

/// A connected account belonging to a messaging provider.
///
/// Only destinations explicitly selected by the user are persisted here.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationAccount {
    pub id: String,
    pub name: String,
    pub destinations: Vec<MessageDestination>,
}

/// Public integration metadata exposed to Flutter.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IntegrationInfo {
    pub key: String,
    pub title: String,
    pub gradient: IntegrationGradient,
    pub provider: IntegrationProvider,
    pub connected: bool,
    pub accounts: Vec<IntegrationAccount>,
}

/// A message returned after sending.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SentMessage {
    pub provider: IntegrationProvider,
    pub destination_id: String,
    pub message_id: Option<String>,
}

/// Result of testing a destination.
///
/// Contains whether the connection succeeded and an optional
/// human-readable message describing the result.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DestinationTestResult {
    pub can_send: bool,
    pub message: String,
}

/// Platform-specific integration implementation.
///
/// The important distinction is that discovery does NOT mutate persisted
/// configuration. The user first discovers available destinations and then
/// explicitly selects which destinations should be persisted.
#[frb(ignore)]
pub trait Integration: Sized {
    const KEY: &'static str;

    #[frb(ignore)]
    type Config: DeserializeOwned;

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
    fn provider(&self) -> IntegrationProvider;

    #[frb(ignore)]
    fn gradient(&self) -> IntegrationGradient;

    /// Returns accounts currently connected to this provider.
    #[frb(ignore)]
    fn accounts(&self) -> Vec<IntegrationAccount>;

    /// Whether at least one account is connected.
    #[frb(ignore)]
    fn connected(&self) -> bool {
        !self.accounts().is_empty()
    }

    #[frb(ignore)]
    fn info(&self) -> IntegrationInfo {
        IntegrationInfo {
            key: Self::KEY.to_owned(),
            title: self.title().to_owned(),
            gradient: self.gradient(),
            provider: self.provider(),
            connected: self.connected(),
            accounts: self.accounts(),
        }
    }

    /// Obtains the currently authenticated account from the provider.
    ///
    /// This performs external API/authentication work but does not mutate
    /// application configuration.
    #[frb(ignore)]
    fn authenticate_account(&self) -> Result<IntegrationAccount>;

    /// Discovers destinations available to an account.
    ///
    /// The result is temporary discovery data. It is NOT automatically
    /// persisted or treated as application permission.
    #[frb(ignore)]
    fn discover_destinations(&self, account_id: &str) -> Result<Vec<MessageDestination>>;

    /// Adds one explicitly selected destination to an account.
    #[frb(ignore)]
    fn add_destination(
        &mut self,
        account_id: &str,
        destination: MessageDestination,
    ) -> Result<IntegrationAccount>;

    /// Removes an explicitly selected destination.
    #[frb(ignore)]
    fn remove_destination(
        &mut self,
        account_id: &str,
        destination_id: &str,
    ) -> Result<IntegrationAccount>;

    /// Adds an authenticated account to persisted configuration.
    #[frb(ignore)]
    fn add_account(&mut self, account: IntegrationAccount) -> Result<IntegrationAccount>;

    /// Removes an account and all of its selected destinations.
    #[frb(ignore)]
    fn remove_account(&mut self, account_id: &str) -> Result<()>;

    /// Sends a message through this provider.
    ///
    /// The implementation must verify that the destination is explicitly
    /// selected for the account before sending.
    #[frb(ignore)]
    fn send_message(
        &self,
        account_id: &str,
        destination_id: &str,
        message: &str,
    ) -> Result<SentMessage>;

    /// Tests whether a specific destination can currently receive a message.
    ///
    /// This must verify both:
    ///
    /// 1. The destination is explicitly selected for the account.
    /// 2. The provider currently allows the connected account to send to it.
    ///
    /// Implementations should avoid actually sending a user-visible message.
    /// Provider-specific permission/access checks should be used where possible.
    #[frb(ignore)]
    fn test_destination(
        &self,
        account_id: &str,
        destination_id: &str,
    ) -> Result<DestinationTestResult>;
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
