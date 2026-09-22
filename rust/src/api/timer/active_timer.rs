use crate::api::timer::config::TimerConfig;
use crate::api::timer::run::TimerRun;
use crate::api::timer::state::TimerState;
use crate::api::timer::traits::*;

use anyhow::{bail, Context, Result};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Represents a configured timer together with its current run state.
///
/// [`ActiveTimer`] combines the timer configuration with the current
/// [`TimerRun`] so that timer operations can update both the in-memory state
/// and its persisted representation.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(opaque)]
pub struct ActiveTimer {
    /// Unique identifier of the timer.
    pub key: String,

    /// Current execution state of the timer.
    pub run: TimerRun,

    /// Configuration associated with the timer.
    #[serde(flatten)]
    pub config: TimerConfig,
}

impl ActiveTimer {
    /// Starts a new timer run.
    ///
    /// The timer's expiration time is calculated from the configured duration.
    /// If a grace period is configured, it is stored as part of the new run.
    ///
    /// The updated timer run is also persisted to the database.
    ///
    /// # Arguments
    ///
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    ///
    /// # Errors
    ///
    /// Returns an error if the timer run cannot be persisted to the database.
    pub fn start_timer_run(&mut self, now_ms: i64) -> Result<()> {
        log::info!("Starting timer run with key: '{}'", self.key);

        let timer_duration_ms = self.config.duration_secs * 1_000;
        let expires_at_ms = now_ms + timer_duration_ms;

        let warning_duration_ms = self.config.grace_period_secs.map(|secs| secs * 1000);

        let new_run = TimerRun {
            timer_id: self.key.clone(),
            state: TimerState::Running,
            started_at_ms: now_ms,
            expires_at_ms,
            warning_duration_ms,
            paused_at_ms: None,
        };

        create_timer_run(&new_run, now_ms).context("Failed to create timer run")?;

        self.run = new_run;

        Ok(())
    }

    /// Pauses the currently running timer.
    ///
    /// A timer in the `Running` or `Warning` state can be paused. A timer that
    /// is already paused is left unchanged.
    ///
    /// If password protection is enabled, `password_verified` must be `true`.
    ///
    /// The new state is persisted before the in-memory run is updated.
    ///
    /// # Arguments
    ///
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    /// * `password_verified` - Whether the caller has successfully verified
    ///   the timer's password.
    ///
    /// # Errors
    ///
    /// Returns an error if password verification is required but has not been
    /// completed, if the timer cannot be paused in its current state, or if
    /// the updated timer state cannot be persisted.
    pub fn pause_timer_run(&mut self, now_ms: i64, password_verified: bool) -> Result<()> {
        log::info!("Pausing timer run with key: '{}'", self.key);

        if self.config.password_protected && !password_verified {
            bail!("Password verification required");
        }

        match self.run.state {
            TimerState::Running | TimerState::Warning => {}

            TimerState::Paused => {
                return Ok(());
            }

            TimerState::Expired | TimerState::Cancelled | TimerState::Completed => {
                bail!("Timer cannot be paused in its current state");
            }
        }

        let mut new_run = self.run.clone();
        new_run.state = TimerState::Paused;
        new_run.paused_at_ms = Some(now_ms);

        update_timer_run_state(&new_run, now_ms).context("Failed to persist paused timer state")?;

        self.run = new_run;

        Ok(())
    }

    /// Resumes a paused timer.
    ///
    /// The time elapsed while the timer was paused is added to the original
    /// start and expiration timestamps so that the remaining timer duration
    /// is preserved.
    ///
    /// The updated run is persisted before the in-memory run is updated.
    ///
    /// # Arguments
    ///
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    ///
    /// # Errors
    ///
    /// Returns an error if the timer is not paused, if its pause timestamp is
    /// missing, or if the updated timer state cannot be persisted.
    pub fn resume_timer_run(&mut self, now_ms: i64) -> Result<()> {
        log::info!("Resuming timer run with key: '{}'", self.key);

        if self.run.state != TimerState::Paused {
            bail!("Timer is not paused");
        }

        let paused_at_ms = self
            .run
            .paused_at_ms
            .context("Timer is missing its pause timestamp")?;

        let time_passed_ms = now_ms - paused_at_ms;

        let mut new_run = self.run.clone();

        new_run.state = TimerState::Running;
        new_run.started_at_ms += time_passed_ms;
        new_run.expires_at_ms += time_passed_ms;
        new_run.paused_at_ms = None;

        update_timer_run_state(&new_run, now_ms)
            .context("Failed to persist resumed timer state")?;

        self.run = new_run;

        Ok(())
    }

