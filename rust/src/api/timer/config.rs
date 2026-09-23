use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Configuration for a timer.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(opaque)]
pub struct TimerConfig {
    /// Human-readable name of the timer.
    pub name: String,

    /// Timer duration in seconds.
    pub duration_secs: i64,

    /// Optional grace period in seconds after the timer expires.
    pub grace_period_secs: Option<i64>,

    /// Whether the timer requires password verification for protected operations.
    pub password_protected: bool,

    /// Stored password hash used to verify protected operations.
    pub password_hash: Option<String>,

    /// Whether the timer should obtain the device's location when an emergency
    /// is triggered.
    ///
    /// When this is `true` and [routeSharingEnabled] is `false`, the application
    /// obtains the device's current location at emergency time and shares that
    /// single location.
    ///
    /// When [routeSharingEnabled] is `true`, location collection is implicitly
    /// enabled and the application records a GPS route throughout the active
    /// timer run instead of obtaining only a single location at emergency time.
    pub location_sharing_enabled: bool,

    /// Whether the timer should record and share a complete GPS route.
    ///
    /// When this is `true`, location collection is implicitly enabled. The
    /// [locationCollectionIntervalSecs] value determines the minimum interval
    /// between persisted GPS route points.
    ///
    /// When this is `false` but [locationSharingEnabled] is `true`, no continuous
    /// route is recorded. Instead, the application's current location is obtained
    /// when an emergency is triggered and that single location is shared.
    ///
    /// When both [locationSharingEnabled] and [routeSharingEnabled] are `false`,
    /// no location is collected or shared.
    pub route_sharing_enabled: bool,

    /// The minimum number of seconds between persisted GPS route points.
    ///
    /// This value is only used when [routeSharingEnabled] is `true`.
    ///
    /// When route sharing is disabled, this value has no effect because the
    /// application does not continuously record the device's location.
    pub location_collection_interval_secs: Option<i64>,

    /// Whether audio recording is enabled for this timer.
    pub audio_recording_enabled: bool,

    /// Contacts associated with the timer.
    pub contacts: Vec<Contact>,

    /// Custom SMS messages associated with the timer.
    pub custom_sms: Vec<String>,

    /// Custom email messages associated with the timer.
    pub custom_email: Vec<String>,

    /// External service integrations configured for the timer.
    pub integrations: TimerIntegrations,

    /// Custom text to send to the destinations.
    pub message: Option<String>,

    /// Timestamp or serialized date representing when the timer configuration was created.
    pub created_at: String,

    /// Timestamp or serialized date representing when the timer configuration was last updated.
    pub updated_at: String,
}

impl TimerConfig {
    /// Creates a new timer configuration from the given fields.
    #[frb(sync)]
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        name: String,
        duration_secs: i64,
        grace_period_secs: Option<i64>,
        password_protected: bool,
        password_hash: Option<String>,
        location_sharing_enabled: bool,
        route_sharing_enabled: bool,
        location_collection_interval_secs: Option<i64>,
        audio_recording_enabled: bool,
        contacts: Vec<Contact>,
        custom_sms: Vec<String>,
        custom_email: Vec<String>,
        integrations: TimerIntegrations,
        message: Option<String>,
        created_at: String,
        updated_at: String,
    ) -> Self {
        Self {
            name,
            duration_secs,
            grace_period_secs,
            password_protected,
            password_hash,
            location_sharing_enabled,
            route_sharing_enabled,
            location_collection_interval_secs,
            audio_recording_enabled,
            contacts,
            custom_sms,
            custom_email,
            integrations,
            message,
            created_at,
            updated_at,
        }
    }
}

/// Represents a contact associated with a timer.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Contact {
    /// Unique identifier of the contact.
    pub id: String,

    /// SMS destinations associated with the contact.
    pub sms: Vec<String>,

    /// Email destinations associated with the contact.
    pub email: Vec<String>,
}

/// Contains the external integrations configured for a timer.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimerIntegrations {
    /// Discord integration configuration.
    pub discord: TimerIntegration,

    /// Telegram integration configuration.
    pub telegram: TimerIntegration,
}

/// Configuration for a specific external integration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimerIntegration {
    /// Accounts configured for this integration.
    pub accounts: Vec<TimerIntegrationAccount>,
}

/// Represents an account configured for an external integration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimerIntegrationAccount {
    /// Unique identifier of the integration account.
    pub id: String,

    /// Destinations associated with the account.
    ///
    /// The meaning of a destination depends on the integration, such as a
    /// Discord channel or Telegram chat.
    pub destinations: Vec<String>,
}
