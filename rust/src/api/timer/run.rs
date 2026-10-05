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
                None if self.state == TimerState::Warning => TimerState::Warning,
                _ => TimerState::Running,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::TimerRun;
    use crate::api::timer::state::TimerState;

    fn test_run(state: TimerState, warning_duration_ms: Option<i64>) -> TimerRun {
        TimerRun {
            timer_id: "test-timer".to_string(),
            state,
            started_at_ms: 0,
            expires_at_ms: 1000,
            warning_duration_ms,
            paused_at_ms: None,
        }
    }

    // 1. Paused state stays Paused regardless of time

    #[test]
    fn paused_stays_paused_before_expiry() {
        let run = test_run(TimerState::Paused, Some(100));
        assert_eq!(run.evaluate_state(0), TimerState::Paused);
    }

    #[test]
    fn paused_stays_paused_during_warning() {
        let run = test_run(TimerState::Paused, Some(100));
        assert_eq!(run.evaluate_state(1050), TimerState::Paused);
    }

    #[test]
    fn paused_stays_paused_after_warning() {
        let run = test_run(TimerState::Paused, Some(100));
        assert_eq!(run.evaluate_state(2000), TimerState::Paused);
    }

    // 2. Cancelled state stays Cancelled regardless of time

    #[test]
    fn cancelled_stays_cancelled_before_expiry() {
        let run = test_run(TimerState::Cancelled, Some(100));
        assert_eq!(run.evaluate_state(0), TimerState::Cancelled);
    }

    #[test]
    fn cancelled_stays_cancelled_during_warning() {
        let run = test_run(TimerState::Cancelled, Some(100));
        assert_eq!(run.evaluate_state(1050), TimerState::Cancelled);
    }

    #[test]
    fn cancelled_stays_cancelled_after_warning() {
        let run = test_run(TimerState::Cancelled, Some(100));
        assert_eq!(run.evaluate_state(2000), TimerState::Cancelled);
    }

    // 3. Completed state stays Completed regardless of time

    #[test]
    fn completed_stays_completed_before_expiry() {
        let run = test_run(TimerState::Completed, Some(100));
        assert_eq!(run.evaluate_state(0), TimerState::Completed);
    }

    #[test]
    fn completed_stays_completed_during_warning() {
        let run = test_run(TimerState::Completed, Some(100));
        assert_eq!(run.evaluate_state(1050), TimerState::Completed);
    }

    #[test]
    fn completed_stays_completed_after_warning() {
        let run = test_run(TimerState::Completed, Some(100));
        assert_eq!(run.evaluate_state(2000), TimerState::Completed);
    }

    // Expired state also stays Expired regardless of time

    #[test]
    fn expired_stays_expired_before_expiry() {
        let run = test_run(TimerState::Expired, Some(100));
        assert_eq!(run.evaluate_state(0), TimerState::Expired);
    }

    #[test]
    fn expired_stays_expired_during_warning() {
        let run = test_run(TimerState::Expired, Some(100));
        assert_eq!(run.evaluate_state(1050), TimerState::Expired);
    }

    #[test]
    fn expired_stays_expired_after_warning() {
        let run = test_run(TimerState::Expired, Some(100));
        assert_eq!(run.evaluate_state(2000), TimerState::Expired);
    }

    // 4. Running with warning duration: before expiry -> Running, during warning -> Warning, after warning -> Expired

    #[test]
    fn running_with_warning_before_expiry() {
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(999), TimerState::Running);
    }

    #[test]
    fn running_with_warning_during_warning() {
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1001), TimerState::Warning);
    }

    #[test]
    fn running_with_warning_mid_warning() {
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1050), TimerState::Warning);
    }

    #[test]
    fn running_with_warning_after_warning() {
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1101), TimerState::Expired);
    }

    // 5. Running without warning duration: before expiry -> Running, after expiry -> Expired

    #[test]
    fn running_without_warning_before_expiry() {
        let run = test_run(TimerState::Running, None);
        assert_eq!(run.evaluate_state(999), TimerState::Running);
    }

    #[test]
    fn running_without_warning_after_expiry() {
        let run = test_run(TimerState::Running, None);
        assert_eq!(run.evaluate_state(1001), TimerState::Expired);
    }

    // 6. Warning run has its own expiry: stays Warning until that time, then Expired
    // (A warning run is created by `start_warning_run` with its own expires_at_ms.)

    #[test]
    fn warning_run_before_expiry_stays_warning() {
        let run = test_run(TimerState::Warning, None);
        assert_eq!(run.evaluate_state(999), TimerState::Warning);
    }

    #[test]
    fn warning_run_after_expiry_is_expired() {
        let run = test_run(TimerState::Warning, None);
        assert_eq!(run.evaluate_state(1001), TimerState::Expired);
    }

    #[test]
    fn warning_run_with_duration_during_warning_stays_warning() {
        let run = test_run(TimerState::Warning, Some(100));
        assert_eq!(run.evaluate_state(1001), TimerState::Warning);
    }

    #[test]
    fn warning_run_with_duration_after_warning_is_expired() {
        let run = test_run(TimerState::Warning, Some(100));
        assert_eq!(run.evaluate_state(1101), TimerState::Expired);
    }

    // 7. Boundary conditions: exactly at expiry, exactly at warning end

    #[test]
    fn exactly_at_expiry_with_warning_stays_running() {
        // Exactly at expiry (now_ms == expires_at_ms): the `now_ms > expires_at_ms`
        // condition is false, so the timer is still Running.
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1000), TimerState::Running);
    }

    #[test]
    fn exactly_at_expiry_without_warning_stays_running() {
        let run = test_run(TimerState::Running, None);
        assert_eq!(run.evaluate_state(1000), TimerState::Running);
    }

    #[test]
    fn exactly_at_warning_end_stays_warning() {
        // Exactly at the end of the warning window (now_ms == expires_at_ms + duration):
        // the `now_ms > expires_at_ms + duration` condition is false, so Warning.
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1100), TimerState::Warning);
    }

    #[test]
    fn one_ms_after_warning_end_is_expired() {
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1101), TimerState::Expired);
    }

    #[test]
    fn one_ms_after_expiry_is_warning() {
        let run = test_run(TimerState::Running, Some(100));
        assert_eq!(run.evaluate_state(1001), TimerState::Warning);
    }
}
