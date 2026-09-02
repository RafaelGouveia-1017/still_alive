import 'package:flutter/services.dart';

/// Provides the shared communication channel between Flutter and a native platform (ex: Android).
class AppMethodChannel {
  /// Name of the native MethodChannel.
  static const String name = 'com.appsbyrafa.stillalive/flutter';

  /// Shared MethodChannel instance.
  static const MethodChannel instance = MethodChannel(name);
}
