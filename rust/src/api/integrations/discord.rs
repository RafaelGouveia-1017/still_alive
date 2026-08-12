use crate::api::integrations::traits::*;
use flutter_rust_bridge::frb;

use anyhow::{anyhow, Ok, Result};
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
        self.config
            .accounts
            .iter()
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
                    destinations,
                }
            })
            .collect()
    }

    fn authenticate_account(&self) -> Result<IntegrationAccount> {
        // Authenticate the Discord integration here.
        //
        // Example:
        //
        // GET /users/@me
        //
        // Return the authenticated Discord identity.
        todo!("Discord: authenticate account")
    }

    fn discover_destinations(&self, account_id: &str) -> Result<Vec<MessageDestination>> {
        let account = self
            .config
            .accounts
            .iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let _ = account;

        // This is deliberately NOT persisted.
        //
        // Depending on your Discord architecture this should discover:
        //
        //   * server text channels the bot/user can send to
        //   * DM destinations that are actually valid
        //
        // Return MessageDestination values.
        //
        // Discord's APIs distinguish guild channels from DMs, so normalize
        // both into the application's destination model here.
        todo!("Discord: discover available message destinations")
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
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        if account
            .destinations
            .iter()
            .any(|existing| existing.id == destination.id)
        {
            return Err(anyhow!(
                "Discord destination already selected: {}",
                destination.id
            ));
        }

        account.destinations.push(destination);

        save_config(Self::KEY, &self.config)?;

        self.accounts()
            .into_iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account disappeared"))
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
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let original_len = account.destinations.len();

        account
            .destinations
            .retain(|destination| destination.id != destination_id);

        if account.destinations.len() == original_len {
            return Err(anyhow!(
                "Discord destination not selected: {}",
                destination_id
            ));
        }

        save_config(Self::KEY, &self.config)?;

        self.accounts()
            .into_iter()
            .find(|account| account.id == account_id)
            .ok_or_else(|| anyhow!("Discord account disappeared"))
    }

    fn add_account(&mut self, account: IntegrationAccount) -> Result<IntegrationAccount> {
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
            return Err(anyhow!("Discord account not found: {}", account_id));
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
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let destination = account
            .destinations
            .iter()
            .find(|destination| destination.id == destination_id)
            .ok_or_else(|| anyhow!("Discord destination is not selected: {}", destination_id))?;

        if message.trim().is_empty() {
            return Err(anyhow!("message cannot be empty"));
        }

        // IMPORTANT:
        // The API call belongs here.
        //
        // For a server channel:
        //   POST /channels/{channel.id}/messages
        //
        // For a DM:
        //   resolve/open the DM channel first, then send to that channel.
        //
        // Do not accept an arbitrary destination_id from Flutter and blindly
        // send to it. The persisted selection check above is part of the
        // authorization boundary.

        let _ = destination;

        todo!("Discord: send message")
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
            .ok_or_else(|| anyhow!("Discord account not found: {}", account_id))?;

        let destination = account
            .destinations
            .iter()
            .find(|destination| destination.id == destination_id)
            .ok_or_else(|| anyhow!("Discord destination is not selected: {}", destination_id))?;

        // Provider-specific check goes here.
        //
        // For a guild channel, verify that the connected Discord identity/bot
        // can send messages to the channel.
        //
        // For a DM, verify that the DM channel can be resolved/used.
        //
        // Do not send an actual message merely to test this.

        let _ = destination;

        todo!("Discord: test whether destination can receive messages")
    }
}
