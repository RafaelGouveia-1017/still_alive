import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/backup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String dbPath;
  late String logPath;

  setUpAll(() async {
    await RustLib.init();

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    dbPath = p.join(tempDir.path, 'backup_test_$timestamp.db');
    logPath = p.join(tempDir.path, 'backup_test_$timestamp.log');

    // Create the log file (required by exportBackup).
    await File(logPath).writeAsString('Test log content\n');

    await initDatabase(path: dbPath);
  });

  group('Backup Round-Trip', () {
    test('export and import a backup preserves data', () async {
      // Modify the database so we can verify the import worked.
      await executeSql(sql: "UPDATE settings SET value = 'backup_test' WHERE key = 'tutorial'");

      // Export the backup.
      final backupBytes = await exportBackup(appVersion: '1.0.0', logPath: logPath);

      expect(backupBytes.isNotEmpty, true, reason: 'Backup should have content');

      // Write the backup to a temp file.
      final tempDir = await getTemporaryDirectory();
      final backupPath = p.join(tempDir.path, 'backup_${DateTime.now().millisecondsSinceEpoch}.zip');

      await File(backupPath).writeAsBytes(backupBytes);

      // Modify the database to a different value.
      await executeSql(sql: "UPDATE settings SET value = 'modified' WHERE key = 'tutorial'");

      // Import the backup.
      await importBackup(zipPath: backupPath, appVersion: '1.0.0');

      // Verify the data was restored.
      final value = await selectOne(sql: "SELECT value FROM settings WHERE key = 'tutorial'");

      expect(value, 'backup_test');
    });

    test('importBackup rejects a backup from a different app version', () async {
      // Export a backup.
      final backupBytes = await exportBackup(appVersion: '1.0.0', logPath: logPath);

      // Write the backup to a temp file.
      final tempDir = await getTemporaryDirectory();
      final backupPath = p.join(tempDir.path, 'backup_${DateTime.now().millisecondsSinceEpoch}.zip');

      File(backupPath).writeAsBytesSync(backupBytes);

      // Try to import with a different app version.
      await expectLater(
        () => importBackup(zipPath: backupPath, appVersion: '2.0.0'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('app version'))),
      );
    });
  });

  group('Backup Format Validation', () {
    test('exportBackup produces a valid ZIP archive', () async {
      final backupBytes = await exportBackup(appVersion: '1.0.0', logPath: logPath);

      // Verify it's a ZIP file (starts with PK).
      expect(backupBytes[0], 0x50, reason: 'ZIP should start with PK');
      expect(backupBytes[1], 0x4B, reason: 'ZIP should start with PK');
    });

    test('exportBackup includes the database and metadata', () async {
      final backupBytes = await exportBackup(appVersion: '1.0.0', logPath: logPath);

      // Verify the backup is reasonably large (contains a database).
      expect(backupBytes.length, greaterThan(1000));
    });
  });
}
