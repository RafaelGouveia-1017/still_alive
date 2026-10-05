import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/data/logging.dart';
import 'package:still_alive/src/rust/api/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();

    final tempDir = await getTemporaryDirectory();
    final dbPath = p.join(tempDir.path, 'logging_test_${DateTime.now().millisecondsSinceEpoch}.db');
    await initDatabase(path: dbPath);
  });

  group('Rust-to-Dart Logging Bridge', () {
    test('disposeRustLogStream disconnects the stream', () async {
      final subscription = createRustLogStream().listen((_) {}, onError: (_) {});

      await disposeRustLogStream();

      await subscription.cancel();
    });
  });

  group('Dart-to-Rust String Marshaling', () {
    test('greet handles ASCII strings', () async {
      final result = await greet(name: 'Hello');
      expect(result, 'Hello, Hello!');
    });

    test('greet handles empty string', () async {
      final result = await greet(name: '');
      expect(result, 'Hello, !');
    });

    test('greet handles unicode characters', () async {
      final result = await greet(name: '世界🌍');
      expect(result, 'Hello, 世界🌍!');
    });

    test('greet handles long strings', () async {
      final longName = 'a' * 10000;
      final result = await greet(name: longName);
      expect(result.length, longName.length + 8); // "Hello, " + "!"
    });

    test('greet handles special characters', () async {
      final result = await greet(name: '<script>alert("xss")</script>');
      expect(result, 'Hello, <script>alert("xss")</script>!');
    });

    test('greet handles newlines and tabs', () async {
      final result = await greet(name: 'line1\nline2\tline3');
      expect(result, 'Hello, line1\nline2\tline3!');
    });
  });
}
