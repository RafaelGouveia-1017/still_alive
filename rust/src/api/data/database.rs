use anyhow::Result;
use rusqlite::{types::Value, Connection, OptionalExtension, Params, Row};
use serde_json::{self, json};
use std::fs;
use std::path::PathBuf;

/// Thin SQLite wrapper built on top of rusqlite.
///
/// # Features
///
/// - SQLite WAL mode enabled by default.
/// - Automatic database creation.
/// - Single-row and multi-row query helpers.
/// - Explicit WAL checkpoint support.
///
/// # Persistence
///
/// SQLite automatically persists committed changes to disk.
///
/// Since WAL mode is enabled, recent writes may temporarily reside in
/// the WAL file before being merged back into the main database file.
/// SQLite performs checkpoints automatically as needed.
///
/// Use [`Database::checkpoint`] if you need to force a checkpoint.
#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug)]
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open or create a SQLite database.
    /// If the database is empty (no tables exist),
    /// the provided `base_schema` SQL will be executed.
    ///
    /// WAL mode is enabled automatically.
    pub fn open(path: &str) -> Result<Self> {
        let conn = Connection::open(path)
            .inspect_err(|e| panic!("\n\n\nDB connection error: {e}\npath: {}\n\n\n", path))
            .unwrap();

        conn.execute_batch(
            r#"
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;
            "#,
        )?;

        // Ensure schema exists.
        let is_empty: bool = conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table'",
            [],
            |row| row.get::<_, i64>(0),
        )? == 0;

        if is_empty {
            conn.execute_batch(
                r#"
                    CREATE TABLE
                        settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);

                    INSERT INTO
                        settings
                    VALUES
                        ('tutorial', 'true'),
                        ('theme', 'SmartBell'),
                        ('lang', 'en');
                "#,
            )?;
        }

        Ok(Self { conn })
    }

    /// Delete an existing SQLite database.
    ///
    /// This removes:
    /// - main database file
    /// - WAL file
    /// - SHM file
    ///
    /// The application should not be actively using the database
    /// when this function is called.
    ///
    /// The application MUST restart after this function is called.
    pub fn purge(path: &str) {
        let _ = fs::remove_file(path);

        let wal_path = PathBuf::from(format!("{}-wal", path));
        let shm_path = PathBuf::from(format!("{}-shm", path));

        let _ = fs::remove_file(wal_path);
        let _ = fs::remove_file(shm_path);
    }

    /// Execute a SQL statement.
    pub fn execute<P: Params>(&self, sql: &str, params: P) -> Result<usize> {
        Ok(self.conn.execute(sql, params)?)
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
    pub fn execute_batch(&self, sql: &str) -> Result<()> {
        self.conn.execute_batch(sql)?;
        Ok(())
    }

    /// Query a single row.
    ///
    /// Returns `None` if no matching row exists.
    ///
    /// Example:
    ///
    /// ```rust
    /// let name = db.query_one(
    ///     "SELECT name FROM users WHERE id = ?",
    ///     [1],
    ///     |row| row.get::<_, String>(0),
    /// )?;
    /// ```
    pub fn query_one<T, P, F>(&self, sql: &str, params: P, mapper: F) -> Result<Option<T>>
    where
        P: Params,
        F: FnOnce(&Row<'_>) -> rusqlite::Result<T>,
    {
        Ok(self.conn.query_row(sql, params, mapper).optional()?)
    }

    /// Queries multiple rows and returns the result as JSON.
    ///
    /// # Arguments
    ///
    /// * `sql` - A SQL query string. Typically a `SELECT` statement.  
    /// * `params` - Dynnamic parameters for SQL query.  
    ///
    /// # Returns
    ///
    /// A JSON string representing a list of rows.  
    /// Each row is a JSON object where:
    /// - keys = column names
    /// - values = column values converted to JSON types:
    ///   - INTEGER → number
    ///   - REAL → floating point number
    ///   - TEXT → string
    ///   - NULL → null
    ///   - BLOB → base64 string (if enabled) or null
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
    ///   { "id": 1, "name": "Alice" },
    ///   { "id": 2, "name": "Bob" }
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
    ///
    /// # Notes
    ///
    /// - Column names are extracted dynamically at runtime.
    /// - This function supports queries across multiple tables (JOINs included).
    /// - Results are not typed; all output is serialized into JSON.
    /// - BLOB values may be base64-encoded depending on implementation.
    /// - Intended for flexible query execution, not strict type safety.
    ///
    /// # Safety
    ///
    /// This function executes raw SQL provided by the caller.  
    /// Do not expose it directly to untrusted input without validation or sanitization.
    /// (i.e: SQL injection)
    ///
    /// # Performance
    ///
    /// - Suitable for small to medium result sets.
    /// - Large datasets may require pagination (`LIMIT/OFFSET`) or streaming.
    ///
    /// # Panics
    ///
    /// This function does not panic. All errors are returned as `Err(String)`.
    pub fn query_many<P>(&self, sql: &str, params: P) -> Result<String, String>
    where
        P: Params,
    {
        let mut stmt = self.conn.prepare(sql).map_err(|e| e.to_string()).unwrap();

        let column_names: Vec<String> = (0..stmt.column_count())
            .map(|i| stmt.column_name(i).unwrap_or("").to_string())
            .collect();

        let rows_iter = stmt
            .query_map(params, |row| {
                let mut obj = serde_json::Map::new();

                for (i, name) in column_names.iter().enumerate() {
                    let value: Value = row.get(i)?;

                    let json_value = match value {
                        Value::Null => serde_json::Value::Null,
                        Value::Integer(v) => json!(v),
                        Value::Real(v) => json!(v),
                        Value::Text(v) => json!(v),
                        Value::Blob(_) => serde_json::Value::Null, // Value::Blob(b) => serde_json::Value::String(base64::encode(b)), //if it's an image or a file (must install base64 package)
                    };

                    obj.insert(name.clone(), json_value);
                }

                Ok(serde_json::Value::Object(obj))
            })
            .map_err(|e| e.to_string())?;

        let mut rows = Vec::new();

        for r in rows_iter {
            rows.push(r.map_err(|e| e.to_string())?);
        }

        serde_json::to_string(&rows).map_err(|e| e.to_string())
    }

    /// Force a WAL checkpoint.
    ///
    /// Normally SQLite performs checkpoints automatically.
    ///
    /// Useful when:
    ///
    /// - Preparing to copy the database file.
    /// - Reclaiming WAL disk space.
    /// - Administrative maintenance.
    pub fn checkpoint(&self) -> Result<()> {
        self.conn
            .execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;

        Ok(())
    }

    /// Return the row id of the most recent successful INSERT.
    pub fn last_insert_rowid(&self) -> i64 {
        self.conn.last_insert_rowid()
    }

    /// Expose the underlying rusqlite connection.
    pub fn connection(&self) -> &Connection {
        &self.conn
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn can_open_database() {
        let db = Database::open(":memory:").expect("failed to open database");

        db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY)", [])
            .unwrap();
    }

    #[test]
    fn can_create_table_and_query() -> Result<()> {
        let db = Database::open(":memory:")?;

        db.execute_batch("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")?;

        db.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])?;
        db.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])?;

        let alice_name = db.query_one("SELECT name FROM users WHERE id = ?", [1], |row| {
            row.get::<_, String>(0)
        })?;
        assert_eq!(alice_name, Some("Alice".to_string()));

        let json_all = db
            .query_many("SELECT id, name FROM users ORDER BY id", [])
            .unwrap();

        println!("{}", json_all);

        let parsed_all: serde_json::Value = serde_json::from_str(&json_all)?;

        assert_eq!(parsed_all[0]["id"], 1);
        assert_eq!(parsed_all[0]["name"], "Alice");

        assert_eq!(parsed_all[1]["id"], 2);
        assert_eq!(parsed_all[1]["name"], "Bob");

        Ok(())
    }

    #[test]
    fn persists_to_disk() -> Result<()> {
        let path = std::env::temp_dir().join("still_alive_test.db");
        let path_str = path.to_str().unwrap();

        Database::purge(path_str);

        {
            let db = Database::open(path_str)?;

            db.execute_batch("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL);")?;

            db.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])?;
        }

        {
            let db = Database::open(path_str)?;

            let name = db.query_one("SELECT name FROM users WHERE id = 1", [], |row| {
                row.get::<_, String>(0)
            })?;

            assert_eq!(name, Some("Alice".to_string()));
        }

        Database::purge(path_str);

        Ok(())
    }
}
