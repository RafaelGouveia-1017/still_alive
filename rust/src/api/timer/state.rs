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

#[cfg(test)]
mod tests {
    use super::TimerState;

    #[test]
    fn test_as_str_running() {
        assert_eq!(TimerState::Running.as_str(), "running");
    }

    #[test]
    fn test_as_str_paused() {
        assert_eq!(TimerState::Paused.as_str(), "paused");
    }

    #[test]
    fn test_as_str_cancelled() {
        assert_eq!(TimerState::Cancelled.as_str(), "cancelled");
    }

    #[test]
    fn test_as_str_expired() {
        assert_eq!(TimerState::Expired.as_str(), "expired");
    }

    #[test]
    fn test_as_str_warning() {
        assert_eq!(TimerState::Warning.as_str(), "warning");
    }

    #[test]
    fn test_as_str_completed() {
        assert_eq!(TimerState::Completed.as_str(), "completed");
    }

    #[test]
    fn test_state_from_str_running() {
        assert_eq!(
            TimerState::state_from_str("running"),
            Ok(TimerState::Running)
        );
    }

    #[test]
    fn test_state_from_str_paused() {
        assert_eq!(TimerState::state_from_str("paused"), Ok(TimerState::Paused));
    }

    #[test]
    fn test_state_from_str_cancelled() {
        assert_eq!(
            TimerState::state_from_str("cancelled"),
            Ok(TimerState::Cancelled)
        );
    }

    #[test]
    fn test_state_from_str_expired() {
        assert_eq!(
            TimerState::state_from_str("expired"),
            Ok(TimerState::Expired)
        );
    }

    #[test]
    fn test_state_from_str_warning() {
        assert_eq!(
            TimerState::state_from_str("warning"),
            Ok(TimerState::Warning)
        );
    }

    #[test]
    fn test_state_from_str_completed() {
        assert_eq!(
            TimerState::state_from_str("completed"),
            Ok(TimerState::Completed)
        );
    }

    #[test]
    fn test_state_from_str_invalid() {
        assert!(TimerState::state_from_str("invalid").is_err());
    }

    #[test]
    fn test_state_from_str_empty() {
        assert!(TimerState::state_from_str("").is_err());
    }

    #[test]
    fn test_state_from_str_case_sensitive() {
        assert!(TimerState::state_from_str("RUNNING").is_err());
        assert!(TimerState::state_from_str("Running").is_err());
    }

    #[test]
    fn test_state_from_str_round_trip() {
        let states = [
            TimerState::Running,
            TimerState::Paused,
            TimerState::Cancelled,
            TimerState::Expired,
            TimerState::Warning,
            TimerState::Completed,
        ];
        for state in states {
            assert_eq!(TimerState::state_from_str(state.as_str()), Ok(state));
        }
    }
}
