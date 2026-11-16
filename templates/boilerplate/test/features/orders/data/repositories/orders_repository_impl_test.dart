import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/core/common/data/paged.dart';
import 'package:kit_app/core/errors/api_exception.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/data/datasources/fake_orders_remote_datasource.dart';
import 'package:kit_app/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:kit_app/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/domain/entities/orders_failures.dart';

/// A data source that fails the way the real one can: it throws an ApiException.
class ThrowingRemote implements OrdersRemoteDataSource {
  ThrowingRemote(this.error);

  final ApiException error;

  @override
  Future<JsonMap> fetchOrders({String? cursor, required int limit}) async =>
      throw error;
}

/// A data source that answers one fixed page.
class CannedRemote implements OrdersRemoteDataSource {
  CannedRemote(this.page);

  final JsonMap page;

  @override
  Future<JsonMap> fetchOrders({String? cursor, required int limit}) async =>
      page;
}

Paged<Order> pageFrom(Result<Paged<Order>> result) {
  return switch (result) {
    Success(:final value) => value,
    FailureResult(:final failure) => fail('expected a page, got $failure'),
  };
}

Failure failureFrom(Result<Paged<Order>> result) {
  return switch (result) {
    Success() => fail('expected a failure, got a page'),
    FailureResult(:final failure) => failure,
  };
}

JsonMap row(String id) {
  return {
    'id': id,
    'number': id.substring(4),
    'status': 'paid',
    'total_cents': 4250,
    'currency': 'EUR',
    'item_count': 3,
    'created_at': '2026-03-14T09:30:00.000Z',
  };
}

void main() {
  group('over the fake data source', () {
    final repository = OrdersRepositoryImpl(
      FakeOrdersRemoteDataSource(latency: Duration.zero),
    );

    test('pages through every order with the server cursor', () async {
      final first = pageFrom(await repository.getOrders());
      expect(first.items, hasLength(OrdersRepositoryImpl.pageSize));
      expect(first.hasMore, isTrue);
      final second = pageFrom(
        await repository.getOrders(cursor: first.nextCursor),
      );
      expect(second.items, hasLength(3));
      expect(second.hasMore, isFalse);
      expect({
        ...first.items.map((o) => o.id),
        ...second.items.map((o) => o.id),
      }, hasLength(23));
    });

    test('an account without orders is an empty page, not a failure', () async {
      final empty = OrdersRepositoryImpl(
        FakeOrdersRemoteDataSource(latency: Duration.zero, total: 0),
      );
      expect(pageFrom(await empty.getOrders()).items, isEmpty);
    });

    test('a cursor the server never issued is a validation failure', () async {
      expect(
        failureFrom(await repository.getOrders(cursor: 'bogus')),
        isA<ValidationFailure>(),
      );
    });
  });

  test('a bad row is skipped and the good ones stay', () async {
    final broken = {...row('ord_1'), 'total_cents': 'a lot'};
    final repository = OrdersRepositoryImpl(
      CannedRemote({
        'items': [row('ord_2'), broken, 'not an object', row('ord_3')],
        'next_cursor': null,
      }),
    );
    expect(pageFrom(await repository.getOrders()).items.map((o) => o.id), [
      'ord_2',
      'ord_3',
    ]);
  });

  test('a page without its items list is a validation failure', () async {
    final repository = OrdersRepositoryImpl(
      CannedRemote({'orders': <Object?>[]}),
    );
    expect(failureFrom(await repository.getOrders()), isA<ValidationFailure>());
  });

  group('every error becomes a typed failure', () {
    final cases = <String, (ApiException, Matcher)>{
      'no connection': (
        const ApiException(ApiErrorKind.network),
        isA<NetworkFailure>(),
      ),
      'timeout': (
        const ApiException(ApiErrorKind.timeout),
        isA<TimeoutFailure>(),
      ),
      '401': (
        const ApiException(ApiErrorKind.http, statusCode: 401),
        isA<UnauthorizedFailure>(),
      ),
      '403': (
        const ApiException(ApiErrorKind.http, statusCode: 403),
        isA<ForbiddenFailure>(),
      ),
      '404': (
        const ApiException(ApiErrorKind.http, statusCode: 404),
        isA<NotFoundFailure>(),
      ),
      '409': (
        const ApiException(ApiErrorKind.http, statusCode: 409),
        isA<ConflictFailure>(),
      ),
      '422': (
        const ApiException(ApiErrorKind.http, statusCode: 422),
        isA<ValidationFailure>(),
      ),
      '429': (
        const ApiException(ApiErrorKind.http, statusCode: 429),
        isA<RateLimitFailure>(),
      ),
      '500': (
        const ApiException(ApiErrorKind.http, statusCode: 500),
        isA<ServerFailure>(),
      ),
      'bad payload': (
        ApiException.badPayload(statusCode: 200),
        isA<ValidationFailure>(),
      ),
      'unknown': (
        const ApiException(ApiErrorKind.unknown),
        isA<UnknownFailure>(),
      ),
    };
    for (final MapEntry(key: name, value: (error, matcher)) in cases.entries) {
      test(name, () async {
        final result = await OrdersRepositoryImpl(ThrowingRemote(error))
            .getOrders();
        expect(failureFrom(result), matcher);
      });
    }

    test("this feature's own code wins over the status", () async {
      const error = ApiException(
        ApiErrorKind.http,
        statusCode: 403,
        code: OrdersDisabledFailure.backendCode,
      );
      final failure = failureFrom(
        await OrdersRepositoryImpl(ThrowingRemote(error)).getOrders(),
      );
      expect(failure, isA<OrdersDisabledFailure>());
      // Still a ForbiddenFailure for code that knows only the core kinds.
      expect(failure, isA<ForbiddenFailure>());
    });
  });
}
