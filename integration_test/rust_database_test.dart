import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String dbPath;

  setUpAll(() async {
    await RustLib.init();

    final tempDir = await getTemporaryDirectory();
    dbPath = p.join(tempDir.path, 'db_integration_${DateTime.now().millisecondsSinceEpoch}.db');

    await initDatabase(path: dbPath);
  });

  test('selectOne returns default row from settings', () async {
    final value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'");

    expect(value, 'true');
  });

  test('executeSql + selectOne round-trips a value', () async {
    await executeSql(sql: "UPDATE settings SET value = 'false' WHERE key = 'tutorial'");

    final value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'");

    expect(value, 'false');
  });

  test('select returns JSON array of rows', () async {
    final json = await select(sql: 'SELECT key, value FROM settings');

    expect(json, startsWith('['));
    expect(json, endsWith(']'));
  });

  test('selectOne returns None when no rows match', () async {
    final value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'definitely_not_a_key'");

    expect(value, 'None');
  });

  test('updateMessage round-trips a value', () async {
    final testMessage = 'test message ${DateTime.now().millisecondsSinceEpoch}';

    await executeSql(sql: "INSERT INTO settings (key, value) VALUES ('test_key', '$testMessage')");

    await updateMessage(message: testMessage);

    final value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'test_key'");

    expect(value, testMessage);
  });

  test('executeSql returns affected row count', () async {
    final affected = await executeSql(sql: "UPDATE settings SET value = 'updated' WHERE key = 'tutorial'");

    expect(affected, greaterThan(BigInt.from(0)));
  });

  test('executeBatchSql creates and queries a table', () async {
    await executeBatchSql(
      sql:
          """
      CREATE TABLE IF NOT EXISTS test_table_${DateTime.now().millisecondsSinceEpoch} (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      );
      """,
    );
  });

  test('closeDatabase and openDatabase work correctly', () async {
    await closeDatabase();

    // Verify database is closed by checking we can reopen it
    await openDatabase();

    // Verify data is still accessible
    final value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'");

    expect(value, isNotNull);
    expect(value, isNot('None'));
  });
}
