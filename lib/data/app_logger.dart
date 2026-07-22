import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

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

      debugPrint(message.toString());

      _logFile.writeAsString('$message\n\n', mode: FileMode.append);
    });
  }

  /// Returns the current session's log file.
  ///
  /// This can be used to share the log file with the user, attach it to bug
  /// reports, or inspect its contents.
  static File getLogFile() => _logFile;
}
