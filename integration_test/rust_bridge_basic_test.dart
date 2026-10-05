import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:still_alive/src/rust/api/integrations/public_traits.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String dbPath;

  setUpAll(() async {
    await RustLib.init();

    final tempDir = await getTemporaryDirectory();
    dbPath = p.join(tempDir.path, 'db_integration_${DateTime.now().millisecondsSinceEpoch}.db');

    await initDatabase(path: dbPath);
  });

  group('FRB Basic Bridge Tests', () {
    test('loadAllIntegrations returns both integrations', () async {
      final integrations = await loadAllIntegrations();

      expect(integrations.length, 2, reason: 'Expected Discord and Telegram');

      final discord = integrations.firstWhere((i) => i.key == 'discord', orElse: () => throw Exception('Discord not found'));
      final telegram = integrations.firstWhere((i) => i.key == 'telegram', orElse: () => throw Exception('Telegram not found'));

      expect(discord.title, 'Discord');
      expect(telegram.title, 'Telegram');

      expect(discord.connected, isFalse, reason: 'No Discord accounts should be connected by default');
      expect(telegram.connected, isFalse, reason: 'No Telegram accounts should be connected by default');
    });

    test('loadAllIntegrations returns valid gradient values', () async {
      final integrations = await loadAllIntegrations();

      for (final integration in integrations) {
        expect(integration.gradient.start, greaterThan(0), reason: 'Gradient start should be a positive ARGB value');
        expect(integration.gradient.end, greaterThan(0), reason: 'Gradient end should be a positive ARGB value');
      }
    });

    test('connectIntegrationAccount with empty token fails', () async {
      await expectLater(
        () => connectIntegrationAccount(key: 'discord', credentials: {'token': ''}),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('token'))),
      );
    });

    test('connectIntegrationAccount with whitespace token fails', () async {
      await expectLater(
        () => connectIntegrationAccount(key: 'telegram', credentials: {'token': '   '}),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('token'))),
      );
    });

    test('connectIntegrationAccount with unknown key fails', () async {
      await expectLater(
        () => connectIntegrationAccount(key: 'unknown_integration', credentials: {'token': '123'}),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('unknown integration'))),
      );
    });

    test('deleteIntegrationAccount with unknown account fails', () async {
      await expectLater(() => deleteIntegrationAccount(key: 'discord', accountId: 'nonexistent_account'), throwsA(isA<Exception>()));
    });
  });
}