    /// Cancels the current timer run.
    ///
    /// A running timer is transitioned to `Cancelled`. An expired timer is
    /// transitioned to `Completed`. Paused, warning, cancelled, and completed
    /// timers are left unchanged.
    ///
    /// If password protection is enabled, `password_verified` must be `true`.
    ///
    /// The resulting state is persisted before the in-memory run is updated.
    ///
    /// # Arguments
    ///
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    /// * `password_verified` - Whether the caller has successfully verified
    ///   the timer's password.
    ///
    /// # Errors
    ///
    /// Returns an error if password verification is required but has not been
    /// completed, or if the resulting timer state cannot be persisted.
    pub fn cancel_timer_run(&mut self, now_ms: i64, password_verified: bool) -> Result<()> {
        log::info!("Cancelling timer run with key: '{}'", self.key);

        if self.config.password_protected && !password_verified {
            bail!("Password verification required");
        }

        if matches!(
            self.run.state,
            TimerState::Cancelled | TimerState::Completed
        ) {
            return Ok(());
        }

        let mut new_run = self.run.clone();

        new_run.state = if matches!(new_run.state, TimerState::Expired) {
            TimerState::Completed
        } else {
            TimerState::Cancelled
        };

        update_timer_run_state(&new_run, now_ms)
            .context("Failed to persist cancelled timer state")?;

        self.run = new_run;

        Ok(())
    }

    /// Updates the current timer run's state based on the current time.
    ///
    /// The timer's state is evaluated using its current timestamps and the
    /// provided time. If the evaluated state differs from the current state,
    /// the updated state is persisted to the database before the in-memory
    /// run is updated.
    ///
    /// If the evaluated state is unchanged, no database update is performed.
    ///
    /// # Arguments
    ///
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    ///
    /// # Errors
    ///
    /// Returns an error if the updated timer state cannot be persisted to the
    /// database.
    pub fn update_run_state(&mut self, now_ms: i64) -> Result<()> {
        let state: TimerState = self.run.evaluate_state(now_ms);

        if self.run.state != state {
            let mut new_run = self.run.clone();
            new_run.state = state;

            update_timer_run_state(&new_run, now_ms)
                .context("Failed to persist updated timer state")?;

            self.run = new_run;
        }

        Ok(())
    }

    /// Replaces the currently active timer with a new timer.
    ///
    /// The new timer is created using the provided key and configuration. Its
    /// initial run is marked as `Completed`, with its timestamps calculated from
    /// the provided current time and configured duration. If a grace period is
    /// configured, it is stored as part of the new run.
    ///
    /// The new timer run and timer configuration are persisted to the database
    /// before the in-memory timer is updated.
    ///
    /// # Arguments
    ///
    /// * `key` - Unique key identifying the new timer.
    /// * `config` - Configuration for the new timer.
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    ///
    /// # Errors
    ///
    /// Returns an error if the new timer run or timer configuration cannot be
    /// persisted to the database.
    pub fn replace_active_timer(
        &mut self,
        key: String,
        config: TimerConfig,
        now_ms: i64,
    ) -> Result<()> {
        log::info!(
            "Replacing active timer with key '{}' to key '{}'",
            self.key,
            key
        );

        let timer_duration_ms = config.duration_secs * 1_000;
        let expires_at_ms = now_ms + timer_duration_ms;

        let warning_duration_ms = config.grace_period_secs.map(|secs| secs * 1000);

        let new_run = TimerRun {
            timer_id: key.clone(),
            state: TimerState::Completed,
            started_at_ms: now_ms,
            expires_at_ms,
            warning_duration_ms,
            paused_at_ms: None,
        };

        save_timer(&key, &config).context("Failed to persist timer to database")?;
        create_timer_run(&new_run, now_ms).context("Failed to create timer run")?;

        self.key = key;
        self.run = new_run;
        self.config = config;

        Ok(())
    }

