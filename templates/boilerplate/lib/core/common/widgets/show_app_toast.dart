import 'package:material_ui/material_ui.dart';

/// The ScaffoldMessenger of the app, mounted once: MaterialApp.router(scaffoldMessengerKey: appMessengerKey).
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The ONE way to tell the user that something happened (F12). Never a raw ScaffoldMessenger call in a page.
///
/// It needs no BuildContext, so it is safe after an await; read the text from the catalog before the await or
/// check `context.mounted` first. The look comes from SnackBarThemeData in AppTheme.
void showAppToast(String message) {
  final messenger = appMessengerKey.currentState;
  // No app is mounted (a test that pumps a bare widget, or the app is closing): nothing to show it on.
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
}
