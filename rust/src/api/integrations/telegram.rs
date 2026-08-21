use crate::api::integrations::traits::*;
use flutter_rust_bridge::frb;

use anyhow::{anyhow, Ok, Result};
use reqwest::Client;
use serde::{Deserialize, Serialize};

/// Persisted Telegram integration configuration.
///
/// Only connected accounts and explicitly selected destinations are stored.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct TelegramConfig {
    pub accounts: Vec<TelegramAccount>,
}

/// A connected Telegram account and its selected destinations.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct TelegramAccount {
    pub id: String,
    pub name: String,

    #[serde(default)]
    pub update_offset: i64,

    pub destinations: Vec<MessageDestination>,
}

/// Telegram implementation of the [`Integration`] trait.
#[frb(ignore)]
pub struct TelegramIntegration {
    pub config: TelegramConfig,
}

/// Persisted Telegram integration configuration.
///
/// This structure mirrors the JSON stored in the `integrations` table.
impl Integration for TelegramIntegration {
    const KEY: &'static str = "telegram";
    type Config = TelegramConfig;

    fn title(&self) -> &'static str {
        "Telegram"
    }

    fn provider(&self) -> IntegrationProvider {
        IntegrationProvider::Telegram
    }

    fn from_config(config: TelegramConfig) -> Self {
        Self { config }
    }

    fn gradient(&self) -> IntegrationGradient {
        IntegrationGradient {
            start: 0xFF29A8EB,
            end: 0xFF1E719E,
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

                destinations.retain_mut(|d| {
                    if d.id == "example" {
                        return false;
                    }
                    true
                });

                destinations.sort_by(|a, b| a.name.cmp(&b.name));

                IntegrationAccount {
                    id: account.id.clone(),
                    name: account.name.clone(),
                    destinations,
                }
            })
            .collect()
    }

    async fn authenticate_account(&self, credential: &str) -> Result<IntegrationAccount> {
        log::info!("Starting authenticate_account in {}", self.title());

        if credential.trim().is_empty() {
            return Err(anyhow!("Telegram bot token cannot be empty"));
        }

        let client = Client::new();

        let response = client.get(telegram_url(credential, "getMe")).send().await?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Telegram authentication failed with HTTP {}",
                response.status()
            ));
        }

        let body: TelegramResponse<TelegramUser> = response.json().await?;

        if !body.ok {
            return Err(anyhow!(
                "Telegram authentication failed: {}",
                body.description.unwrap_or_else(|| "unknown error".into())
            ));
        }

        let bot = body
            .result
            .ok_or_else(|| anyhow!("Telegram returned no bot information"))?;

        if !bot.is_bot {
            return Err(anyhow!("Telegram credential does not belong to a bot"));
        }

        Ok(IntegrationAccount {
            id: credential.to_owned(),
            name: bot
                .username
                .map(|username| format!("@{}", username))
                .unwrap_or(bot.first_name),
            destinations: Vec::new(),
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
        let update_offset = self.config.accounts[account_index].update_offset + 1;

        let client = Client::new();

        // ---------------------------------------------------------
        // Discover destinations from getUpdates.
        // ---------------------------------------------------------

        let response = client
            .post(telegram_url(credential.as_str(), "getUpdates"))
            .json(&serde_json::json!({
                "offset": update_offset,
                "limit": 100,
                "timeout": 1,
                "allowed_updates": [
                    "message",
                    "my_chat_member"
                ]
            }))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!(
                "Telegram update discovery failed with HTTP {}",
                response.status()
            ));
        }

        let body: TelegramResponse<Vec<TelegramUpdate>> = response.json().await?;

        if !body.ok {
            return Err(anyhow!(
                "Telegram update discovery failed: {}",
                body.description.unwrap_or_else(|| "unknown error".into())
            ));
        }

        let updates = body.result.unwrap_or_default();

        let mut discovered_destinations = Vec::new();

        for update in updates {
            let chat = update
                .my_chat_member
                .map(|member| member.chat)
                .or_else(|| update.message.map(|message| message.chat));

            let Some(chat) = chat else {
                continue;
            };

            let kind = match chat.chat_type.as_str() {
                "private" => DestinationKind::DirectMessage,
                "group" | "supergroup" => DestinationKind::Group,
                "channel" => DestinationKind::Channel,
                _ => DestinationKind::Group,
            };

            let name = chat
                .title
                .or_else(|| chat.username.map(|username| format!("@{}", username)))
                .or_else(|| {
                    let full_name = format!(
                        "{} {}",
                        chat.first_name.unwrap_or_default(),
                        chat.last_name.unwrap_or_default()
                    )
                    .trim()
                    .to_owned();

                    if full_name.is_empty() {
                        None
                    } else {
                        Some(full_name)
                    }
                })
                .unwrap_or_else(|| "Unnamed Channel".to_string());

            let destination = MessageDestination {
                id: chat.id.to_string(),
                name,
                kind,
                parent_id: None,
                parent_name: None,
            };

            if !discovered_destinations
                .iter()
                .any(|existing: &MessageDestination| existing.id == destination.id)
            {
                discovered_destinations.push(destination);
            }
        }

        // ---------------------------------------------------------
        // Reconcile destinations that are already persisted.
        //
        // getUpdates is NOT a complete list of chats, so every persisted
        // destination must be checked independently with getChat.
        // ---------------------------------------------------------

        // Take the old persisted destinations out of the account.
        let persisted_destinations =
            std::mem::take(&mut self.config.accounts[account_index].destinations);

        let mut valid_persisted_destinations = Vec::with_capacity(persisted_destinations.len());

        for mut destination in persisted_destinations {
            let response = match client
                .post(telegram_url(&credential, "getChat"))
                .json(&TelegramGetChatRequest {
                    chat_id: &destination.id,
                })
                .send()
                .await
            {
                Result::Ok(response) => response,
                Err(error) => {
                    // A network error is not proof that the destination was
                    // deleted/inaccessible, so keep it.
                    log::info!(
                        "Failed to validate Telegram destination {}: {}",
                        destination.id,
                        error
                    );

                    valid_persisted_destinations.push(destination);
                    continue;
                }
            };

            if response.status().is_server_error() {
                log::warn!(
                    "Telegram server error while validating destination {}: HTTP {}",
                    destination.id,
                    response.status()
                );

                valid_persisted_destinations.push(destination);
                continue;
            }

            if !response.status().is_success() {
                log::info!(
                    "Removing inaccessible Telegram destination {}: HTTP {}",
                    destination.id,
                    response.status()
                );
                continue;
            }

            let body: TelegramResponse<TelegramChat> = match response.json().await {
                Result::Ok(body) => body,
                Err(error) => {
                    log::warn!(
                        "Failed to parse Telegram destination {} response: {}",
                        destination.id,
                        error
                    );

                    valid_persisted_destinations.push(destination);
                    continue;
                }
            };

            if !body.ok {
                log::info!(
                    "Removing inaccessible Telegram destination {}: {}",
                    destination.id,
                    body.description
                        .unwrap_or_else(|| "unknown Telegram error".into())
                );
                continue;
            }

            let Some(chat) = body.result else {
                log::warn!(
                    "Telegram returned no chat information for destination {}",
                    destination.id
                );

                valid_persisted_destinations.push(destination);
                continue;
            };

            let current_name = chat
                .title
                .or_else(|| chat.username.map(|username| format!("@{}", username)))
                .or_else(|| {
                    let full_name = format!(
                        "{} {}",
                        chat.first_name.unwrap_or_default(),
                        chat.last_name.unwrap_or_default()
                    )
                    .trim()
                    .to_owned();

                    if full_name.is_empty() {
                        None
                    } else {
                        Some(full_name)
                    }
                })
                .unwrap_or_else(|| "Unnamed Channel".to_string());

            if destination.name != current_name {
                log::info!(
                    "Updating Telegram destination {} name: '{}' -> '{}'",
                    destination.id,
                    destination.name,
                    current_name
                );

                destination.name = current_name;
            }

            valid_persisted_destinations.push(destination);
        }

        // ---------------------------------------------------------
        // Add all still-valid persisted destinations to the discovery
        // result. This ensures discovery returns every destination the
        // bot can currently access, including destinations for which
        // Telegram did not return an update this time.
        // ---------------------------------------------------------

        let mut destinations = discovered_destinations;

        for persisted in valid_persisted_destinations {
            if !destinations
                .iter()
                .any(|destination| destination.id == persisted.id)
            {
                destinations.push(persisted);
            }
        }

        destinations.sort_by(|a, b| a.name.cmp(&b.name));

        self.config.accounts[account_index].update_offset += 1;
        self.config.accounts[account_index].destinations = destinations.clone();

        save_config(Self::KEY, &self.config)?;

        Ok(destinations)
    }

    fn add_account(&mut self, account: IntegrationAccount) -> Result<IntegrationAccount> {
        log::info!("Starting add_account in {}", self.title());

        if account.id.trim().is_empty() {
            return Err(anyhow!("Telegram bot token cannot be empty"));
        }

        if self
            .config
            .accounts
            .iter()
            .any(|existing| existing.id == account.id)
        {
            return Err(anyhow!(
                "Telegram account already connected: {}",
                account.id
            ));
        }

        let account = TelegramAccount {
            id: account.id,
            name: account.name,
            update_offset: 0,
            destinations: account.destinations,
        };

        self.config.accounts.push(account.clone());

        save_config(Self::KEY, &self.config)?;

        Ok(IntegrationAccount {
            id: account.id,
            name: account.name,
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
            return Err(anyhow!("Telegram account not found: {}", account_id));
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
            .ok_or_else(|| anyhow!("Telegram account not found: {}", account_id))?;

        let destination = account
            .destinations
            .iter()
            .find(|destination| destination.id == destination_id)
            .ok_or_else(|| anyhow!("Telegram destination is not selected: {}", destination_id))?;

        if message.trim().is_empty() {
            return Err(anyhow!("message cannot be empty"));
        }

        let credential = &account.id;

        let client = Client::new();

        let response = client
            .post(telegram_url(credential, "sendMessage"))
            .json(&TelegramSendMessageRequest {
                chat_id: &destination.id,
                text: message,
            })
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();

            return Err(anyhow!(
                "Telegram send message failed with HTTP {}: {}",
                status,
                body
            ));
        }

        let body: TelegramResponse<TelegramSentMessage> = response.json().await?;

        if !body.ok {
            return Err(anyhow!(
                "Telegram send message failed: {}",
                body.description.unwrap_or_else(|| "unknown error".into())
            ));
        }

        let sent = body
            .result
            .ok_or_else(|| anyhow!("Telegram returned no sent message"))?;

        Ok(SentMessage {
            provider: IntegrationProvider::Telegram,
            destination_id: destination.id.clone(),
            message_id: Some(sent.message_id.to_string()),
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
            .ok_or_else(|| anyhow!("Telegram account not found: {}", account_id))?;

        let destination = account
            .destinations
            .iter()
            .find(|destination| destination.id == destination_id)
            .ok_or_else(|| anyhow!("Telegram destination is not selected: {}", destination_id))?;

        let credential = &account.id;

        let client = Client::new();

        let response = client
            .post(telegram_url(credential, "getChat"))
            .json(&TelegramGetChatRequest {
                chat_id: &destination.id,
            })
            .send()
            .await?;

        if !response.status().is_success() {
            return Ok(DestinationTestResult {
                can_send: false,
                message: format!("Telegram returned HTTP {}.", response.status()),
            });
        }

        let body: TelegramResponse<TelegramChat> = response.json().await?;

        if !body.ok {
            return Ok(DestinationTestResult {
                can_send: false,
                message: body
                    .description
                    .unwrap_or_else(|| "Telegram destination is inaccessible.".into()),
            });
        }

        Ok(DestinationTestResult {
            can_send: true,
            message: "Telegram destination is accessible.".into(),
        })
    }

    async fn test_account(&self, account_id: &str) -> Result<DestinationTestResult> {
        log::info!("Starting test_account in {}", self.title());

        let account = self
            .config
            .accounts
            .iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Telegram account not found: {}", account_id))?;

        let credential = &account.id;

        let client = Client::new();

        let response = client.get(telegram_url(credential, "getMe")).send().await?;

        if !response.status().is_success() {
            return Ok(DestinationTestResult {
                can_send: false,
                message: format!("Telegram returned HTTP {}.", response.status()),
            });
        }

        let body: TelegramResponse<TelegramUser> = response.json().await?;

        if !body.ok {
            return Ok(DestinationTestResult {
                can_send: false,
                message: body
                    .description
                    .unwrap_or_else(|| "Telegram account is inaccessible.".into()),
            });
        }

        Ok(DestinationTestResult {
            can_send: true,
            message: "Telegram account is accessible.".into(),
        })
    }
}

/// Builds the URL for a Telegram Bot API method.
///
/// The returned URL includes the bot token in the path, as required by the
/// Telegram Bot API.
///
/// # Arguments
///
/// * `token` - The Telegram bot token used to authenticate the request.
/// * `method` - The Bot API method to invoke, such as `getMe`, `getUpdates`,
///   `getChat`, or `sendMessage`.
///
/// # Examples
///
/// ```
/// let url = telegram_url("123456:ABC", "getMe");
/// assert_eq!(
///     url,
///     "https://api.telegram.org/bot123456:ABC/getMe"
/// );
/// ```
#[frb(ignore)]
fn telegram_url(token: &str, method: &str) -> String {
    format!("https://api.telegram.org/bot{}/{}", token, method)
}

/// Generic response envelope returned by the Telegram Bot API.
///
/// Telegram wraps successful and failed method responses in an object
/// containing an `ok` flag. Successful responses normally contain `result`,
/// while failed responses may contain a human-readable `description`.
///
/// # Type Parameters
///
/// * `T` - The type of the method-specific `result` payload.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramResponse<T> {
    /// Whether the Telegram API request succeeded.
    ok: bool,

    /// The method-specific response payload when the request succeeds.
    #[serde(default)]
    result: Option<T>,

    /// Human-readable error description returned by Telegram when available.
    #[serde(default)]
    description: Option<String>,
}

/// Telegram bot or user identity returned by the Bot API.
///
/// This structure represents the identity returned by methods such as
/// `getMe`.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramUser {
    /// Whether this Telegram account is a bot.
    #[serde(default)]
    is_bot: bool,

    /// First name of the Telegram account.
    first_name: String,

    /// Optional Telegram username without the `@` prefix.
    #[serde(default)]
    username: Option<String>,
}

