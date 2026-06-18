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

/// Returns a single row.
///
/// Returns `None` if no matching row exists.
pub fn select_one(sql: &str) -> String {
    let db = db();
    db.query_one(sql, [], |row| row.get::<_, String>(0))
        .unwrap()
        .unwrap()
}

/// Returns JSON with data of multiple rows.
///
/// # Example
///
/// ```rust
/// let users = db.query_many(
///     "SELECT id, name FROM users WHERE name LIKE %?%",
///     [mark]
/// )?;
/// ```
///
/// Returns:
///
/// ```json
/// [
///   { "id": 2, "name": "Mark" },
///   { "id": 5, "name": "Denmark" }
/// ]
/// ```
///
/// Usage in Dart:
///
/// ```dart
/// import 'dart:convert';
/// (...)
/// final jsonStr = await query_many(...);
/// final List data = jsonDecode(jsonStr);
/// String name = data[0]['name'];
/// ```
pub fn select(sql: &str) -> String {
    let db = db();
    db.query_many(sql, []).unwrap()
}

/// Execute a SQL statement.
pub fn execute_sql(sql: &str) -> Result<usize> {
    let db = db();
    db.execute(sql, [])
}

/// Execute multiple SQL statements.
///
/// Example:
///
/// ```rust
/// db.execute_batch(
///     "
///     CREATE TABLE users (
///         id INTEGER PRIMARY KEY,
///         name TEXT NOT NULL
///     );
///
///     CREATE INDEX idx_users_name
///     ON users(name);
///     "
/// )?;
/// ```
pub fn execute_batch_sql(sql: &str) {
    let db = db();
    let _ = db.execute_batch(sql);
}
