import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/domain/entities/orders_failures.dart';
import 'package:kit_app/features/orders/domain/usecases/get_orders.dart';
import 'package:kit_app/features/orders/presentation/controllers/orders_controller.dart';

import '../../../../fakes/fake_orders_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late FakeOrdersRepository repository;
  late OrdersController controller;

  setUp(() {
    repository = FakeOrdersRepository();
    controller = OrdersController(GetOrders(repository));
  });

  List<String> numbers() => [
    for (final order in controller.orders) order.number,
  ];

  test('loading: busy, no rows, nothing loaded yet', () {
    unawaited(controller.load());
    expect(controller.isLoading, isTrue);
    expect(controller.hasLoaded, isFalse);
    expect(controller.orders, isEmpty);
  });

  test('data: the first page, and the server says there is more', () async {
    final loading = controller.load();
    repository.answer(0, pageOf([1042, 1041], next: 'c_2'));
    expect(await loading, isNull);
    expect(controller.isLoading, isFalse);
    expect(controller.hasLoaded, isTrue);
    expect(numbers(), ['1042', '1041']);
    expect(controller.hasMore, isTrue);
  });

  test('failure: kept, with no rows, and returned to the caller', () async {
    final loading = controller.load();
    repository.answer(0, const FailureResult(NetworkFailure()));
    expect(await loading, isA<NetworkFailure>());
    expect(controller.failure, isA<NetworkFailure>());
    expect(controller.orders, isEmpty);
  });

  test('a failed refresh keeps the rows on screen', () async {
    final first = controller.load();
    repository.answer(0, pageOf([3, 2, 1]));
    await first;
    final refresh = controller.load();
    repository.answer(1, const FailureResult(TimeoutFailure()));
    expect(await refresh, isA<TimeoutFailure>());
    expect(numbers(), ['3', '2', '1']);
  });

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

  test('load more appends the next page with the server cursor', () async {
    final loading = controller.load();
    repository.answer(0, pageOf([3, 2], next: 'c_2'));
    await loading;
    final more = controller.loadMore();
    expect(controller.isLoadingMore, isTrue);
    expect(repository.cursors.last, 'c_2');
    repository.answer(1, pageOf([1]));
    await more;
    expect(numbers(), ['3', '2', '1']);
    expect(controller.hasMore, isFalse);
  });

  test('a refresh during load more drops the stale page', () async {
    final loading = controller.load();
    repository.answer(0, pageOf([3, 2], next: 'c_2'));
    await loading;
    final more = controller.loadMore();
    final refresh = controller.load();
    repository.answer(2, pageOf([9, 8]));
    await refresh;
    repository.answer(1, pageOf([1]));
    await more;
    expect(numbers(), ['9', '8']);
    expect(controller.isLoadingMore, isFalse);
  });

  test('a failed load more keeps the rows and says why', () async {
    final loading = controller.load();
    repository.answer(0, pageOf([3, 2], next: 'c_2'));
    await loading;
    final more = controller.loadMore();
    repository.answer(1, const FailureResult(ServerFailure()));
    await more;
    expect(numbers(), ['3', '2']);
    expect(controller.moreFailure, isA<ServerFailure>());
    expect(controller.failure, isNull);
  });

  test(
    'never notifies after dispose: a late answer to a closed screen is ignored',
    () async {
      var notified = 0;
      controller.addListener(() => notified++);
      final loading = controller.load();
      expect(notified, 1);
      controller.dispose();
      repository.answer(0, pageOf([1]));
      // A notify here would throw "used after being disposed".
      await loading;
      expect(notified, 1);
    },
  );

  test(
    "the feature's failure has its own text, the core ones the common text",
    () {
      expect(
        controller.messageFor(const OrdersDisabledFailure(), l10nEn),
        l10nEn.ordersErrorDisabled,
      );
      expect(
        controller.messageFor(const TimeoutFailure(), l10nEn),
        l10nEn.commonErrorTimeout,
      );
    },
  );
}
