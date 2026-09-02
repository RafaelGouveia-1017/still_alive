use serde::{Deserialize, Serialize};

/// Represents the current lifecycle state of a timer run.
#[derive(Debug, Clone, Serialize, Deserialize, Copy, PartialEq, Eq)]
pub enum TimerState {
    /// The timer is actively counting down.
    Running,

    /// The timer is temporarily stopped and can be resumed.
    Paused,

    /// The timer was manually cancelled before completion.
    Cancelled,

    /// The timer exceeded its expiration time, including any configured grace period.
    Expired,

    /// The timer has passed its expiration time but is still within its grace period.
    Warning,

    /// The timer has reached a terminal completed state.
    Completed,
}

impl TimerState {
    /// Returns the string representation used when persisting the state.
    pub fn as_str(&self) -> &'static str {
        match self {
            TimerState::Running => "running",
            TimerState::Paused => "paused",
            TimerState::Cancelled => "cancelled",
            TimerState::Expired => "expired",
            TimerState::Warning => "warning",
            TimerState::Completed => "completed",
        }
    }

    /// Converts a persisted timer state string into a [`TimerState`].
    ///
    /// # Errors
    ///
    /// Returns an error if `value` does not match a known timer state.
    pub fn state_from_str(value: &str) -> Result<Self, String> {
        match value {
            "running" => Ok(Self::Running),
            "paused" => Ok(Self::Paused),
            "cancelled" => Ok(Self::Cancelled),
            "expired" => Ok(Self::Expired),
            "warning" => Ok(Self::Warning),
            "completed" => Ok(Self::Completed),
            _ => Err(format!("Unknown timer state: {value}")),
        }
    }
}