    /// Deletes a timer.
    ///
    /// `timer0` cannot be deleted. If deleting the timer also removes the
    /// currently persisted timer run through the database cascade and no
    /// timer run remains, a replacement run is created for a remaining timer.
    ///
    /// When multiple timers remain, a random timer is selected. If only
    /// `timer0` remains, `timer0` is used.
    ///
    /// The returned [`ActiveTimer`] represents the timer that is active after
    /// the deletion.
    ///
    /// # Arguments
    ///
    /// * `key` - Identifier of the timer to delete.
    /// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
    ///
    /// # Errors
    ///
    /// Returns an error if `timer0` is requested, the timer cannot be deleted,
    /// no timers remain, or the replacement timer run cannot be created.
    pub fn delete_timer(&mut self, key: &str, now_ms: i64) -> Result<()> {
        log::info!("Deleting timer with key '{}'", key);

        if key == "timer0" {
            bail!("The base timer 'timer0' cannot be deleted");
        }

        delete_timer(key).context("Failed to delete timer")?;

        // Normally the deleted timer's run has also disappeared because of
        // ON DELETE CASCADE. Only create a replacement run when no run exists.
        if !timer_run_exists().context("Failed to check timer run")? {
            let (replacement_key, replacement_config) =
                get_random_remaining_timer().context("Failed to select replacement timer")?;

            let replacement_run = TimerRun {
                timer_id: replacement_key.clone(),
                state: TimerState::Completed,
                started_at_ms: now_ms,
                expires_at_ms: now_ms,
                warning_duration_ms: None,
                paused_at_ms: None,
            };

            create_timer_run(&replacement_run, now_ms)
                .context("Failed to create replacement timer run")?;

            self.key = replacement_key;
            self.run = replacement_run;
            self.config = replacement_config;
        }

        Ok(())
    }
}

/// Reconciles the persisted timer state with the current timestamp.
///
/// The timer is loaded from persistent storage and its state is evaluated
/// against `now_ms`. If the calculated state differs from the persisted state,
/// the updated state is written back to the database.
///
/// # Arguments
///
/// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
///
/// # Returns
///
/// Returns the active timer if it can be loaded and reconciled successfully.
/// Returns `None` if loading or updating the timer fails.
pub fn reconcile_active_timer(now_ms: i64) -> Option<ActiveTimer> {
    log::info!("Reconciling timer...");

    let mut timer = match load_timer(now_ms) {
        Ok(result) => result,
        Err(e) => {
            log::error!("Failed to load timer: {}", e);
            return None;
        }
    };

    if let Err(e) = timer.update_run_state(now_ms) {
        log::error!("Failed to update timer run state: '{}'", e);
        return None;
    }

    Some(timer)
}

/// Generates a unique identifier for a new timer.
///
/// # Returns
///
/// Returns a timer identifier based on the the first unused timer
/// identifier.
/// Returns `None` if the number of timers cannot be retrieved.
pub fn get_unique_timer_id() -> Option<String> {
    match get_unique_id_for_timer() {
        Ok(id) => Some(id),
        Err(e) => {
            log::error!("Failed to get unique id for timer: '{}'", e);
            None
        }
    }
}

/// Persists a timer from the given key & configuration.
///
/// # Arguments
///
/// * `key` - Identifier of the timer to edit.
/// * `config` - Configuration for the new timer.
///
/// # Errors
///
/// Returns an error if the new timer configuration cannot be
/// persisted to the database.
pub fn persist_timer(key: Option<String>, config: TimerConfig) -> Result<()> {
    let timer_key = match key {
        Some(value) => value,
        None => get_unique_timer_id().context("Failed to get unique id for timer")?,
    };

    log::info!("Persisting timer with key '{}'", timer_key);

    save_timer(&timer_key, &config).context("Failed to persist timer to database")?;

    Ok(())
}
