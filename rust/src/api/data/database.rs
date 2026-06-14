use anyhow::Result;
use rusqlite::{Connection, OptionalExtension, Params, Row};
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
                    CREATE TABLE settings (
                        key TEXT PRIMARY KEY,
                        value TEXT NOT NULL
                    );

                    INSERT INTO settings VALUES ('theme', 'Default');
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
        let _ = std::fs::remove_file(path);

        let wal_path = PathBuf::from(format!("{}-wal", path));
        let shm_path = PathBuf::from(format!("{}-shm", path));

        let _ = std::fs::remove_file(wal_path);
        let _ = std::fs::remove_file(shm_path);
    }

    /// Execute a SQL statement.
    pub fn execute<P: Params>(&self, sql: &str, params: P) -> Result<usize> {
        Ok(self.conn.execute(sql, params)?)
    }

    /// Execute multiple SQL statements.
    ///
    /// Example:
    ///
    /// ```ignore
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
    /// ```ignore
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

    /// Query multiple rows.
    ///
    /// Example:
    ///
    /// ```ignore
    /// let users = db.query_many(
    ///     "SELECT id, name FROM users",
    ///     [],
    ///     |row| {
    ///         Ok(User {
    ///             id: row.get(0)?,
    ///             name: row.get(1)?,
    ///         })
    ///     },
    /// )?;
    /// ```
    pub fn query_many<T, P, F>(&self, sql: &str, params: P, mut mapper: F) -> Result<Vec<T>>
    where
        P: Params,
        F: FnMut(&Row<'_>) -> rusqlite::Result<T>,
    {
        let mut stmt = self.conn.prepare(sql)?;

        let rows = stmt.query_map(params, |row| mapper(row))?;

        let mut results = Vec::new();

        for row in rows {
            results.push(row?);
        }

        Ok(results)
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

    #[derive(Debug, PartialEq)]
    struct User {
        id: i64,
        name: String,
    }

    #[test]
    fn can_create_table_and_query() -> Result<()> {
        let db = Database::open(":memory:")?;

        db.execute_batch(
            r#"
            CREATE TABLE users (
                id   INTEGER PRIMARY KEY,
                name TEXT NOT NULL
            );
            "#,
        )?;

        db.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])?;

        db.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])?;

        let alice_name = db.query_one("SELECT name FROM users WHERE id = ?", [1], |row| {
            row.get::<_, String>(0)
        })?;

        assert_eq!(alice_name, Some("Alice".to_string()));

        let users = db.query_many("SELECT id, name FROM users ORDER BY id", [], |row| {
            Ok(User {
                id: row.get(0)?,
                name: row.get(1)?,
            })
        })?;

        assert_eq!(
            users,
            vec![
                User {
                    id: 1,
                    name: "Alice".into(),
                },
                User {
                    id: 2,
                    name: "Bob".into(),
                },
            ]
        );

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
