use crate::api::data::database::Database;
use anyhow::{anyhow, Result};
use flutter_rust_bridge::frb;
use std::{
    path::{Path, PathBuf},
    sync::{Mutex, MutexGuard, OnceLock},
};

static DATABASE_PATH: OnceLock<PathBuf> = OnceLock::new();
static DATABASE: OnceLock<Mutex<Option<Database>>> = OnceLock::new();
static DATABASE_NAME: &str = "still_alive.db";

/// Returns the database name (with extension).
pub fn get_database_name() -> String {
    DATABASE_NAME.to_owned()
}

/// Initialize the application database.
///
/// Must be called exactly once during app startup.
pub fn init_database(path: String) -> Result<()> {
    if let Some(existing) = DATABASE_PATH.get() {
        if existing == Path::new(&path) {
            return Ok(());
        }
        return Err(anyhow!("database already initialized with different path"));
    }

    DATABASE_PATH.set(PathBuf::from(&path)).unwrap();

    let db = Some(Database::open(&path)?);
    DATABASE.set(Mutex::new(db)).unwrap();

    Ok(())
}

/// Get the global database instance.
///
/// Panics if the database has not been initialized.
#[frb(ignore)]
pub fn db() -> MutexGuard<'static, Option<Database>> {
    DATABASE
        .get()
        .expect("database not initialized")
        .lock()
        .unwrap()
}

/// Get the configured database path.
///
/// Panics if the database has not been initialized.
#[frb(ignore)]
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

/// Open connection to application database.
///
/// Opens the database located at the configured database path and stores
/// it in the global database instance.
///
/// # Errors
///
/// Returns an error if:
///
/// - the database file cannot be opened
/// - SQLite initialization fails
pub fn open_database() -> Result<()> {
    let mut db = db();

    *db = Some(Database::open(database_path_str())?);

    Ok(())
}

/// Close connection to application database.
///
/// After calling this function, any attempt to access the database
/// must first reopen it using [`open_database`].
///
/// Closing the database is required before replacing the underlying
/// database file during an import operation.
///
/// Calling this function multiple times is safe.
///
/// # Errors
///
/// Returns an error if SQLite fails to close the connection.
pub fn close_database() -> Result<()> {
    let mut db = db();

    if let Some(database) = db.take() {
        database.close()?;
    }

    Ok(())
}

/// Export the application database.
///
/// Performs a consistent export of the current SQLite database by:
///
/// 1. Performing a WAL checkpoint.
/// 2. Copying the database file.
///
/// The database connection remains open during the export.
///
/// # Arguments
///
/// * `path` - Destination path of the exported database.
///
/// # Errors
///
/// Returns an error if the checkpoint or file copy fails.
///
/// # Notes
///
/// This function only exports the SQLite database.
///
/// Metadata generation and ZIP creation should be handled by
/// higher-level backup functions.
pub fn export_database(path: &str) -> Result<()> {
    let db = db();

    db.as_ref().unwrap().export(path)
}

/// Import a SQLite database.
///
/// Replaces the current application database with an imported one.
///
/// The import procedure is:
///
/// 1. Close the current database.
/// 2. Replace the database file.
/// 3. Reopen the database.
///
/// # Arguments
///
/// * `path` - Path to the imported database.
///
/// # Errors
///
/// Returns an error if:
///
/// - the current database cannot be closed
/// - the database file cannot be copied
/// - the imported database cannot be opened
///
/// # Warning
///
/// The imported database completely replaces the existing one.
///
/// Existing data cannot be recovered unless a backup exists.
pub fn import_database(path: &str) -> Result<()> {
    close_database()?;

    std::fs::copy(path, database_path_str())?;

    open_database()?;

    Ok(())
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
    db.as_ref()
        .unwrap()
        .query_one(sql, [], |row| row.get::<_, String>(0))
        .unwrap_or_else(|err| panic!("Database query failed: {err}"))
        .unwrap_or_else(|| String::from("None"))
}

/// Returns JSON with data of multiple rows.
///
/// # Example
///
/// ```rust
/// let users = db.select(
///     "SELECT id, name FROM users WHERE name LIKE %?%"
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
/// String jsonStr = await select(...);
/// List<dynamic> data = jsonDecode(jsonStr);
/// String name = data[0]['name'];
/// ```
pub fn select(sql: &str) -> String {
    let db = db();
    db.as_ref().unwrap().query_many(sql, []).unwrap()
}

/// Execute a SQL statement.
pub fn execute_sql(sql: &str) -> Result<usize> {
    let db = db();
    db.as_ref().unwrap().execute(sql, [])
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
    let _ = db.as_ref().unwrap().execute_batch(sql);
}

/// Custom execute_sql function to prevent SQL injection from user.
pub fn update_message(message: String) -> Result<usize> {
    let db = db();
    db.as_ref().unwrap().execute(
        "UPDATE settings SET value = ?1 WHERE key = ?2",
        rusqlite::params![message, "message"],
    )
}
