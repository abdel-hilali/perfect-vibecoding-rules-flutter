# Recipe: typed errors (ApiException, Failure, Result)

## Problem

A repository that returns `null` on failure cannot say why, so the screen shows "no orders" when the network is
down. A `catch (_) {}` hides the bug for weeks, a branch on an error message breaks when the backend rewords it, and
one bad row in a list of twenty crashes the whole screen with a `TypeError`.

## Rule

- Data sources throw `ApiException` (built by `ApiException.fromDio`): the kind, the HTTP status, the backend's
  error `code`, a debug-only message. Nothing else crosses the data layer (F5).
- Repositories catch it in ONE private `_guard` and return a sealed `Result<T>`: `Success(value)` or
  `FailureResult(failure)`. A repository never throws to the presentation layer.
- `core/errors/failures.dart` holds the sealed `Failure` kinds; a feature's own failures extend one of them.
- Branch on the failure type or the backend's `code`, never on a message. The controller turns a failure into the
  catalog's text; the user never sees a stack trace, a URL or the server's own words.
- Models parse with typed readers (`stringOf`, `intOf`, `dateOf`, `listOf`): a bad field is a `FormatException`,
  so a bad row is skipped and logged in debug, never a crash and never silence.

## Code

```dart
// lib/core/usecases/result.dart
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;
}
```

```dart
// lib/features/orders/data/repositories/orders_repository_impl.dart
  // The ONE place where this repository's errors become failures. A programming error (a TypeError, a
  // StateError) is not caught: it must stay loud.
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on ApiException catch (e) {
      return FailureResult(_toFailure(e));
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint('Orders page unreadable: ${e.message}');
      }
      return FailureResult<T>(const ValidationFailure());
    }
  }

  // This feature's own codes first, then the core meaning of the error (F5: branch on the code, never a message).
  static Failure _toFailure(ApiException e) {
    return switch (e.code) {
      OrdersDisabledFailure.backendCode => const OrdersDisabledFailure(),
      _ => e.toFailure(),
    };
  }
```

```dart
// lib/features/orders/domain/entities/orders_failures.dart
class OrdersDisabledFailure extends ForbiddenFailure {
  const OrdersDisabledFailure() : super(code: backendCode);

  static const backendCode = 'orders_disabled';
}
```

```dart
// lib/features/orders/data/models/order_model.dart
  factory OrderModel.fromJson(JsonMap json) {
    return OrderModel(
      id: stringOf(json, 'id'),
      number: stringOf(json, 'number'),
      status: statusFromJson(stringOrNull(json, 'status')),
      totalMinor: intOf(json, 'total_cents'),
      // ...
    );
  }
```

The text for each core kind sits in one switch, which the compiler keeps complete:

```dart
// lib/core/l10n/failure_messages.dart
extension FailureMessages on AppLocalizations {
  String failureMessage(Failure failure) {
    return switch (failure) {
      NetworkFailure() => commonErrorNetwork,
      TimeoutFailure() => commonErrorTimeout,
      // ...
      UnknownFailure() => commonErrorUnknown,
    };
  }
}
```

```dart
// lib/features/orders/presentation/controllers/orders_controller.dart
  String messageFor(Failure failure, AppLocalizations l10n) {
    return failure is OrdersDisabledFailure
        ? l10n.ordersErrorDisabled
        : l10n.failureMessage(failure);
  }
```

`ApiException.toFailure()` maps the status: 401 `UnauthorizedFailure`, 403 `ForbiddenFailure`, 404
`NotFoundFailure`, 409 `ConflictFailure`, 400 and 422 `ValidationFailure`, 429 `RateLimitFailure`, 5xx
`ServerFailure`; no connection `NetworkFailure`, a timeout or a spent budget `TimeoutFailure`.

## Traps

- Inside a generic `_guard<T>`, `const FailureResult(...)` does not compile (`T` is not a constant type): write
  `FailureResult<T>(const ValidationFailure())`.
- `_guard` catches `ApiException` and `FormatException` only. Catching everything turns a programming error into a
  polite "try again" that nobody ever fixes.
- A feature failure extends a core kind (`OrdersDisabledFailure extends ForbiddenFailure`): code that knows only
  the core kinds still treats it as "not allowed", and the sealed switch still covers it.
- A status the backend adds tomorrow is not a bad row: `statusFromJson` maps an unknown value to
  `OrderStatus.unknown`. Only a missing required field skips the row.
- Some backends send `12.0` for 12: `intOf` accepts a whole double; `12.5` is still an error.
- The analyzer runs with strict casts: read JSON with the typed readers, never `json['id'] as String`.
- A 422 often names the field: map that code to the field's problem, under the field (forms.md), not a toast.
