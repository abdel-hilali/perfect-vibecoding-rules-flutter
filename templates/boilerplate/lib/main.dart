import 'package:flutter/services.dart';
import 'package:kit_app/app.dart';
import 'package:kit_app/core/config/env.dart';
import 'package:kit_app/core/config/injection-modules/session_module.dart';
import 'package:kit_app/core/config/injection-modules/settings_module.dart';
import 'package:kit_app/core/router/app_router.dart';
import 'package:material_ui/material_ui.dart';

/// Bootstrap only (F2): configuration, system bars, what the first frame needs, then runApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fails here, with the key's name, when assets/.env misses a required value (F13).
  await Env.load();
  // Edge to edge on every Android version (F9); from Android 15 the system forces it anyway.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final session = SessionModule.instance;
  final settings = SettingsModule.instance.settingsController;
  // Independent reads start together (F6), and both finish before the first frame: the app opens in the saved
  // theme and language, already signed in or out, with no flash.
  await Future.wait([session.start(), settings.load()]);
  runApp(
    App(
      router: buildAppRouter(session: session.session),
      settings: settings,
    ),
  );
}
