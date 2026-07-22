use crate::api::data::db::*;
use crate::api::data::metadata::*;
use anyhow::{anyhow, Result};
use std::{
    fs::{self, File},
    io::{Cursor, Read, Write},
};
use zip::{write::SimpleFileOptions, ZipArchive, ZipWriter};

/// Export a complete application backup as a ZIP archive in memory.
///
/// The generated backup contains:
///
/// - the SQLite database
/// - a metadata file
///
/// The ZIP archive is returned as raw bytes (`Vec<u8>`), making it
/// platform-independent.
///
/// # Export procedure
///
/// 1. Perform WAL checkpoint to ensure DB consistency.
/// 2. Read database file into memory.
/// 3. Generate metadata JSON in memory.
/// 4. Create ZIP archive in memory.
/// 5. Return ZIP as `Vec<u8>`.
///
/// The database connection remains open throughout the export.
///
/// # Arguments
///
/// * `app_version` - Application version.
///
/// # Returns
///
/// A `Vec<u8>` containing the full ZIP archive.
///
/// # Errors
///
/// Returns an error if:
///
/// - WAL checkpoint fails
/// - database file cannot be read
/// - metadata cannot be generated
/// - ZIP creation fails
///
/// # Notes
///
/// - No files are written to storage.
/// - Entire ZIP is held in memory.
pub fn export_backup(app_version: &str) -> Result<Vec<u8>> {
    let db = db();

    let database = db
        .as_ref()
        .ok_or_else(|| anyhow!("database not initialized"))?;

    database.checkpoint()?;

    let db_bytes = fs::read(database_path_str())?;

    let metadata_json = create_backup_metadata_string(app_version)?;

    let mut buffer = Vec::new();
    let cursor = Cursor::new(&mut buffer);
    let mut zip = ZipWriter::new(cursor);

    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);

    zip.start_file(get_database_name(), options)?;
    zip.write_all(&db_bytes)?;

    zip.start_file("metadata.json", options)?;
    zip.write_all(metadata_json.as_bytes())?;

    let log_path = database_path_str()
        .split(&get_database_name())
        .next()
        .unwrap();
    let log_bytes = fs::read(log_path.to_owned() + "app.log")?;

    zip.start_file("app.log", options)?;
    zip.write_all(&log_bytes)?;

    let cursor = zip.finish()?;
    let zip_buffer = cursor.into_inner().to_vec();

    Ok(zip_buffer)
}

/// Import an application backup from a ZIP archive.
///
/// # Import procedure:
///
/// 1. Extract ZIP archive into memory.
/// 2. Extract `metadata.json` and validate it.
/// 3. Validate backup format and compatibility.
/// 4. Extract database file into memory.
/// 5. Close current database connection.
/// 6. Overwrite existing database file.
/// 7. Reopen database.
///
/// # Arguments
///
/// - `zip_path` - Path to the backup ZIP archive.
/// - `app_version` - Current application version.
///
/// # Errors
///
/// Returns an error if:
///
/// - the ZIP archive is invalid
/// - required files are missing
/// - metadata validation fails
/// - the database cannot be replaced
pub fn import_backup(zip_path: &str, app_version: &str) -> Result<()> {
    let file = File::open(zip_path)?;

    let mut archive = ZipArchive::new(file)?;

    {
        let mut metadata_file = archive
            .by_name("metadata.json")
            .map_err(|_| anyhow!("metadata.json not found"))?;

        let mut metadata_str = String::new();
        metadata_file.read_to_string(&mut metadata_str)?;

        let metadata = validate_backup_metadata(&metadata_str)?;

        if metadata.format_version != 1 {
            return Err(anyhow!("unsupported backup format version"));
        }

        if metadata.app_version != app_version {
            return Err(anyhow!("backup created with different app version"));
        }
    };
    {
        let mut db_file = archive
            .by_name(&get_database_name())
            .map_err(|_| anyhow!("database file not found"))?;

        let mut db_bytes = Vec::new();
        db_file.read_to_end(&mut db_bytes)?;

        close_database()?;

        fs::write(database_path_str(), &db_bytes)?;

        open_database()?;
    };

    Ok(())
}
