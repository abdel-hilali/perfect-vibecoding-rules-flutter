# Recipe: controllers over ChangeNotifier

## Problem

A screen whose data lives in `setState` cannot be tested without pumping it, and every widget fetches its own
copy. An answer that arrives after the screen closed throws "used after being disposed"; a slow first load that
answers after a fast refresh puts old rows back on screen.

## Rule

- Screen state lives in a controller: a `ChangeNotifier` in `presentation/controllers/`, with read-only getters
  (`isLoading`, `failure`, the data) and methods for actions. It calls use cases, never a data source (F3).
- The route creates the controller from the feature module and serves it with `NotifierProvider<T>`; the page
  reads it. `NotifierProvider.of<T>(context)` listens; `NotifierProvider.read<T>(context)` does not (callbacks,
  `initState`).
- Every controller guards `notifyListeners()` with a `_disposed` flag, and drops stale answers with a generation
  counter.
- The first load starts in `initState`, after the first frame. Never a load from `build()`.
- App-wide state (the session, the theme choice, the language) lives in controllers created once by their module.
- No bloc, no Riverpod, no get_it, no `setState` for data that comes from a repository.

## Code

```dart
// lib/features/orders/orders_routes.dart
      builder: (context, state) {
        return NotifierProvider<OrdersController>(
          create: OrdersModule.instance.createOrdersController,
          child: const OrdersPage(),
        );
      },
```

```dart
// lib/features/orders/presentation/controllers/orders_controller.dart
  /// The first page; also the refresh. Returns the failure, if any, so a pull to refresh can say why it failed.
  Future<Failure?> load() async {
    final generation = ++_generation;
    _isLoading = true;
    // A "load more" still running belongs to the old list: its answer will be dropped.
    _isLoadingMore = false;
    _failure = null;
    _notify();
    final result = await _getOrders();
    if (_isStale(generation)) {
      return null;
    }
    _isLoading = false;
    switch (result) {
      case Success(:final value):
        _orders = value.items;
        _nextCursor = value.nextCursor;
        _hasLoaded = true;
        _moreFailure = null;
      case FailureResult(:final failure):
        _failure = failure;
    }
    _notify();
    return _failure;
  }
  // ...
  bool _isStale(int generation) => _disposed || generation != _generation;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
```

```dart
// lib/features/orders/presentation/pages/orders_page.dart
  @override
  void initState() {
    super.initState();
    // The first load starts after the first frame, never from build(): build runs again on every rebuild (F3).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(NotifierProvider.read<OrdersController>(context).load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = NotifierProvider.of<OrdersController>(context);
```

An app-wide controller outlives the page that shows it:

```dart
// lib/features/settings/settings_routes.dart
        // App-wide: App reads the same controller for the theme and the locale, so the page must not dispose it.
        return NotifierProvider<SettingsController>(
          create: () => SettingsModule.instance.settingsController,
          autoDispose: false,
          child: const SettingsPage(),
        );
```

`loadMore()` reads the current generation without raising it, so a refresh that starts meanwhile makes the page
it fetches stale, and it is dropped. `SettingsController` raises the generation on every user choice, so a saved
value that arrives late never overwrites the choice just made.

## Traps

- Notifying a disposed `ChangeNotifier` throws. Every `await` in a controller is a point where the screen may have
  closed: check `_disposed` (or `_isStale`) right after it.
- `of` in `initState` or in a callback throws or rebuilds for nothing; `read` in `build` never rebuilds. `of` in
  `build`, `read` everywhere else.
- A load called from `build()` runs on every rebuild: each answer notifies, which rebuilds, which loads again.
- A notify while the tree builds throws ("setState() or markNeedsBuild() called during build"). Start work from a
  post-frame callback, as `initState` and the list footer do.
- After an `await` in a widget, check `mounted` (or `context.mounted`) before you use the context (F15).
- An app-wide controller served without `autoDispose: false` dies with its page, and the App then reads a disposed
  object. Create it in its module, never in a route.
- Tests build controllers by hand with fakes (`OrdersController(GetOrders(FakeOrdersRepository()))`); they never
  reach into a module (tests.md).
