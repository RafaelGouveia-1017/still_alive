use log::{LevelFilter, Log, Metadata, Record};
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::frb_generated::StreamSink;

/// A log record emitted by Rust and transported to Dart through
/// [`flutter_rust_bridge`]'s [`StreamSink`].
///
/// `RustLogRecord` intentionally contains the useful source metadata provided
/// by the [`log`] crate so that the Dart logging layer can preserve information
/// about where a Rust log originated.
///
/// The FRB code generator generates the necessary serialization code for this
/// type. On the Dart side, the generated type is received from
/// `createRustLogStream()` and is converted into the application's normal
/// Dart `Logger` records.
///
/// # Logging pipeline
///
/// A Rust logging macro such as:
///
/// ```ignore
/// log::info!("Connected to server");
/// ```
///
/// follows this path:
///
/// ```text
/// log::info!()
///     │
///     ▼
/// RustLogger::log()
///     │
///     ▼
/// RustLogRecord
///     │
///     ▼
/// StreamSink<RustLogRecord>
///     │
///     │ flutter_rust_bridge
///     ▼
/// Dart Stream<RustLogRecord>
///     │
///     ▼
/// Application logger
/// ```
///
/// If the Dart logging stream has not yet been established, the record is not
/// sent to Dart. Instead, the logger falls back to Rust-side logging so that
/// messages emitted during application startup are not silently discarded.
#[derive(Clone, Debug)]
pub struct RustLogRecord {
    /// Unix timestamp in milliseconds when Rust created the record.
    pub time_millis: i64,

    /// ERROR, WARN, INFO, DEBUG, TRACE.
    pub level: String,

    /// Rust log target, e.g. "my_crate::network".
    pub target: String,

    /// Rust module path.
    pub module_path: Option<String>,

    /// Rust source file.
    pub file: Option<String>,

    /// Rust source line.
    pub line: Option<u32>,

    /// Actual log message.
    pub message: String,
}

/// The global Rust logger instance.
///
/// `log` allows only one global logger to be installed for a process. This
/// logger is therefore stored as a static value and registered by
/// [`init_rust_logging`].
///
/// The logger itself contains only the current Dart [`StreamSink`]. The sink is
/// optional because Rust code can emit logs before Dart has established the
/// Rust-to-Dart logging stream.
///
/// The internal [`RwLock`] makes the logger safe to access from multiple Rust
/// threads. Logging may occur concurrently from asynchronous tasks, worker
/// threads, or other native code, while the Dart stream can be connected or
/// disconnected independently.
static RUST_LOGGER: RustLogger = RustLogger::new();

/// The implementation of [`log::Log`] responsible for forwarding Rust log
/// records to Dart.
///
/// `RustLogger` does not own the logging configuration itself. The global
/// [`log`] crate remains responsible for filtering records according to
/// [`log::max_level`].
///
/// Its primary responsibility is to:
///
/// 1. receive records from the `log` crate,
/// 2. convert them into [`RustLogRecord`],
/// 3. forward them through the active FRB [`StreamSink`],
/// 4. gracefully handle the absence or disconnection of Dart.
///
/// The logger is intentionally kept independent of Flutter or Dart-specific
/// application code. The only bridge-specific dependency is the FRB
/// [`StreamSink`].
struct RustLogger {
    /// The currently active Rust-to-Dart stream sink.
    ///
    /// The sink is wrapped in an [`Arc`] because log records may be emitted
    /// concurrently from multiple threads. Each logging call obtains a cloned
    /// `Arc` before releasing the read lock, allowing the actual stream
    /// operation to proceed without holding the lock.
    ///
    /// `None` means that Dart has not connected a logging stream, or that the
    /// previously connected stream has been disconnected.
    ///
    /// The [`RwLock`] allows the common logging path to acquire a read lock
    /// while still allowing the sink to be replaced or removed exclusively
    /// when Dart connects or disconnects.
    sink: RwLock<Option<Arc<StreamSink<RustLogRecord>>>>,
}

impl RustLogger {
    /// Creates a new logger with no Dart logging sink attached.
    ///
    /// This is a `const fn` so that the global [`RUST_LOGGER`] can be
    /// initialized statically.
    const fn new() -> Self {
        Self {
            sink: RwLock::new(None),
        }
    }

    /// Installs or replaces the active Rust-to-Dart logging sink.
    ///
    /// This method is called by [`create_rust_log_stream`] when Dart establishes
    /// its subscription.
    ///
    /// Replacing the existing sink is intentional. It allows the Dart side to
    /// reconnect after a hot restart, Flutter engine restart, or other
    /// lifecycle event without requiring the Rust logger itself to be
    /// recreated.
    ///
    /// The sink is wrapped in an [`Arc`] so individual logging calls can safely
    /// retain it after releasing the [`RwLock`] read guard.
    fn set_sink(&self, sink: StreamSink<RustLogRecord>) {
        let mut guard = self
            .sink
            .write()
            .unwrap_or_else(|poisoned| poisoned.into_inner());

        *guard = Some(Arc::new(sink));
    }

    /// Removes the currently active Rust-to-Dart logging sink.
    ///
    /// After this method returns, subsequent Rust log records will use the
    /// logger's fallback behavior until Dart establishes another stream with
    /// [`create_rust_log_stream`].
    ///
    /// This is also called automatically when sending a record to Dart fails,
    /// preventing subsequent records from repeatedly attempting to use a
    /// known-stale stream sink.
    fn clear_sink(&self) {
        let mut guard = self
            .sink
            .write()
            .unwrap_or_else(|poisoned| poisoned.into_inner());

        *guard = None;
    }

