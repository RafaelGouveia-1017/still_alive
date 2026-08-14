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
        log::info!("Starting accounts in {}", self.title());

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
        log::info!("Starting authenticate_account in {}", self.title());

        // Authenticate the Discord integration here.
        //
        // Example:
        //
        // GET /users/@me
        //
        // Return the authenticated Discord identity.
        //todo!("Discord: authenticate account")

        Ok(IntegrationAccount {
            id: "bruhid".into(),
            name: "discord bruh".into(),
            destinations: [].into(),
        })
    }

    fn discover_destinations(&self, account_id: &str) -> Result<Vec<MessageDestination>> {
        log::info!("Starting discover_destinations in {}", self.title());

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
        //todo!("Discord: discover available message destinations")

        Ok(vec![
            MessageDestination {
                id: "789".into(),
                name: "general".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("5KuCjeIJNd".into()),
                parent_name: Some("Still Alive".into()),
            },
            MessageDestination {
                id: "78329".into(),
                name: "general #2".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("5KuCjeIJNd".into()),
                parent_name: Some("Still Alive".into()),
            },
            MessageDestination {
                id: "E0LCyU1tQ6".into(),
                name: "emergency".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("45ew6".into()),
                parent_name: Some("Still Dead".into()),
            },
            MessageDestination {
                id: "dAE1KqF4YI".into(),
                name: "Alice".into(),
                kind: DestinationKind::DirectMessage,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "hp7iKPwDvi".into(),
                name: "Mano bro".into(),
                kind: DestinationKind::DirectMessage,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "JNjTdzz9VI".into(),
                name: "outro bro".into(),
                kind: DestinationKind::DirectMessage,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "0GoH5qOT3D".into(),
                name: "music".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("rnvqTfEQKs".into()),
                parent_name: Some("Monstercat".into()),
            },
            MessageDestination {
                id: "fpQgCiuU0s".into(),
                name: "general".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("rnvqTfEQKs".into()),
                parent_name: Some("Monstercat".into()),
            },
            MessageDestination {
                id: "hf77hRua6d".into(),
                name: "Tom".into(),
                kind: DestinationKind::DirectMessage,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "45J44CGdTb".into(),
                name: "Still Alive".into(),
                kind: DestinationKind::Group,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "k8Lm2QpR7x".into(),
                name: "announcements".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("5KuCjeIJNd".into()),
                parent_name: Some("Still Alive".into()),
            },
            MessageDestination {
                id: "v3Nx9AaL2m".into(),
                name: "random".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("5KuCjeIJNd".into()),
                parent_name: Some("Still Alive".into()),
            },
            MessageDestination {
                id: "Q7wEr4TyUi".into(),
                name: "off-topic".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("5KuCjeIJNd".into()),
                parent_name: Some("Still Alive".into()),
            },
            MessageDestination {
                id: "m2Zx8BcV5n".into(),
                name: "support".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("45ew6".into()),
                parent_name: Some("Still Dead".into()),
            },
            MessageDestination {
                id: "P4qL7sW1eR".into(),
                name: "logs".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("45ew6".into()),
                parent_name: Some("Still Dead".into()),
            },
            MessageDestination {
                id: "Y6uI9oP3aS".into(),
                name: "releases".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("rnvqTfEQKs".into()),
                parent_name: Some("Monstercat".into()),
            },
            MessageDestination {
                id: "t5Gh2Jk8Lm".into(),
                name: "artists".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("rnvqTfEQKs".into()),
                parent_name: Some("Monstercat".into()),
            },
            MessageDestination {
                id: "R9cV4bN7xQ".into(),
                name: "beats".into(),
                kind: DestinationKind::ServerChannel,
                parent_id: Some("rnvqTfEQKs".into()),
                parent_name: Some("Monstercat".into()),
            },
            MessageDestination {
                id: "a1S2d3F4g5".into(),
                name: "Bob".into(),
                kind: DestinationKind::DirectMessage,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "h6J7k8L9m0".into(),
                name: "Charlie".into(),
                kind: DestinationKind::DirectMessage,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "N4b5V6c7X8".into(),
                name: "Dev Team".into(),
                kind: DestinationKind::Group,
                parent_id: None,
                parent_name: None,
            },
            MessageDestination {
                id: "z9Q0w1E2r3".into(),
                name: "Weekend Plans".into(),
                kind: DestinationKind::Group,
                parent_id: None,
                parent_name: None,
            },
        ])
    }

    fn add_destination(
        &mut self,
        account_id: &str,
        destination: MessageDestination,
    ) -> Result<IntegrationAccount> {
        log::info!("Starting add_destination in {}", self.title());

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
        log::info!("Starting remove_destination in {}", self.title());

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
        log::info!("Starting add_account in {}", self.title());

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

    fn send_message(
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

        // Provider-specific check goes here.
        //
        // For a guild channel, verify that the connected Discord identity/bot
        // can send messages to the channel.
        //
        // For a DM, verify that the DM channel can be resolved/used.
        //
        // Do not send an actual message merely to test this.

        let _ = destination;

        //todo!("Discord: test whether destination can receive messages")

        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .subsec_nanos();

        Ok(DestinationTestResult {
            can_send: nanos.is_multiple_of(2),
            message: "".into(),
        })
    }
}
