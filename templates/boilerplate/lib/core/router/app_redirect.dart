import 'package:kit_app/features/auth/presentation/pages/sign_in_page.dart';
import 'package:kit_app/features/orders/presentation/pages/orders_page.dart';

/// The query parameter that carries where a signed-out user was going.
const String nextParam = 'next';

/// Every redirect of the app, in ONE pure function (F7): no redirect logic in pages, and each gate unit-tested.
///
/// The router calls it on every navigation and whenever the session changes (refreshListenable). Returns where
/// to go instead, or null to stay. A new gate (onboarding, update required, a role) is a new named parameter.
String? appRedirect(Uri location, {required bool signedIn}) {
  final path = location.path;
  final atSignIn = path == SignInPage.path;
  if (!signedIn) {
    if (atSignIn) {
      return null;
    }
    // Keep where the user was going, so sign-in can bring them back there.
    return Uri(
      path: SignInPage.path,
      queryParameters: {nextParam: location.toString()},
    ).toString();
  }
  if (atSignIn) {
    return safeNext(location.queryParameters[nextParam]) ?? OrdersPage.path;
  }
  if (path.isEmpty || path == '/') {
    return OrdersPage.path;
  }
  return null;
}

/// [next] when it is one of the app's own paths, else null (F7).
///
/// A `?next=` value can come from outside (a deep link): a full URL or a `//host` path would send the user to
/// another site, and the sign-in page itself would loop.
String? safeNext(String? next) {
  if (next == null || !next.startsWith('/') || next.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(next);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path == SignInPage.path) {
    return null;
  }
  return next;
}
