# Recipe: routing and guards (go_router)

## Problem

Redirect logic spread over pages lets a signed-out user see a screen for one frame, or loops between two pages. A
tab that rebuilds its page on every switch loses its scroll position. Back on a tab root closes the app at once,
and a deep link whose `?next=` holds a full URL sends the user to another site after sign-in.

## Rule

- ONE `GoRouter` in `lib/core/router/app_router.dart`, built once in `main()`, with `refreshListenable` set to the
  session (and any other state the redirect reads) (F7).
- ONE pure function decides every redirect: `appRedirect()` in `app_redirect.dart`, unit-tested for each gate. No
  redirect logic inside pages.
- Every page has `static const path` (and `name`). Each feature exports `List<RouteBase>` from
  `<feature>_routes.dart`; `app_router.dart` only assembles them.
- The tab shell is a `StatefulShellRoute.indexedStack`: each tab keeps its stack and scroll. `MainShell` draws the
  bottom bar. On a tab root, back twice leaves the app.
- A screen the backend cannot serve yet is a real, guarded route with a "coming soon" body, never a 404.
- Deep links accept only the app's own paths; a `?next=` value is an app path, never a URL.

## Code

```dart
// lib/core/router/app_router.dart
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
```

```dart
// lib/core/router/app_redirect.dart
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
  // ...
}
```

`safeNext` keeps a value only when it starts with one `/`, has no scheme or host, and is not the sign-in page. A
new gate (onboarding, update required, a role) is a new named parameter of `appRedirect` and a new row in its
table test.

```dart
// lib/core/router/main_shell.dart
  // Tapping the open tab again goes back to its first page; another tab opens where the user left it.
  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
```

```dart
// lib/core/common/widgets/root_back_handler.dart
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: widget.child,
    );
```

```dart
// test/core/router/app_redirect_test.dart
    test('a next that leaves the app or loops is ignored', () {
      const unsafe = [
        'https://evil.example.com',
        '//evil.example.com/orders',
        'orders',
        '/sign-in',
        'mailto:a@example.com',
      ];
```

## Traps

- go_router 18 hands a system back to the open tab's own navigator first, then to the root: the `PopScope` in
  `MainShell` runs only at a tab root, so pushed pages still pop as usual.
- In a widget test, the system back is `tester.binding.handlePopRoute()`, then `tester.pump()`.
- A redirect that returns the location it is already on loops. Return `null` to stay.
- Without `refreshListenable`, a sign-out leaves the user on the page they were on until they navigate.
- `context.go` goes to a place (a tab, the page after sign-in) and rebuilds the stack from the routes;
  `context.push` adds a page the user comes back from.
- A path parameter from a deep link can be anything: validate it in the page's controller, and show the "not
  found" state for an id the server does not know.
- Hiding a button is not a permission: the backend checks every call again (F7).