    /// Returns a cloned reference to the currently active Dart logging sink.
    ///
    /// The returned [`Arc`] allows the caller to release the internal
    /// [`RwLock`] before sending the log record. This is important because
    /// sending a record may involve work outside the logger's synchronization
    /// mechanism and should not unnecessarily block another thread attempting
    /// to connect or disconnect the Dart stream.
    ///
    /// Returns `None` when Dart has not connected a logging stream.
    fn get_sink(&self) -> Option<Arc<StreamSink<RustLogRecord>>> {
        self.sink
            .read()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }
}

impl Log for RustLogger {
    /// Determines whether a log record should be processed.
    ///
    /// The global maximum log level is controlled by [`log::set_max_level`].
    /// This method delegates filtering to that global configuration rather
    /// than maintaining a separate log-level setting inside `RustLogger`.
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= log::max_level()
    }

    /// Receives a Rust log record from the [`log`] crate.
    ///
    /// The record is converted into [`RustLogRecord`] and forwarded to Dart
    /// when a Dart stream is connected.
    ///
    /// If Dart has not connected yet, the record is emitted using the Rust
    /// logging infrastructure instead of being silently discarded. This is
    /// especially useful during application startup, when Rust initialization
    /// can happen before Dart has established its logging subscription.
    ///
    /// If forwarding to Dart fails, the current sink is considered stale and
    /// is removed. This prevents every subsequent Rust log record from
    /// repeatedly attempting to send through a disconnected Dart stream.
    fn log(&self, record: &Record) {
        if !self.enabled(record.metadata()) {
            return;
        }

        let time_millis = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;

        let rust_record = RustLogRecord {
            time_millis,
            level: record.level().to_string(),
            target: record.target().to_owned(),
            module_path: record.module_path().map(ToOwned::to_owned),
            file: record.file().map(ToOwned::to_owned),
            line: record.line(),
            message: record.args().to_string(),
        };

        let Some(sink) = self.get_sink() else {
            // Dart isn't connected yet. Keep the record visible through the
            // Rust logging infrastructure rather than silently dropping it.
            eprintln!("{} - {}", record.level(), record.args());
            return;
        };

        if let Err(error) = sink.add(rust_record) {
            eprintln!("Failed to forward Rust log to Dart: {error:?}");

            // The Dart stream may have been cancelled or the Flutter engine
            // may have been restarted. Remove the stale sink so future records
            // fall back to Rust-side logging until Dart reconnects.
            self.clear_sink();
        }
    }

    /// Flushes buffered log output.
    ///
    /// No additional buffering is performed by [`RustLogger`] itself, so there
    /// is nothing to flush here. The method is required by the [`log::Log`]
    /// trait.
    fn flush(&self) {}
}

/// Installs [`RustLogger`] as the global logger for the [`log`] crate.
///
/// This should be called during Rust library initialization, before Rust code
/// begins emitting application logs.
///
/// The function is intentionally tolerant of an existing global logger. The
/// `log` crate permits only one global logger, so another Rust dependency or
/// application component may already have installed one. In that case,
/// `set_logger` simply fails and this function leaves the existing logger
/// untouched rather than panicking.
///
/// When installation succeeds, the maximum log level is set to
/// [LevelFilter::Info], which allows all `log` levels to reach [`RustLogger`].
/// Dart-side logging can then decide how verbose the application's final output
/// should be.
///
/// # Initialization
///
/// This function is normally invoked automatically through FRB's initialization
/// mechanism, for example:
///
/// ```rust,ignore
/// #[frb(init)]
/// pub fn init_rust_logging() {
///     // ...
/// }
/// ```
///
/// Once installed, ordinary Rust logging macros can be used throughout the
/// application:
///
/// ```rust,ignore
/// log::error!("Something went wrong");
/// log::warn!("Something looks suspicious");
/// log::info!("Application started");
/// log::debug!("Received response");
/// log::trace!("Detailed diagnostic information");
/// ```
pub fn init_rust_logging() {
    // It is possible that another Rust library/application component has
    // already installed a logger. Don't panic in that case.
    if log::set_logger(&RUST_LOGGER).is_ok() {
        log::set_max_level(LevelFilter::Info);
    }
}

/// Establishes the Rust-to-Dart logging stream.
///
/// The generated Dart API exposes this as a stream of [`RustLogRecord`] values.
/// When Dart subscribes to that stream, FRB provides the corresponding
/// [`StreamSink`] to this function.
///
/// The sink is retained by [`RUST_LOGGER`] after this function returns, allowing
/// Rust logging calls to occur independently of the lifetime of this function.
///
/// Calling this function again replaces the previous sink. This makes the
/// logging connection safe to recreate during Flutter lifecycle events such as
/// hot restart or Dart-side reconnection.
///
/// Rust logs emitted before the Dart stream is established use the fallback
/// behavior in [`RustLogger::log`] and are not replayed after Dart connects.
pub fn create_rust_log_stream(sink: StreamSink<RustLogRecord>) {
    RUST_LOGGER.set_sink(sink);
}

/// Disconnects the active Rust-to-Dart logging stream.
///
/// After disconnection, Rust logging continues to work, but records are no
/// longer forwarded to Dart until [`create_rust_log_stream`] is called again.
///
/// This is useful when the Flutter/Dart side is being shut down, restarted, or
/// otherwise needs to explicitly release the active stream.
///
/// A failed stream send automatically performs the equivalent cleanup, so
/// callers generally only need to invoke this function when they want to
/// proactively disconnect the logging bridge.
pub fn dispose_rust_log_stream() {
    RUST_LOGGER.clear_sink();
}
