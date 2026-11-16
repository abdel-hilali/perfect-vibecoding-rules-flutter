import 'package:go_router/go_router.dart';
import 'package:kit_app/core/router/app_redirect.dart';
import 'package:kit_app/core/router/main_shell.dart';
import 'package:kit_app/core/storage/session.dart';
import 'package:kit_app/features/auth/auth_routes.dart';
import 'package:kit_app/features/orders/orders_routes.dart';
import 'package:kit_app/features/orders/presentation/pages/orders_page.dart';
import 'package:kit_app/features/settings/settings_routes.dart';

/// The ONE router of the app (F7), built once in main(). Features bring their routes; this file only assembles.
GoRouter buildAppRouter({required Session session}) {
  return GoRouter(
    initialLocation: OrdersPage.path,
    // Signing in or out re-runs the redirect at once, wherever the user is.
    refreshListenable: session,
    redirect: (context, state) =>
        appRedirect(state.uri, signedIn: session.isSignedIn),
    // A link to a path the app does not have opens the first tab, never an error page (F7).
    onException: (context, state, router) => router.go(OrdersPage.path),
    routes: [
      ...authRoutes(),
      // Each tab keeps its own stack and scroll position; MainShell draws the bottom bar.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: ordersRoutes()),
          StatefulShellBranch(routes: settingsRoutes()),
        ],
      ),
    ],
  );
}
