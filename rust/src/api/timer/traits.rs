use crate::api::data::db::db;
use crate::api::timer::active_timer::ActiveTimer;
use crate::api::timer::config::TimerConfig;
use crate::api::timer::run::TimerRun;
use crate::api::timer::state::TimerState;
use flutter_rust_bridge::frb;

use anyhow::{Context, Result};
use rusqlite::params;

/// Loads the active timer configuration and its most recent run.
///
/// If no timer run exists, a default completed run is created for `timer0`.
/// The timer configuration is then loaded from the database and combined with
/// the run into an [`ActiveTimer`].
///
/// This function is intended for internal Rust use and is not exposed through
/// Flutter Rust Bridge.
///
/// # Arguments
///
/// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
///
/// # Errors
///
/// Returns an error if the timer run cannot be loaded or created, if the
/// timer configuration cannot be loaded or deserialized, or if a database
/// operation fails.
#[frb(ignore)]
pub fn load_timer(now_ms: i64) -> Result<ActiveTimer> {
    let run: TimerRun = match load_timer_run()? {
        Some(result) => result,
        None => {
            let new = TimerRun {
                timer_id: "timer0".to_owned(),
                state: TimerState::Completed,
                started_at_ms: now_ms,
                expires_at_ms: now_ms,
                warning_duration_ms: None,
                paused_at_ms: None,
            };

            create_timer_run(&new, now_ms)?;

            new
        }
    };

    let key = run.timer_id.clone();

    log::info!("Loading timer with key: '{}'", key);

    let db = db();

    let json: String = db
        .as_ref()
        .unwrap()
        .query_one("SELECT value FROM timers WHERE key = ?1", [&key], |row| {
            row.get(0)
        })?
        .context("Timer configuration not found")?;

    let config: TimerConfig = serde_json::from_str(&json)?;

    Ok(ActiveTimer {
        key: key.to_string(),
        run,
        config,
    })
}

/// Returns the first unused identifier for a timer.
///
/// Timer identifiers use the `timerN` format, starting at `timer0`. The
/// function finds the smallest non-negative numeric suffix that is not
/// currently used by a timer.
///
/// For example, if `timer0`, `timer1`, and `timer3` exist, this function
/// returns `timer2`.
///
/// This function is intended for internal Rust use and is not exposed through
/// Flutter Rust Bridge.
///
/// # Returns
///
/// Returns the first unused timer identifier.
///
/// # Errors
///
/// Returns an error if the database query fails.
#[frb(ignore)]
pub fn get_unique_id_for_timer() -> Result<String> {
    log::info!("Getting unique timer ID...");

    let db = db();

    let id: i64 = db
        .as_ref()
        .unwrap()
        .query_one(
            r#"
        WITH RECURSIVE numbers(n) AS (
            SELECT 0
            UNION ALL
            SELECT n + 1 FROM numbers
        )
        SELECT n
        FROM numbers
        WHERE NOT EXISTS (
            SELECT 1
            FROM timers
            WHERE key = 'timer' || n
        )
        LIMIT 1
        "#,
            [],
            |row| row.get(0),
        )?
        .context("Unique timer id not found")?;

    let key = format!("timer{}", id);

    log::info!("Generated unique timer ID: '{}'", key);

    Ok(key)
}

/// Saves the timer configuration to persistent storage.
///
/// The timer configuration is serialized to JSON and stored using the timer's
/// key. Existing configuration for the same key is replaced.
///
/// This function is intended for internal Rust use and is not exposed through
/// Flutter Rust Bridge.
///
/// # Arguments
///
/// * `timer` - Timer whose configuration should be persisted.
///
/// # Errors
///
/// Returns an error if the configuration cannot be serialized or the database
/// operation fails.
#[frb(ignore)]
pub fn save_timer(key: &String, config: &TimerConfig) -> Result<()> {
    log::info!("Saving timer with key: '{}'", key);

    let db = db();

    let json = serde_json::to_string(&config)?;

    db.as_ref()
        .unwrap()
        .execute(
            r#"
            INSERT INTO timers (key, value)
            VALUES (?1, ?2)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            "#,
            [&key, &json],
        )
        .context("Failed to insert timer")?;

    Ok(())
}

