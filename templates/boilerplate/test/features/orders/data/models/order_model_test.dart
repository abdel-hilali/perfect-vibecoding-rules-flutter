import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/features/orders/data/models/order_model.dart';
import 'package:kit_app/features/orders/domain/entities/order_status.dart';

/// One row as the backend sends it (the same shape as FakeOrdersRemoteDataSource).
JsonMap goodRow() {
  return {
    'id': 'ord_1042',
    'number': '1042',
    'status': 'paid',
    'total_cents': 4250,
    'currency': 'EUR',
    'item_count': 3,
    'created_at': '2026-03-14T09:30:00.000Z',
  };
}

void main() {
  test('reads a good row', () {
    final order = OrderModel.fromJson(goodRow());
    expect(order.id, 'ord_1042');
    expect(order.number, '1042');
    expect(order.status, OrderStatus.paid);
    expect(order.totalMinor, 4250);
    expect(order.currency, 'EUR');
    expect(order.itemCount, 3);
    expect(order.createdAt, DateTime.utc(2026, 3, 14, 9, 30));
  });

  test('accepts a whole number sent as 4250.0', () {
    expect(
      OrderModel.fromJson({...goodRow(), 'total_cents': 4250.0}).totalMinor,
      4250,
    );
  });

  test('an unknown or missing status keeps the row', () {
    expect(
      OrderModel.fromJson({...goodRow(), 'status': 'refunded'}).status,
      OrderStatus.unknown,
    );
    expect(
      OrderModel.fromJson(goodRow()..remove('status')).status,
      OrderStatus.unknown,
    );
  });

  test('a missing required field is a FormatException, never a TypeError', () {
    const required = [
      'id',
      'number',
      'total_cents',
      'currency',
      'item_count',
      'created_at',
    ];
    for (final key in required) {
      expect(
        () => OrderModel.fromJson(goodRow()..remove(key)),
        throwsFormatException,
        reason: key,
      );
    }
  });

  test('a field of the wrong type is a FormatException', () {
    final bad = <String, Object?>{
      'total_cents': '4250',
      'item_count': 2.5,
      'created_at': 'yesterday',
      'id': 42,
    };
    for (final MapEntry(:key, :value) in bad.entries) {
      expect(
        () => OrderModel.fromJson({...goodRow(), key: value}),
        throwsFormatException,
        reason: key,
      );
    }
  });

  test('toJson writes the shape fromJson reads', () {
    final order = OrderModel.fromJson(goodRow());
    expect(OrderModel.fromJson(order.toJson()).toJson(), order.toJson());
  });
}
