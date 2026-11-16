# Recipe: dependency injection, one module per feature

## Problem

Concrete classes created all over the code make the switch from a fake data source to the real backend a hunt
through many files, and tests end up calling the network. A service locator hides who needs what until a screen
crashes at run time.

## Rule

- `lib/core/config/injection-modules/<feature>_module.dart`: a singleton (`OrdersModule.instance`) that builds the
  feature's objects. Shared objects are `late final` (created once, on first use); per-screen controllers come
  from `createX()` factories (F4).
- The module is the only place that names a concrete class (`FakeOrdersRemoteDataSource`,
  `HttpOrdersRemoteDataSource`). Swapping the fake for the real data source is one line in the module.
- App-wide objects (the session, the one `ApiClient`) live in `SessionModule`; app-wide controllers (the settings)
  in their feature's module, created once.
- Tests build controllers and repositories by hand with fakes. They never reach into a module's singletons.
- No get_it, no service locator.

## Code

```dart
// lib/core/config/injection-modules/orders_module.dart
class OrdersModule {
  OrdersModule._();

  static final OrdersModule instance = OrdersModule._();

  // The one line to change when the backend serves /orders:
  //   late final OrdersRemoteDataSource remote = HttpOrdersRemoteDataSource(SessionModule.instance.apiClient);
  late final OrdersRemoteDataSource remote = FakeOrdersRemoteDataSource();
  late final OrdersRepository repository = OrdersRepositoryImpl(remote);
  late final GetOrders getOrders = GetOrders(repository);

  /// One controller per screen: the route creates it, NotifierProvider disposes it with the page.
  OrdersController createOrdersController() => OrdersController(getOrders);
}
```

```dart
// lib/core/config/injection-modules/session_module.dart
  late final SecureStore secureStore = SecureStore();
  late final AppPreferences preferences = AppPreferences();
  late final Session session = Session(secureStore);
  late final TokenRefresher _refresher = TokenRefresher(session);
  // ...
  /// Runs once in main(), before runApp, so the first frame already knows who is signed in.
  Future<void> start() async {
    _deviceId = await preferences.deviceId();
    await session.restore();
    if (useFakeAccount && !session.isSignedIn) {
      await session.signIn(SessionTokens.fakeAccount);
    }
  }
```

```dart
// lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fails here, with the key's name, when assets/.env misses a required value (F13).
  await Env.load();
  // Edge to edge on every Android version (F9); from Android 15 the system forces it anyway.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final session = SessionModule.instance;
  final settings = SettingsModule.instance.settingsController;
  // Independent reads start together (F6), and both finish before the first frame: the app opens in the saved
  // theme and language, already signed in or out, with no flash.
  await Future.wait([session.start(), settings.load()]);
  runApp(
    App(
      router: buildAppRouter(session: session.session),
      settings: settings,
    ),
  );
}
```

A new feature copies this shape: `<feature>_module.dart` with its data source, repository, use cases and a
`createX()` per screen; its route calls `createX` (state.md). `SessionModule.useFakeAccount` keeps the starter
signed in with a local account until the auth feature lands; set it to false then.

## Traps

- A per-screen controller held in a `late final` is disposed with its first page, then served again to the next
  one: "used after being disposed". Per-screen objects come from `createX()`.
- `late final` builds on first use. A module read before `Env.load()` fails with "Env.load() must run in main()";
  `apiClient` read before `start()` fails because the device id is not read yet. Keep `main()` in this order.
- A shared object with state (the session, a cache) has ONE owner module. Others read it from there
  (`SessionModule.instance.session`), never build a second one.
- Two modules whose `late final` fields read each other recurse until the stack overflows. Shared objects go down
  into `SessionModule`, never sideways between features.
- A test that touches `OrdersModule.instance` shares its state with every later test in the run. Build by hand.
