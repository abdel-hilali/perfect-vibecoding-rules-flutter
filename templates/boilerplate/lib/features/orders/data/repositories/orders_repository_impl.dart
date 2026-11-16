import 'package:flutter/foundation.dart';
import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/core/common/data/paged.dart';
import 'package:kit_app/core/errors/api_exception.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:kit_app/features/orders/data/models/order_model.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/domain/entities/orders_failures.dart';
import 'package:kit_app/features/orders/domain/repositories/orders_repository.dart';

/// Orders over a remote data source (F5): parses each row, and turns every error into a typed Failure in one
/// `_guard`, so nothing above it ever sees an exception.
class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl(this._remote);

  final OrdersRemoteDataSource _remote;

  static const pageSize = 20;

  @override
  Future<Result<Paged<Order>>> getOrders({String? cursor}) {
    return _guard(() async {
      final page = await _remote.fetchOrders(cursor: cursor, limit: pageSize);
      return Paged<Order>(
        items: _parseRows(listOf(page, 'items')),
        nextCursor: stringOrNull(page, 'next_cursor'),
      );
    });
  }

  // A bad row is skipped and logged in debug builds: one broken order must not hide the nineteen good ones.
  static List<Order> _parseRows(List<Object?> rows) {
    final orders = <Order>[];
    for (final row in rows) {
      try {
        orders.add(OrderModel.fromJson(asJsonMap(row, 'order')));
      } on FormatException catch (e) {
        if (kDebugMode) {
          debugPrint('Skipped a bad order row: ${e.message}');
        }
      }
    }
    return orders;
  }

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
}
