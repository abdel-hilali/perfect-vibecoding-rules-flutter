# Recipe: the one API client (dio)

## Problem

dio created in three places means three sets of headers, timeouts and token handling. Five calls that fail with
401 together send five refreshes, and a backend that rotates refresh tokens accepts only the first: the user is
signed out for nothing. A retry after a lost answer creates the order twice.

## Rule

- ONE `ApiClient` over dio (`lib/core/network/api_client.dart`), built once by `SessionModule`. Base URL from `Env`;
  timeouts connect 15 s, send 15 s, receive 20 s; uploads and downloads also get a total time budget (F6).
- Interceptors in this order: auth header, envelope unwrap, unauthorized (ONE shared refresh, one retry per call,
  never on `/auth/` paths, then sign-out), debug log (debug builds only, never headers or bodies).
- Headers on every call: `X-App-Version`, `X-Platform`, `X-Device-Id`; an `Idempotency-Key` on every create.
- Only data sources know a path. They throw `ApiException` and nothing else (errors.md).
- Lists are paginated by the server's cursor; "is there more" comes from the server, never from a row count.

## Code

```dart
// lib/core/network/api_client.dart
    // The order matters: the token goes on first, the envelope comes off before the 401 check retries a call,
    // and the log sees what really went out.
    _dio.interceptors.addAll([
      AuthInterceptor(readAccessToken),
      const ResponseUnwrapInterceptor(),
      UnauthorizedInterceptor(
        dio: _dio,
        readAccessToken: readAccessToken,
        refresh: () => refreshAccessToken(_dio),
        onUnauthorized: onUnauthorized,
      ),
      if (kDebugMode) const DebugLogInterceptor(),
    ]);
  // ...
  // Every call asks dio for Object? and checks the type here, so a surprising body becomes an ApiException that
  // the repository maps, never a TypeError thrown from inside dio.
  Future<T> _send<T>(Future<Response<Object?>> Function() call) async {
    final Response<Object?> response;
    try {
      response = await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    final data = response.data;
    if (data is T) {
      return data;
    }
    throw ApiException.badPayload(
      statusCode: response.statusCode,
      expected: '$T',
    );
  }
```

The shared refresh: every 401 that arrives while a refresh runs waits for that same future.

```dart
// lib/core/network/unauthorized_interceptor.dart
  Future<String?> _sharedRefresh() {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    final started = _refreshSafely();
    _inFlight = started;
    // Cleared only once it settles, and only if it is still the current one, so a refresh that fails at once
    // cannot leave a finished future behind for every later 401.
    unawaited(
      started.whenComplete(() {
        if (identical(_inFlight, started)) {
          _inFlight = null;
        }
      }),
    );
    return started;
  }
```

A data source is the only place with a path:

```dart
// lib/features/orders/data/datasources/http_orders_remote_datasource.dart
  static const ordersPath = '/orders';

  @override
  Future<JsonMap> fetchOrders({String? cursor, required int limit}) {
    return _client.get<JsonMap>(
      ordersPath,
      query: {'limit': limit, 'cursor': ?cursor},
    );
  }
```

A create passes `idempotencyKey:` to `_client.create`, and the caller keeps the key while it retries the same values
(forms.md). Without a backend yet, `FakeOrdersRemoteDataSource` answers the same JSON shapes with a little latency
and cursor pages; `OrdersModule` swaps it for the http one in one line (di.md).

## Traps

- dio casts `Response<T>.data` after the interceptors: a wrong `T` is a `TypeError` from inside dio, not a
  `DioException`. Ask for `Object?` and check the type, as `_send` does.
- dio 5.11 has a `transformTimeout` type: an exhaustive switch on `DioExceptionType` must name it.
- An async refresh that throws before its first `await` runs its `finally` before `_inFlight ??=` stores the
  future: every later 401 then gets a dead answer and signs out. Clear the shared future by identity, once it settles.
- dio sends a `FormData` only once. A retried upload (after a 401) must send `form.clone()`, or the retry fails with
  "The FormData has already been finalized".
- dio's receive timeout is the longest pause between two chunks: a slow but steady upload never trips it. Long
  transfers run under `_withBudget` (a cancel token and a timer); a cancel then maps to `TimeoutFailure`.
- Never refresh on `/auth/` paths: a wrong password is a 401 too, and refreshing there loops.
- Write `'cursor': ?cursor` (a null-aware map element), not `if (cursor != null)`: the lints ask for it.
- Start independent reads together (`Future.wait`), debounce a search box (about 350 ms), HTTPS only.