/// Loads the most recent timer run from persistent storage.
///
/// The function reads the timer run from the database and converts the stored
/// state string into a [`TimerState`].
///
/// This function is intended for internal Rust use and is not exposed through
/// Flutter Rust Bridge.
///
/// # Returns
///
/// Returns `Some(TimerRun)` when a timer run is found. Returns `None` when no
/// timer run exists.
///
/// # Errors
///
/// Returns an error if the database query fails or the stored timer state is
/// invalid.
#[frb(ignore)]
pub fn load_timer_run() -> Result<Option<TimerRun>> {
    log::info!("Attempting to load timer run...");

    let db = db();

    let run = db
        .as_ref()
        .unwrap()
        .query_one("SELECT * FROM timer_run LIMIT 1", [], |row| {
            let timer_id: String = row.get(0)?;
            let state_string: String = row.get(1)?;
            let state = TimerState::state_from_str(&state_string).map_err(|e| {
                log::error!("Invalid timer state '{}': {}", state_string, e);
                rusqlite::Error::InvalidQuery
            })?;

            log::info!("Loading timer run with key: '{}'", timer_id);

            Ok(TimerRun {
                timer_id,
                state,
                started_at_ms: row.get(2)?,
                expires_at_ms: row.get(3)?,
                warning_duration_ms: row.get(4)?,
                paused_at_ms: row.get(5)?,
            })
        })
        .context("Failed to load timer run")?;

    Ok(run)
}

/// Creates and persists a new timer run.
///
/// The supplied [`TimerRun`] is inserted into the `timer_run` database table
/// together with the creation and update timestamp.
///
/// This function is intended for internal Rust use and is not exposed through
/// Flutter Rust Bridge.
///
/// # Arguments
///
/// * `run` - Timer run to persist.
/// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
///
/// # Errors
///
/// Returns an error if the database insert fails.
#[frb(ignore)]
pub fn create_timer_run(run: &TimerRun, now_ms: i64) -> Result<()> {
    log::info!("Creating timer run with key: '{}'", run.timer_id);

    let db = db();

    db.as_ref()
        .unwrap()
        .execute(
            r#"
            INSERT INTO timer_run (
                timer_id,
                state,
                started_at_ms,
                expires_at_ms,
                warning_duration_ms,
                paused_at_ms,
                created_at_ms,
                updated_at_ms
            )
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?7);
            "#,
            params![
                run.timer_id,
                run.state.as_str(),
                run.started_at_ms,
                run.expires_at_ms,
                run.warning_duration_ms,
                run.paused_at_ms,
                now_ms
            ],
        )
        .context("Failed to insert timer run")?;

    Ok(())
}

