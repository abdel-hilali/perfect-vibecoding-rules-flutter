import 'dart:async';

import 'package:kit_app/core/common/data/paged.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/domain/entities/order_status.dart';
import 'package:kit_app/features/orders/domain/repositories/orders_repository.dart';

/// A hand-written OrdersRepository (F17): no mocking library. Each call waits until the test answers it, so a
/// test can hold the loading state, or answer two calls out of order.
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

/// An order with the values the backend sends (compare FakeOrdersRemoteDataSource).
Order testOrder(int number, {OrderStatus status = OrderStatus.paid}) {
  return Order(
    id: 'ord_$number',
    number: '$number',
    status: status,
    totalMinor: 4250,
    currency: 'EUR',
    itemCount: 3,
    createdAt: DateTime.utc(2026, 3, 14, 9, 30),
  );
}

/// A successful page of [numbers]; [next] is the server's cursor, null on the last page.
Result<Paged<Order>> pageOf(List<int> numbers, {String? next}) {
  return Success(
    Paged<Order>(
      items: [for (final number in numbers) testOrder(number)],
      nextCursor: next,
    ),
  );
}
