use crate::api::integrations::traits::*;
use flutter_rust_bridge::frb;

use anyhow::{anyhow, Ok, Result};
use reqwest::{header, Client};
use serde::{Deserialize, Serialize};

/// Persisted Discord integration configuration.
///
/// Only connected accounts and explicitly selected destinations are stored.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct DiscordConfig {
    pub accounts: Vec<DiscordAccount>,
}

/// A connected Discord account and its selected message destinations.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct DiscordAccount {
    pub id: String,
    pub app_id: String,
    pub name: String,

    /// Destinations explicitly selected by the user.
    pub destinations: Vec<MessageDestination>,
}

/// Discord implementation of the [`Integration`] trait.
#[frb(ignore)]
pub struct DiscordIntegration {
    pub config: DiscordConfig,
}

/// Persisted Discord integration configuration.
///
/// This structure mirrors the JSON stored in the `integrations` table.
impl Integration for DiscordIntegration {
    const KEY: &'static str = "discord";
    type Config = DiscordConfig;

    fn title(&self) -> &'static str {
        "Discord"
    }

    fn provider(&self) -> IntegrationProvider {
        IntegrationProvider::Discord
    }

    fn from_config(config: DiscordConfig) -> Self {
        Self { config }
    }

    fn gradient(&self) -> IntegrationGradient {
        IntegrationGradient {
            start: 0xFF5865F2,
            end: 0xFF394196,
        }
    }

    fn accounts(&self) -> Vec<IntegrationAccount> {
        log::info!("Starting accounts in {}", self.title());

        self.config
            .accounts
            .iter()
            .filter(|account| account.id != "example")
            .map(|account| {
                let mut destinations = account.destinations.clone();

                destinations.sort_by(|a, b| {
                    a.parent_name
                        .cmp(&b.parent_name)
                        .then_with(|| a.name.cmp(&b.name))
                });

                IntegrationAccount {
                    id: account.id.clone(),
                    name: account.name.clone(),
                    app_id: Some(account.app_id.clone()),
                    destinations,
                }
            })
            .collect()
    }

    async fn authenticate_account(&self, credential: &str) -> Result<IntegrationAccount> {
        log::info!("Starting authenticate_account in {}", self.title());

        if credential.trim().is_empty() {
            return Err(anyhow!("Discord bot token cannot be empty"));
        }

        let client = Client::new();

        let response = client
            .get(discord_url("users/@me"))
            .header(header::AUTHORIZATION, format!("Bot {}", credential))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Discord authentication failed with HTTP {}",
                response.status()
            ));
        }

        let user: DiscordUser = response.json().await?;

        if user.bot != Some(true) {
            return Err(anyhow!("Discord credential does not belong to a bot"));
        }

        let name = user
            .global_name
            .unwrap_or_else(|| user.username + "#" + &user.discriminator);

        Ok(IntegrationAccount {
            id: credential.to_owned(),
            name,
            destinations: Vec::new(),
            app_id: Some(user.id),
        })
    }

    async fn discover_destinations(&mut self, account_id: &str) -> Result<Vec<MessageDestination>> {
        log::info!("Starting discover_destinations in {}", self.title());

        let account_index = self
            .config
            .accounts
            .iter()
            .position(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let credential = self.config.accounts[account_index].id.clone();

        let client = Client::new();
        let auth_header = format!("Bot {}", credential);

        // ---------------------------------------------------------
        // 1. Get guilds the bot belongs to.
        // ---------------------------------------------------------

        let guilds_response = client
            .get(discord_url("users/@me/guilds"))
            .header(header::AUTHORIZATION, &auth_header)
            .send()
            .await?;

        if !guilds_response.status().is_success() {
            return Err(anyhow!(
                "Discord guild discovery failed with HTTP {}",
                guilds_response.status()
            ));
        }

        let guilds: Vec<DiscordGuild> = guilds_response.json().await?;

        let mut destinations = Vec::new();

        // Keep track of guilds that are actually accessible.
        let mut accessible_guild_ids = std::collections::HashSet::new();

        // Keep track of channels that are currently accessible.
        let mut accessible_channel_ids = std::collections::HashSet::new();

        // ---------------------------------------------------------
        // 2. Get channels for every guild.
        // ---------------------------------------------------------

        for guild in guilds {
            let guild_id = guild.id.clone();

            let url = discord_url(format!("guilds/{}/channels", guild.id).as_str());

            let channels_response = client
                .get(url)
                .header(header::AUTHORIZATION, &auth_header)
                .send()
                .await?;

            if !channels_response.status().is_success() {
                log::warn!(
                    "Failed to discover Discord channels for guild {}: HTTP {}",
                    guild.id,
                    channels_response.status()
                );

                continue;
            }

            accessible_guild_ids.insert(guild_id.clone());

            let channels: Vec<DiscordChannel> = channels_response.json().await?;

            for channel in channels {
                // https://docs.discord.com/developers/resources/channel#channel-object-channel-types
                let kind = match channel.channel_type {
                    0 | 5 => DestinationKind::ServerChannel,
                    3 => DestinationKind::Group,
                    _ => continue,
                };

                accessible_channel_ids.insert(channel.id.clone());

                destinations.push(MessageDestination {
                    id: channel.id,
                    name: channel.name.unwrap_or_else(|| "Unnamed Channel".into()),
                    kind,
                    parent_id: Some(guild.id.clone()),
                    parent_name: Some(guild.name.clone()),
                });
            }
        }

        destinations.sort_by(|a, b| {
            a.parent_name
                .cmp(&b.parent_name)
                .then_with(|| a.name.cmp(&b.name))
        });

        self.config.accounts[account_index].destinations = destinations.clone();

        save_config(Self::KEY, &self.config)?;

        Ok(destinations)
    }

    fn add_account(&mut self, account: IntegrationAccount) -> Result<IntegrationAccount> {
        log::info!("Starting add_account in {}", self.title());

        if account.id.trim().is_empty() {
            return Err(anyhow!("Discord bot token cannot be empty"));
        }

        if self
            .config
            .accounts
            .iter()
            .any(|existing| existing.id == account.id)
        {
            return Err(anyhow!("Discord account already connected: {}", account.id));
        }

        let account = DiscordAccount {
            id: account.id,
            app_id: account.app_id.unwrap(),
            name: account.name,
            destinations: account.destinations,
        };

        self.config.accounts.push(account.clone());

        save_config(Self::KEY, &self.config)?;

        Ok(IntegrationAccount {
            id: account.id,
            name: account.name,
            app_id: Some(account.app_id.clone()),
            destinations: account.destinations,
        })
    }

    fn remove_account(&mut self, account_id: &str) -> Result<()> {
        log::info!("Starting remove_account in {}", self.title());

        let original_len = self.config.accounts.len();

        self.config
            .accounts
            .retain(|account| account.id != account_id);

        if self.config.accounts.len() == original_len {
            return Err(anyhow!("Discord account not found: {}", account_id));
        }

        save_config(Self::KEY, &self.config)?;

        Ok(())
    }

    async fn send_message(
        &self,
        account_id: &str,
        destination_id: &str,
        message: &str,
    ) -> Result<SentMessage> {
        log::info!("Starting send_message in {}", self.title());

        let account = self
            .config
            .accounts
            .iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let destination = account
            .destinations
            .iter()
            .find(|destination| destination.id == destination_id)
            .ok_or_else(|| anyhow!("Discord destination is not selected: {}", destination_id))?;

        if message.trim().is_empty() {
            return Err(anyhow!("message cannot be empty"));
        }

        let credential = &account.id;

        let client = Client::new();

        let url = discord_url(format!("channels/{}/messages", destination.id).as_str());

        let response = client
            .post(url)
            .header(header::AUTHORIZATION, format!("Bot {}", credential))
            .json(&DiscordCreateMessage { content: message })
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();

            return Err(anyhow!(
                "Discord send message failed with HTTP {}: {}",
                status,
                body
            ));
        }

        let sent: DiscordMessage = response.json().await?;

        Ok(SentMessage {
            provider: IntegrationProvider::Discord,
            destination_id: destination.id.clone(),
            message_id: Some(sent.id),
        })
    }

    async fn test_destination(
        &self,
        account_id: &str,
        destination_id: &str,
    ) -> Result<DestinationTestResult> {
        log::info!("Starting test_destination in {}", self.title());

        let account = self
            .config
            .accounts
            .iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let destination = account
            .destinations
            .iter()
            .find(|destination| destination.id == destination_id)
            .ok_or_else(|| anyhow!("Discord destination is not selected: {}", destination_id))?;

        let credential = &account.id;

        let client = Client::new();

        let url = discord_url(format!("channels/{}", destination.id).as_str());

        let response = client
            .get(url)
            .header(header::AUTHORIZATION, format!("Bot {}", credential))
            .send()
            .await?;

        if response.status().is_success() {
            Ok(DestinationTestResult {
                can_send: true,
                message: "Discord destination is accessible.".into(),
            })
        } else {
            Ok(DestinationTestResult {
                can_send: false,
                message: format!("Discord destination returned HTTP {}.", response.status()),
            })
        }
    }

    async fn test_account(&self, account_id: &str) -> Result<DestinationTestResult> {
        log::info!("Starting test_account in {}", self.title());

        let account = self
            .config
            .accounts
            .iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let credential = &account.id;

        let client = Client::new();

        let response = client
            .get(discord_url("users/@me"))
            .header(header::AUTHORIZATION, format!("Bot {}", credential))
            .send()
            .await?;

        if response.status().is_success() {
            Ok(DestinationTestResult {
                can_send: true,
                message: "Discord account is accessible.".into(),
            })
        } else {
            Ok(DestinationTestResult {
                can_send: false,
                message: format!("Discord account returned HTTP {}.", response.status()),
            })
        }
    }
}

