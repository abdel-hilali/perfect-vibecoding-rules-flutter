import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kit_app/app.dart';
import 'package:kit_app/core/common/widgets/app_bottom_bar.dart';
import 'package:kit_app/core/config/injection-modules/settings_module.dart';
import 'package:kit_app/core/router/app_router.dart';
import 'package:kit_app/core/storage/session.dart';
import 'package:kit_app/core/storage/session_tokens.dart';
import 'package:kit_app/features/auth/presentation/pages/sign_in_page.dart';
import 'package:kit_app/features/orders/presentation/pages/orders_page.dart';
import 'package:kit_app/features/settings/presentation/pages/settings_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../fakes/fake_secure_store.dart';

/// Every path the router registers, and the page a signed-in user sees there. A new route needs its row here.
const routes = [
  (path: OrdersPage.path, page: OrdersPage),
  (path: SettingsPage.path, page: SettingsPage),
  // Signed in, the gate sends the sign-in page on to the first tab.
  (path: SignInPage.path, page: OrdersPage),
];

/// The page of each MainShell tab, in the bottom bar's order.
const tabs = [OrdersPage, SettingsPage];

void main() {
  testWidgets('every registered path and every tab open their page', (
    tester,
  ) async {
    // The settings route builds the app's own preferences: in memory here, never the computer's store.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final session = Session(FakeSecureStore());
    addTearDown(session.dispose);
    await session.signIn(SessionTokens.fakeAccount);
    final router = buildAppRouter(session: session);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      App(router: router, settings: SettingsModule.instance.settingsController),
    );
    await tester.pumpAndSettle();

    expect(
      registeredPaths(router.configuration.routes),
      unorderedEquals(routes.map((route) => route.path)),
    );
    for (final route in routes) {
      router.go(route.path);
      await tester.pumpAndSettle();
      expect(find.byType(route.page), findsOneWidget, reason: route.path);
    }

    final bar = tester.widget<AppBottomBar>(find.byType(AppBottomBar));
    expect(bar.tabs, hasLength(tabs.length));
    for (final (index, tab) in bar.tabs.indexed) {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomBar),
          matching: find.text(tab.label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(tabs[index]), findsOneWidget, reason: tab.label);
    }
  });
}

/// The full path of every GoRoute, nested ones included (a child's path is relative to its parent's).
Iterable<String> registeredPaths(
  List<RouteBase> children, [
  String parent = '',
]) sync* {
  for (final route in children) {
    var path = parent;
    if (route is GoRoute) {
      path = route.path.startsWith('/') ? route.path : '$parent/${route.path}';
      yield path;
    }
    yield* registeredPaths(route.routes, path);
  }
}
