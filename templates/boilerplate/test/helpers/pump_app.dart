import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/widgets/show_app_toast.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The smallest phone the app supports (F16).
const Size smallPhone = Size(320, 640);

/// The catalog the tests read, so a test never retypes a sentence (F11).
final AppLocalizations l10nEn = lookupAppLocalizations(const Locale('en'));

/// Pumps [child] the way the app shows a page: the app's themes, catalogs and toast host, on a 320x640 phone with
/// a 1.3 text scale by default. An overflow there fails the test, and it is a real bug.
Future<void> pumpPage(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double textScale = 1.3,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = smallPhone;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      scaffoldMessengerKey: appMessengerKey,
      home: child,
    ),
  );
}