/// Builds the URL for a Discord API v10 endpoint.
///
/// # Arguments
///
/// * `method` - The API path relative to the Discord API v10 base URL.
///
/// # Examples
///
/// ```
/// let url = discord_url("users/@me");
/// assert_eq!(
///     url,
///     "https://discord.com/api/v10/users/@me"
/// );
/// ```
#[frb(ignore)]
fn discord_url(method: &str) -> String {
    format!("https://discord.com/api/v10/{}", method)
}

/// Discord user or bot identity returned by the API.
///
/// This structure is primarily used to authenticate a bot token and obtain
/// the bot's display identity.
#[derive(Debug, Deserialize)]
#[frb(ignore)]
struct DiscordUser {
    /// Discord application id.
    id: String,

    /// Discord username.
    username: String,

    /// Username discriminator associated with the account.
    discriminator: String,

    /// Optional display name associated with the account.
    #[serde(default)]
    global_name: Option<String>,

    /// Whether the Discord account is a bot.
    #[serde(default)]
    bot: Option<bool>,
}

/// Discord guild (server) returned by the API.
///
/// A guild represents a Discord server that the authenticated bot belongs to.
#[derive(Debug, Deserialize)]
#[frb(ignore)]
struct DiscordGuild {
    /// Unique Discord identifier of the guild.
    id: String,

    /// Display name of the guild.
    name: String,
}

/// Discord channel returned by the API.
///
/// Only the fields required by the integration layer are represented here.
/// The numeric `channel_type` determines whether the channel is a text
/// channel, DM, group DM, or another Discord channel type.
#[derive(Debug, Deserialize)]
#[frb(ignore)]
struct DiscordChannel {
    /// Unique Discord identifier of the channel.
    id: String,

    /// Optional display name of the channel.
    ///
    /// DM channels may not have a conventional channel name.
    name: Option<String>,

    /// Discord numeric channel type.
    ///
    /// For example, `0` represents a guild text channel, `1` a DM, and `3`
    /// a group DM.
    #[serde(rename = "type")]
    channel_type: i32,
}

/// Discord message returned after successfully creating a message.
#[derive(Debug, Deserialize)]
#[frb(ignore)]
struct DiscordMessage {
    /// Unique Discord identifier of the newly created message.
    id: String,
}

/// Request body for Discord's create-message endpoint.
///
/// The lifetime parameter allows the request to borrow the message content
/// without allocating an owned copy.
#[derive(Debug, Serialize)]
#[frb(ignore)]
struct DiscordCreateMessage<'a> {
    /// Message content to send to the Discord channel.
    content: &'a str,
}
