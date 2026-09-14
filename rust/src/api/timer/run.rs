use crate::api::timer::state::TimerState;

use serde::{Deserialize, Serialize};

/// Represents a persisted execution of a timer.
///
/// A [`TimerRun`] contains the timing information and current state for a
/// particular timer instance. It is persisted separately from the timer's
/// configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimerRun {
    /// Identifier of the timer associated with this run.
    pub timer_id: String,

    /// Current lifecycle state of the timer run.
    pub state: TimerState,

    /// Timestamp, in milliseconds since the Unix epoch, at which the run started.
    pub started_at_ms: i64,

    /// Timestamp, in milliseconds since the Unix epoch, at which the run expires.
    pub expires_at_ms: i64,

    /// Optional grace-period duration, in milliseconds, after the expiration time.
    pub warning_duration_ms: Option<i64>,

    /// Timestamp, in milliseconds since the Unix epoch, at which the run was paused.
    ///
    /// This is `None` when the timer has not been paused or has been resumed.
    pub paused_at_ms: Option<i64>,
}

impl TimerRun {
    /// Returns whether the timer is currently active.
    ///
    /// A timer is considered active while it is [`TimerState::Running`].
    pub fn is_active(&self) -> bool {
        matches!(self.state, TimerState::Running)
    }

    /// Evaluates the timer's state at the specified timestamp.
    ///
    /// Terminal and paused states are returned unchanged. For an active timer,
    /// the current state is calculated using its expiration time and optional
    /// grace period.
    ///
    /// # Arguments
    ///
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    ///
    /// # Returns
    ///
    /// The state the timer should currently have at `now_ms`.
    pub fn evaluate_state(&self, now_ms: i64) -> TimerState {
        match self.state {
            TimerState::Paused
            | TimerState::Cancelled
            | TimerState::Expired
            | TimerState::Completed => self.state,

            _ => match self.warning_duration_ms {
                Some(duration) if now_ms > self.expires_at_ms + duration => TimerState::Expired,
                Some(_) if now_ms > self.expires_at_ms => TimerState::Warning,
                None if now_ms > self.expires_at_ms => TimerState::Expired,
                _ => TimerState::Running,
            },
        }
    }
}
