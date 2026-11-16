import 'package:go_router/go_router.dart';
import 'package:kit_app/features/auth/presentation/pages/sign_in_page.dart';

/// The routes of the auth feature (F7). They sit outside the tab shell: no bottom bar before sign-in.
List<RouteBase> authRoutes() {
  return [
    GoRoute(
      path: SignInPage.path,
      name: SignInPage.name,
      builder: (context, state) => const SignInPage(),
    ),
  ];
}
