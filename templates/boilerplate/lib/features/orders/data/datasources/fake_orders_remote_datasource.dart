import 'dart:math' as math;

import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/core/errors/api_exception.dart';
import 'package:kit_app/features/orders/data/datasources/orders_remote_datasource.dart';

/// The orders endpoint, on the phone (F4, F17): the same JSON shapes the backend sends, a little latency, and
/// cursor pages, so every state of the screen can be seen without a server. Before you trust a fake, compare it
/// with a real answer: a fake that invents shapes hides real bugs.
class FakeOrdersRemoteDataSource implements OrdersRemoteDataSource {
  FakeOrdersRemoteDataSource({
    this.latency = const Duration(milliseconds: 400),
    this.total = 23,
  });

  /// Tests pass Duration.zero.
  final Duration latency;

  /// How many orders the fake account has; 0 shows the empty state.
  final int total;

  static const _statuses = ['pending', 'paid', 'shipped', 'cancelled'];

  @override
  Future<JsonMap> fetchOrders({String? cursor, required int limit}) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final start = cursor == null ? 0 : _offsetOf(cursor);
    final end = math.min(start + limit, total);
    return {
      'items': [for (var i = start; i < end; i++) _order(i)],
      'next_cursor': end < total ? 'c_$end' : null,
    };
  }

  // The backend answers 400 with this code for a cursor it did not issue.
  static int _offsetOf(String cursor) {
    final offset = cursor.startsWith('c_')
        ? int.tryParse(cursor.substring(2))
        : null;
    if (offset == null || offset < 0) {
      throw const ApiException(
        ApiErrorKind.http,
        statusCode: 400,
        code: 'invalid_cursor',
      );
    }
    return offset;
  }

  static JsonMap _order(int index) {
    final number = 1042 - index;
    return {
      'id': 'ord_$number',
      'number': '$number',
      'status': _statuses[index % _statuses.length],
      'total_cents': 1250 + (index * 734) % 9000,
      'currency': 'EUR',
      'item_count': 1 + index % 4,
      'created_at': DateTime.utc(
        2026,
        3,
        14,
        9,
        30,
      ).subtract(Duration(hours: 7 * index)).toIso8601String(),
    };
  }
}
