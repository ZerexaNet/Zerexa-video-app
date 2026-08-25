import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:zerexa_video/main.dart';
import 'package:zerexa_video/stores/app_stores.dart';
import 'package:zerexa_video/core/api.dart';
import 'package:zerexa_video/features/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compiles and constructs core singletons', () {
    SharedPreferences.setMockInitialValues({});
    final api = ZerexaApi(baseUrl: 'https://example.com');
    expect(api.baseUrl, 'https://example.com');
    expect(api.resolveAsset('/api/img.png'),
        'https://example.com/api/img.png');
  });

  testWidgets('app root builds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ZerexaApi(baseUrl: 'https://example.com');
    final app = ZerexaVideoApp(
      auth: AuthStore(prefs, api),
      themes: ThemeStore(prefs),
      badge: UnreadBadge(),
    );
    await tester.pumpWidget(app);
    await tester.pump();
    expect(find.byType(ZerexaVideoApp), findsOneWidget);
    // Let dio's timeout timers fire so no timer stays pending.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