/// Updates the persisted state and timing information for a timer run.
///
/// The database fields updated depend on the run's current [`TimerState`].
/// The caller is responsible for ensuring that `updated_run` contains the
/// latest state before calling this function.
///
/// This function is intended for internal Rust use and is not exposed through
/// Flutter Rust Bridge.
///
/// # Arguments
///
/// * `updated_run` - Timer run containing the latest state and timing values.
/// * `now_ms` - Current timestamp in milliseconds since the Unix epoch.
///
/// # Errors
///
/// Returns an error if the database update fails.
#[frb(ignore)]
pub fn update_timer_run_state(updated_run: &TimerRun, now_ms: i64) -> Result<()> {
    let key = updated_run.timer_id.clone();
    let state = updated_run.state.as_str();

    log::info!("Updating state for timer run with key: '{}'", key);

    let db = db();

    match updated_run.state {
        TimerState::Cancelled | TimerState::Warning | TimerState::Expired => {
            db.as_ref()
                .unwrap()
                .execute(
                    r#"
                    UPDATE timer_run 
                    SET 
                        state = ?1,
                        updated_at_ms = ?2
                    WHERE
                        timer_id = ?3
                    "#,
                    params![state, now_ms, key],
                )
                .context("Failed to update state")?;
        }

        TimerState::Paused => {
            db.as_ref()
                .unwrap()
                .execute(
                    r#"
                    UPDATE timer_run
                    SET
                        state = 'paused',
                        paused_at_ms = ?1,
                        updated_at_ms = ?1
                    WHERE
                        timer_id = ?2
                    "#,
                    params![now_ms, key],
                )
                .context("Failed to update state")?;
        }

        TimerState::Running => {
            db.as_ref()
                .unwrap()
                .execute(
                    r#"
                    UPDATE timer_run
                    SET
                        state = 'running',
                        expires_at_ms = ?1,
                        paused_at_ms = NULL,
                        updated_at_ms = ?2
                    WHERE
                        timer_id = ?3
                    "#,
                    params![updated_run.expires_at_ms, now_ms, key],
                )
                .context("Failed to update state")?;
        }

        TimerState::Completed => {
            db.as_ref()
                .unwrap()
                .execute(
                    r#"
                    UPDATE timer_run
                    SET
                        state = 'completed',
                        started_at_ms = ?1,
                        expires_at_ms = ?1,
                        warning_duration_ms = NULL,
                        paused_at_ms = NULL,
                        updated_at_ms = ?1
                    WHERE
                        timer_id = ?2
                    "#,
                    params![now_ms, key],
                )
                .context("Failed to update state")?;
        }
    }

    Ok(())
}

/// Deletes a timer from persistent storage.
///
/// The timer's associated run is deleted automatically by the database's
/// `ON DELETE CASCADE` constraint.
///
/// `timer0` cannot be deleted.
///
/// This function does not create a replacement timer run. The caller is
/// responsible for reconciling the active timer after deletion.
///
/// # Arguments
///
/// * `key` - Identifier of the timer to delete.
///
/// # Errors
///
/// Returns an error if `timer0` is requested or if the database operation
/// fails.
#[frb(ignore)]
pub fn delete_timer(key: &str) -> Result<()> {
    log::info!("Deleting timer with key: '{}'", key);

    if key == "timer0" {
        anyhow::bail!("The base timer 'timer0' cannot be deleted");
    }

    let db = db();

    db.as_ref()
        .unwrap()
        .execute("DELETE FROM timers WHERE key = ?1", [key])
        .context("Failed to delete timer")?;

    Ok(())
}

/// Returns a timer configuration that should be used to create a replacement
/// timer run.
///
/// If multiple timers remain, a random timer is selected. If only `timer0`
/// remains, `timer0` is selected.
#[frb(ignore)]
pub fn get_random_remaining_timer() -> Result<(String, TimerConfig)> {
    log::info!("Selecting timer for replacement run...");

    let db = db();

    let (key, json): (String, String) = db
        .as_ref()
        .unwrap()
        .query_one(
            r#"
            SELECT key, value
            FROM timers
            ORDER BY
                CASE WHEN key = 'timer0' THEN 1 ELSE 0 END,
                RANDOM()
            LIMIT 1
            "#,
            [],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?
        .context("Failed to select replacement timer")?;

    let config: TimerConfig =
        serde_json::from_str(&json).context("Failed to deserialize replacement timer")?;

    Ok((key, config))
}

/// Returns whether the timer_run table currently contains a run.
#[frb(ignore)]
pub fn timer_run_exists() -> Result<bool> {
    let db = db();

    let exists: bool = db
        .as_ref()
        .unwrap()
        .query_one("SELECT EXISTS(SELECT 1 FROM timer_run)", [], |row| {
            row.get(0)
        })?
        .context("Failed to check for timer run")?;

    Ok(exists)
}
