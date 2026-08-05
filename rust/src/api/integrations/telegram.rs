use crate::api::integrations::traits::*;
use flutter_rust_bridge::frb;

use anyhow::{Ok, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct TelegramConfig {
    pub users: Vec<TelegramUser>,
    pub groups: Vec<TelegramGroup>,
}

/// Connected Telegram account.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct TelegramUser {
    pub id: String,
    pub username: String,
}

/// Telegram group or channel configured as a message destination.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(ignore)]
pub struct TelegramGroup {
    pub id: String,
    pub name: String,
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

    fn from_config(config: TelegramConfig) -> Self {
        Self { config }
    }

    fn gradient(&self) -> IntegrationGradient {
        IntegrationGradient {
            start: 0xFF29A8EB,
            end: 0xFF1E719E,
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
        self.config
            .groups
            .iter()
            .map(|c| IntegrationChannel {
                guild_id: None,
                guild_name: None,
                channel_id: c.id.clone(),
                channel_name: c.name.clone(),
            })
            .collect()
    }

    fn delete(&mut self, id: &str) -> Result<()> {
        self.config.users.retain(|u| u.id != id);
        self.config.groups.retain(|group| group.id != id);

        save_config(Self::KEY, &self.config)?;

        Ok(())
    }

    fn test(&self, id: &str) -> Result<IntegrationTestResult> {
        // Example:
        // Call Telegram getMe endpoint using stored bot token.

        let exists = self.config.users.iter().any(|u| u.id == id)
            || self.config.groups.iter().any(|g| g.id == id);

        Ok(IntegrationTestResult {
            connected: exists,
            message: if exists {
                "Telegram connection exists".to_owned()
            } else {
                "Telegram connection not found".to_owned()
            },
        })
    }

    fn send(&self, recipient_id: &str, message: &str) -> Result<()> {
        // call Telegram API here

        Ok(())
    }
}
