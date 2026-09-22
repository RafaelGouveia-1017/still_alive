import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:still_alive/src/rust/frb_generated.dart';

import 'package:still_alive/src/rust/api/data/db.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await RustLib.init();

    Directory documentDirectory = await getApplicationDocumentsDirectory();
    String databasePath = p.join(documentDirectory.path, 'DB_for_tests.db');

    if (await File(databasePath).exists()) await purgeDatabase();

    try {
      await initDatabase(path: databasePath);
    } catch (e) {
      throw ('Database Error: $e');
    }
  });

  test('DB manipulation', () async {
    expect('true', await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'"));
    await executeSql(sql: "UPDATE settings SET value = 'false' WHERE key = 'tutorial'");
    expect('false', await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'"));
  });
}
