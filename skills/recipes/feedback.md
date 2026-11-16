# Recipe: the four states, toasts, sheets and dialogs

## Problem

A screen that shows a spinner forever on a network error, or "no orders" while it is still loading, makes users
retry, reinstall and leave. A `ScaffoldMessenger` call in every page shows toasts in five styles, and a context
used after an `await` crashes when the page has closed.

## Rule

- Every data screen shows four states: loading, empty (an `EmptyState` that says what to do), error (an
  `ErrorState` with a retry) and the data. Its widget tests cover all four (F12, F17).
- ONE way to give feedback: `showAppToast`, over the one messenger mounted by `MaterialApp`. Never a raw
  `ScaffoldMessenger` call or a hand-built `AlertDialog` in a page.
- Sheets open through `showAppSheet`; confirmations through `showConfirmDialog` (true only on confirm).
- The text comes from the catalog; a failure's text comes from the controller (`messageFor`), never the server.

## Code

```dart
// lib/features/orders/presentation/pages/orders_page.dart
    final controller = NotifierProvider.of<OrdersController>(context);
    final l10n = context.l10n;
    final failure = controller.failure;
    final Widget body;
    if (controller.orders.isNotEmpty) {
      body = OrdersList(controller: controller, onRefresh: _refresh);
    } else if (failure != null) {
      body = ErrorState(
        message: controller.messageFor(failure, l10n),
        onRetry: () => unawaited(controller.load()),
      );
    } else if (controller.hasLoaded && !controller.isLoading) {
      body = EmptyState(
        title: l10n.ordersEmptyTitle,
        message: l10n.ordersEmptyBody,
      );
    } else {
      body = const LoadingState();
    }
```

Rows on screen win over an error: a failed refresh keeps them and says why in a toast.

```dart
// lib/core/common/widgets/show_app_toast.dart
/// The ScaffoldMessenger of the app, mounted once: MaterialApp.router(scaffoldMessengerKey: appMessengerKey).
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
// ...
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
```

```dart
// lib/core/common/widgets/show_app_sheet.dart
  return showModalBottomSheet<T>(
    context: context,
    // Above the tab shell: from a tab, the nearest navigator is the tab's own, and the sheet would end on top of
    // the bottom bar, which stays live under it.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.of(context, AppMotion.sheet),
      reverseDuration: AppMotion.of(context, AppMotion.normal),
    ),
    builder: (sheetContext) => _AppSheet(builder: builder),
  );
```

The list's footer asks for the next page when it is built, so a first page that fits the screen still loads more:

```dart
// lib/features/orders/presentation/widgets/orders_list.dart
            // A new key for every new list, so the footer of the next page asks again when it comes into view.
            return _LoadMoreFooter(
              key: ObjectKey(orders),
              failed: controller.moreFailure != null,
              onLoadMore: () => unawaited(controller.loadMore()),
            );
```

## Traps

- A spinning `CircularProgressIndicator` never settles: a test that shows `LoadingState` uses `pump()`; a
  `pumpAndSettle()` times out.
- A `SnackBar` shows only inside a `Scaffold`. A toast test needs one, and lets the toast's timer run out at the
  end (`pumpAndSettle(const Duration(seconds: 4))`), or the test fails on a pending timer.
- "Empty" needs `hasLoaded`: before the first answer, no rows means "still loading", not "nothing there".
- Pull to refresh on a short list needs `AlwaysScrollableScrollPhysics`, or the list cannot be pulled.
- `showAppToast` needs no context, so it is safe after an `await`; read the text from the catalog before the
  `await`, or check `mounted` first.
- `showDialog` opens on the root navigator, above the bottom bar. `showModalBottomSheet` opens on the nearest one:
  from a tab, the sheet ends on top of the bottom bar, which stays live under it. So `showAppSheet` must pass
  `useRootNavigator: true`.
- A tall sheet scrolls its own content (`isScrollControlled: true`); the keyboard padding is already in
  `showAppSheet`.