/// Telegram chat metadata returned by the Bot API.
///
/// A chat can represent a private conversation, group, supergroup, or
/// channel. The `chat_type` field identifies which kind of chat it is.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramChat {
    /// Unique Telegram identifier of the chat.
    id: i64,

    /// Telegram chat type, such as `private`, `group`, `supergroup`, or
    /// `channel`.
    #[serde(rename = "type")]
    chat_type: String,

    /// Display title for group, supergroup, and channel chats.
    #[serde(default)]
    title: Option<String>,

    /// Optional Telegram username without the `@` prefix.
    #[serde(default)]
    username: Option<String>,

    /// First name of a private chat participant, when applicable.
    #[serde(default)]
    first_name: Option<String>,

    /// Last name of a private chat participant, when applicable.
    #[serde(default)]
    last_name: Option<String>,
}

/// A Telegram message returned as part of an update.
///
/// Only the fields required by the integration layer are represented here.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramMessage {
    /// Chat in which the message was sent.
    chat: TelegramChat,
}

/// Telegram `my_chat_member` update payload.
///
/// This update is emitted when the bot's membership or status in a chat
/// changes.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramChatMemberUpdate {
    /// Chat whose membership state changed.
    chat: TelegramChat,
}

/// An update returned by Telegram's `getUpdates` method.
///
/// The integration uses updates to discover chats that the bot has interacted
/// with or whose membership has changed.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramUpdate {
    /// Message associated with the update, when the update contains a
    /// message.
    #[serde(default)]
    message: Option<TelegramMessage>,

    /// Bot membership change associated with the update, when present.
    #[serde(default)]
    my_chat_member: Option<TelegramChatMemberUpdate>,
}

/// Telegram message returned after successfully sending a message.
///
/// This contains the identifier assigned to the newly created message.
#[derive(Default, Debug, Deserialize)]
#[frb(ignore)]
struct TelegramSentMessage {
    /// Unique identifier of the newly sent message within its chat.
    message_id: i64,
}

/// Request body for Telegram's `sendMessage` method.
///
/// The lifetime parameter allows the request to borrow the destination and
/// message strings without allocating owned copies.
#[derive(Default, Debug, Serialize)]
#[frb(ignore)]
struct TelegramSendMessageRequest<'a> {
    /// Identifier of the Telegram chat that should receive the message.
    chat_id: &'a str,

    /// Text content of the message to send.
    text: &'a str,
}

/// Request body for Telegram's `getChat` method.
///
/// The lifetime parameter allows the request to borrow the chat identifier
/// without allocating an owned copy.
#[derive(Default, Debug, Serialize)]
#[frb(ignore)]
struct TelegramGetChatRequest<'a> {
    /// Identifier of the Telegram chat to retrieve.
    chat_id: &'a str,
}
