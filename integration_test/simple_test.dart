import 'package:flutter_test/flutter_test.dart';
import 'package:still_alive/main.dart';
import 'package:still_alive/data/app_themes.dart';
import 'package:still_alive/src/rust/api/data/theme.dart';
import 'package:still_alive/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(theme: AppThemes.themeData(CustomTheme.default_)),
    );
    expect(find.textContaining('Result: `Hello, Tom!`'), findsOneWidget);
  });
}
