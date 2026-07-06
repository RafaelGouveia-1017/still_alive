use anyhow::Result;
use chrono::Utc;
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::fs;

/// Metadata stored alongside exported backups.
///
/// This information allows future versions of the application to
/// identify when the backup was created and which application version
/// produced it.
///
/// The metadata is serialized as JSON.
#[frb(ignore)]
#[derive(Debug, Serialize, Deserialize)]
pub struct Metadata {
    pub app_version: String,
    pub created: String,
    pub format_version: u32,
}

/// Create a metadata JSON file for a database backup.
///
/// The generated file has the following structure:
///
/// ```json
/// {
///   "appVersion": "1.0.0",
///   "created": "2026-07-06T18:51:03Z"
/// }
/// ```
///
/// # Arguments
///
/// - `version` - Application version.
///
/// # Errors
///
/// Returns an error if:
///
/// - the metadata cannot be serialized
/// - the file cannot be written
///
/// # Notes
///
/// The creation timestamp is generated in UTC using RFC 3339 format.
///
/// This file is intended to be included in exported backup archives.
#[frb(ignore)]
pub fn create_backup_metadata(path: &str, app_version: &str) -> Result<()> {
    let metadata = Metadata {
        app_version: app_version.to_owned(),
        created: Utc::now().to_rfc3339(),
        format_version: 1,
    };

    let json = serde_json::to_string_pretty(&metadata)?;

    fs::write(path, json)?;

    Ok(())
}

/// Same function as [create_backup_metadata]
/// except it does not create a JSON file
/// and only returns the JSON string.
#[frb(ignore)]
pub fn create_backup_metadata_string(app_version: &str) -> Result<String> {
    let metadata = Metadata {
        app_version: app_version.to_owned(),
        created: Utc::now().to_rfc3339(),
        format_version: 1,
    };

    Ok(serde_json::to_string_pretty(&metadata)?)
}

/// Read and validate a backup metadata string.
///
/// Parses the metadata JSON string and returns the deserialized structure.
///
/// # Arguments
///
/// - `json` - metadata JSON string.
///
/// # Errors
///
/// Returns an error if:
///
/// - the JSON is malformed
/// - required fields are missing
#[frb(ignore)]
pub fn validate_backup_metadata(json: &str) -> Result<Metadata> {
    Ok(serde_json::from_str(&json)?)
}
