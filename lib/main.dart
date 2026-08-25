import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/app_shell.dart';
import 'core/api.dart';
import 'stores/app_stores.dart';
import 'theme/app_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final api = ZerexaApi();
  final auth = AuthStore(prefs, api);
  final themes = ThemeStore(prefs);
  final badge = UnreadBadge();
  unawaited(auth.bootstrap());

  runApp(ZerexaVideoApp(auth: auth, themes: themes, badge: badge));
}

void unawaited(Future<void> f) {}

class ZerexaVideoApp extends StatelessWidget {
  const ZerexaVideoApp({
    super.key,
    required this.auth,
    required this.themes,
    required this.badge,
  });

  final AuthStore auth;
  final ThemeStore themes;
  final UnreadBadge badge;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: themes),
        ChangeNotifierProvider.value(value: badge),
        Provider<ZerexaApi>.value(value: auth.api),
      ],
      child: ListenableBuilder(
        listenable: themes,
        builder: (context, _) => MaterialApp(
          title: 'Zerexa Video',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(themes.mode),
          home: const AppShell(),
        ),
      ),
    );
  }
}
