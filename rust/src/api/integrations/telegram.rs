use crate::api::integrations::traits::*;
use flutter_rust_bridge::frb;

use anyhow::{anyhow, Ok, Result};
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
        self.config
            .accounts
            .iter()
            .map(|account| {
                let mut destinations = account.destinations.clone();

                destinations.sort_by(|a, b| a.name.cmp(&b.name));

                IntegrationAccount {
                    id: account.id.clone(),
                    name: account.name.clone(),
                    destinations,
                }
            })
            .collect()
    }

    fn authenticate_account(&self) -> Result<IntegrationAccount> {
        // For the bot architecture:
        //
        // GET /bot<TOKEN>/getMe
        //
        // Return the bot's ID/name.
        //
        // If you later support MTProto user accounts, this implementation
        // can use a Telegram user session instead.
        todo!("Telegram: authenticate account")
    }

    fn discover_destinations(&self, account_id: &str) -> Result<Vec<MessageDestination>> {
        let account = self
            .config
            .accounts
            .iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Telegram account not found: {}", account_id))?;

        let _ = account;

        // Discover chats/channels the Telegram bot can legitimately send to.
        //
        // Normalize them into:
        //
        //   DirectMessage
        //   Group
        //   Channel
        //
        // Nothing is persisted here.
        todo!("Telegram: discover available destinations")
    }

    fn add_destination(
        &mut self,
        account_id: &str,
        destination: MessageDestination,
    ) -> Result<IntegrationAccount> {
        let account = self
            .config
            .accounts
            .iter_mut()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Telegram account not found: {}", account_id))?;

        if account
            .destinations
            .iter()
            .any(|existing| existing.id == destination.id)
        {
            return Err(anyhow!(
                "Telegram destination already selected: {}",
                destination.id
            ));
        }

        account.destinations.push(destination);

        save_config(Self::KEY, &self.config)?;

        self.accounts()
            .into_iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Telegram account disappeared"))
    }

    fn remove_destination(
        &mut self,
        account_id: &str,
        destination_id: &str,
    ) -> Result<IntegrationAccount> {
        let account = self
            .config
            .accounts
            .iter_mut()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Telegram account not found: {}", account_id))?;

        let original_len = account.destinations.len();

        account
            .destinations
            .retain(|destination| destination.id != destination_id);

        if account.destinations.len() == original_len {
            return Err(anyhow!(
                "Telegram destination not selected: {}",
                destination_id
            ));
        }

        save_config(Self::KEY, &self.config)?;

        self.accounts()
            .into_iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Telegram account disappeared"))
    }

    fn add_account(&mut self, account: IntegrationAccount) -> Result<IntegrationAccount> {
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

    fn send_message(
        &self,
        account_id: &str,
        destination_id: &str,
        message: &str,
    ) -> Result<SentMessage> {
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

        // Bot API:
        //
        // POST /bot<TOKEN>/sendMessage
        //
        // {
        //     "chat_id": destination.id,
        //     "text": message
        // }
        //
        // Telegram's Bot API currently accepts an integer/string chat_id
        // for sendMessage. Store it as a String in the cross-platform model
        // to avoid platform-specific integer assumptions.
        let _ = destination;

        todo!("Telegram: send message")
    }

    fn test_destination(
        &self,
        account_id: &str,
        destination_id: &str,
    ) -> Result<DestinationTestResult> {
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

        // Provider-specific check goes here.
        //
        // For a bot, query the chat/member/administrator state as appropriate
        // and determine whether the bot can send messages to this chat.
        //
        // Do not send a test message.

        let _ = destination;

        todo!("Telegram: test whether destination can receive messages")
    }
}
