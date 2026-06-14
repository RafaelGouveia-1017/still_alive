use crate::api::data::database::Database;
use anyhow::{anyhow, Result};
use std::{
    path::{Path, PathBuf},
    sync::{Mutex, MutexGuard, OnceLock},
};

static DATABASE_PATH: OnceLock<PathBuf> = OnceLock::new();
static DATABASE: OnceLock<Mutex<Database>> = OnceLock::new();
static DATABASE_NAME: &str = "still_alive.db";

/// Returns the database name (with extension).
pub fn get_database_name() -> String {
    DATABASE_NAME.to_owned()
}

/// Initialize the application database.
///
/// Must be called exactly once during app startup.
pub fn init_database(path: String) -> Result<()> {
    DATABASE_PATH
        .set(PathBuf::from(&path))
        .map_err(|_| anyhow!("database path already initialized"))?;

    let db = Database::open(&path)?;

    DATABASE
        .set(Mutex::new(db))
        .map_err(|_| anyhow!("database already initialized"))?;

    Ok(())
}

/// Get the global database instance.
///
/// Panics if the database has not been initialized.
#[flutter_rust_bridge::frb(ignore)]
pub fn db() -> MutexGuard<'static, Database> {
    DATABASE
        .get()
        .expect("database not initialized")
        .lock()
        .expect("database mutex poisoned")
}

/// Get the configured database path.
///
/// Panics if the database has not been initialized.
#[flutter_rust_bridge::frb(ignore)]
pub fn database_path() -> &'static Path {
    DATABASE_PATH
        .get()
        .expect("database path not initialized")
        .as_path()
}

/// Return the database path as a string.
pub fn database_path_str() -> &'static str {
    database_path()
        .to_str()
        .expect("database path is not valid UTF-8")
}

/// Delete the existing SQLite database.
pub fn purge_database() {
    let path = database_path_str();
    Database::purge(path);
}
