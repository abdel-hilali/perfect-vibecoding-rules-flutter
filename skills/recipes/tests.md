# Recipe: unit and widget tests

## Problem

A page that passes on an 800x600 test window overflows on a 320 dp phone with large text. A mock that returns
shapes the backend never sends hid a real bug for weeks. A suite bigger than the code costs every agent tokens and
minutes, and a test that waits on a spinner or a toast timer hangs or flakes.

## Rule

- `test/` mirrors `lib/`. Fakes are hand-written classes that `implements` the real interface, with the shapes the
  real backend sends. No mockito, no mocktail (F17).
- Unit tests: controllers (loading, data, each failure, a stale answer dropped), repositories over fake data
  sources, models (a good row, a bad row), `appRedirect` (one table test of every gate), `systemOverlayFor`.
- Widget tests: each page's four states at 320x640 with text scale 1.3, light and dark in one loop.
- The test budget: a test earns its place only by a bug it would catch. Many inputs are one table test. Never test
  generated code, constants, plain getters or Flutter itself. Search `test/` before you add (`grep -rn`). The tests
  stay smaller than the code.
- Every bug fix gets a regression test that fails without the fix.
- While working, run the touched test files only (`scripts/tools/q-test.sh <files>`); the whole suite runs once,
  in the gate.

## Code

```dart
// test/helpers/pump_app.dart
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
  // ...
```

`pumpPage` then pumps a `MaterialApp` with both themes, the catalogs and the toast's messenger key, and
`l10nEn` (same file) gives tests the English catalog.

```dart
// test/fakes/fake_orders_repository.dart
class FakeOrdersRepository implements OrdersRepository {
  final List<Completer<Result<Paged<Order>>>> _calls = [];

  /// The cursor of every call, in order.
  final List<String?> cursors = [];

  int get callCount => _calls.length;

  @override
  Future<Result<Paged<Order>>> getOrders({String? cursor}) {
    cursors.add(cursor);
    final call = Completer<Result<Paged<Order>>>();
    _calls.add(call);
    return call.future;
  }

  /// Answers call number [index], 0 being the first.
  void answer(int index, Result<Paged<Order>> result) =>
      _calls[index].complete(result);
}
```

Each call waits until the test answers it, so a test holds the loading state, or answers two calls out of order:

```dart
// test/features/orders/presentation/controllers/orders_controller_test.dart
  test('a stale answer is dropped: the newer load wins', () async {
    final older = controller.load();
    final newer = controller.load();
    // The newer call answers first, then the older one, slow, arrives.
    repository.answer(1, pageOf([2]));
    await newer;
    repository.answer(0, pageOf([1]));
    await older;
    expect(numbers(), ['2']);
  });
```

```dart
// test/features/orders/presentation/pages/orders_page_test.dart
  for (final dark in [false, true]) {
    group(
      'OrdersPage, ${dark ? 'dark' : 'light'}, 320x640, text scale 1.3',
      () {
        testWidgets('loading', (tester) async {
          final repository = await pumpOrdersPage(tester, dark: dark);
          expect(repository.callCount, 1);
          expect(find.byType(LoadingState), findsOneWidget);
        });
```

The network is faked one level lower: `test/core/network/unauthorized_interceptor_test.dart` gives dio a
`FakeAdapter implements HttpClientAdapter` that answers each request, so the real `ApiClient` and its interceptors
run with no server.

## Traps

- The test font draws every glyph one em wide: at 320 dp and text scale 1.3 far fewer rows fit than on a phone.
  Assert on the first rows, never on a row count.
- A spinning `CircularProgressIndicator` never settles: use `pump()`; `pumpAndSettle()` times out.
- A toast leaves a timer: end the test with `pumpAndSettle(const Duration(seconds: 4))`.
- A test that changes `tester.view` or the text scale resets it in `addTearDown`, as `pumpPage` does, so no other
  test inherits a small window.
- The system back button is `tester.binding.handlePopRoute()`, then `tester.pump()`.
- A test that touches a module's singleton shares state with every later test: build objects by hand.
- `shared_preferences` in a test needs its in-memory platform (storage-env.md).
- A fake that "fixes" a shape the backend really sends wrong hides the bug: copy a real answer into the fake.
