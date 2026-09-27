import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:still_alive/src/rust/api/data/logging.dart';

/// Provides centralized application logging.
///
/// Logs are written to both:
/// - the debug console (visible when running `flutter run` or using a debugger),
/// - a log file stored in the application's documents directory.
///
/// A new log file is created each time the application starts, replacing any
/// existing log from a previous session.
///
/// Call [init] once during application startup before using [log].
class AppLogger {
  AppLogger._();

  /// The application's shared logger instance.
  ///
  /// Use this logger throughout the application instead of creating additional
  /// [Logger] instances.
  static final Logger log = Logger('StillAlive');

  static late File _logFile;
  static IOSink? _logSink;

  /// Initializes the logging system.
  ///
  /// This method:
  /// - creates a new `app.log` file in the application's documents directory,
  /// - deletes any existing log file from a previous session,
  /// - configures the root logger to capture all log levels,
  /// - forwards log records to both the debug console and the log file.
  ///
  /// This method should be called once before [runApp].
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();

    _logFile = File('${dir.path}/app.log');

    if (await _logFile.exists()) {
      await _logFile.delete();
    }

    await _logFile.create();

    // Keeps one persistent writer instead of opening the file for every log.
    _logSink = _logFile.openWrite(mode: FileMode.append);

    Logger.root.level = Level.ALL;

    Logger.root.onRecord.listen((record) {
      final message = StringBuffer()
        ..write('[${record.time.toIso8601String()}] ')
        ..write('${record.level.name}: ')
        ..write(record.message);

      if (record.error != null) {
        message.write('\nError: ${record.error}');
      }

      if (record.stackTrace != null) {
        message.write('\n${record.stackTrace}');
      }

      final formattedMessage = message.toString();
      debugPrint(formattedMessage);
      _logSink?.writeln(formattedMessage);
      _logSink?.writeln();
    });
  }

  /// Returns the current session's log file.
  ///
  /// This can be used to share the log file with the user, attach it to bug
  /// reports, or inspect its contents.
  static File getLogFile() => _logFile;

  /// Save log file in custom location.
  static Future<String?> saveLogFile() async {
    // Make sure everything currently buffered by the IOSink is on disk.
    await _logSink?.flush();

    return await FilePicker.saveFile(
      dialogTitle: "Save log file",
      fileName: 'StillAlive_Log_${DateTime.now().toIso8601String().replaceAll(':', '-')}.log',
      type: FileType.custom,
      allowedExtensions: ['log'],
      bytes: await getLogFile().readAsBytes(),
    );
  }

  /// Closes the log file writer.
  ///
  /// Call this when the application's logging lifecycle is ending.
  static Future<void> dispose() async {
    await _rustLogSubscription?.cancel();
    _rustLogSubscription = null;

    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
  }

  /// Subscription used to receive log records emitted by Rust.
  ///
  /// The subscription is kept so that an existing Rust logging connection can
  /// be cancelled before establishing a new one.
  static StreamSubscription<RustLogRecord>? _rustLogSubscription;

  /// Connects the Rust logger to the application's Dart logger.
  ///
  /// Rust log records received through [createRustLogStream] are converted to
  /// their corresponding [Level] from the `logging` package and forwarded to
  /// [AppLogger.log].
  ///
  /// Rust source metadata is included in the log message when available:
  /// - [RustLogRecord.target] identifies the Rust logging target.
  /// - [RustLogRecord.file] identifies the Rust source file.
  /// - [RustLogRecord.line] identifies the Rust source line.
  ///
  /// This allows Rust logs to follow the same logging pipeline as Dart logs,
  /// including the debug console and application log file configured by
  /// [AppLogger.init].
  ///
  /// If Rust logging is already connected, the existing subscription is
  /// cancelled before creating a new one. This makes the method safe to call
  /// multiple times without accumulating duplicate listeners.
  ///
  /// Call this after [AppLogger.init] and after the Rust library has been
  /// initialized.
  static void connectRustLogging() {
    _rustLogSubscription?.cancel();

    final stream = createRustLogStream();
    _rustLogSubscription = stream.listen((record) {
      final level = switch (record.level) {
        'ERROR' => Level.SEVERE,
        'WARN' => Level.WARNING,
        'INFO' => Level.INFO,
        'DEBUG' => Level.FINE,
        'TRACE' => Level.FINER,
        _ => Level.INFO,
      };

      final location = StringBuffer();

      /*
      if (record.target.isNotEmpty) {
        location.write(record.target);
      }
      */
      if (record.file != null) {
        if (location.isNotEmpty) {
          location.write(' ');
        }

        location.write(record.file);

        if (record.line != null) {
          location.write(':${record.line}');
        }
      }

      final message = location.isEmpty ? '[Rust] ${record.message}' : '[Rust][$location] ${record.message}';

      AppLogger.log.log(level, message);
    });
  }
}
