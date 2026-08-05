use crate::api::integrations::traits::*;
use flutter_rust_bridge::frb;

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct DiscordConfig {
    pub users: Vec<DiscordUser>,
    pub guilds: Vec<DiscordGuild>,
}

/// Connected Discord account.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct DiscordUser {
    pub id: String,
    pub username: String,
}

/// Discord server containing one or more configured channels.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct DiscordGuild {
    pub id: String,
    pub name: String,
    pub channels: Vec<DiscordTextChannel>,
}

/// Discord text channel configured as a message destination.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct DiscordTextChannel {
    pub id: String,
    pub name: String,
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

    fn from_config(config: DiscordConfig) -> Self {
        Self { config }
    }

    fn gradient(&self) -> IntegrationGradient {
        IntegrationGradient {
            start: 0xFF5865F2,
            end: 0xFF394196,
        }
    }

    fn users(&self) -> Vec<IntegrationUser> {
        self.config
            .users
            .iter()
            .map(|u| IntegrationUser {
                id: u.id.clone(),
                username: u.username.clone(),
            })
            .collect()
    }

    fn channels(&self) -> Vec<IntegrationChannel> {
        let mut guilds: Vec<_> = self.config.guilds.iter().collect();
        guilds.sort_by(|a, b| a.name.cmp(&b.name));

        guilds
            .into_iter()
            .flat_map(|guild| {
                let mut channels: Vec<_> = guild.channels.iter().collect();
                channels.sort_by(|a, b| a.name.cmp(&b.name));

                channels.into_iter().map(move |channel| IntegrationChannel {
                    guild_id: Some(guild.id.clone()),
                    guild_name: Some(guild.name.clone()),
                    channel_id: channel.id.clone(),
                    channel_name: channel.name.clone(),
                })
            })
            .collect()
    }

    fn delete(&mut self, id: &str) -> Result<()> {
        self.config.users.retain(|u| u.id != id);

        self.config.guilds.retain_mut(|guild| {
            guild.channels.retain(|channel| channel.id != id);
            !guild.channels.is_empty()
        });

        save_config(Self::KEY, &self.config)?;

        Ok(())
    }

    fn test(&self, id: &str) -> Result<IntegrationTestResult> {
        // Example:
        // Call Discord API using stored token/session.

        let exists = self.config.users.iter().any(|u| u.id == id)
            || self
                .config
                .guilds
                .iter()
                .any(|g| g.channels.iter().any(|c| c.id == id));

        Ok(IntegrationTestResult {
            connected: exists,
            message: if exists {
                "Discord connection exists".to_owned()
            } else {
                "Discord connection not found".to_owned()
            },
        })
    }

    fn send(&self, recipient_id: &str, message: &str) -> Result<()> {
        // call Discord API here

        Ok(())
    }
}
