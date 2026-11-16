import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/domain/entities/order_status.dart';

/// An order as the backend sends it (F5).
///
/// Every field is read with a typed helper, so a missing or wrong field throws a FormatException that the
/// repository handles (it skips the row), never a TypeError that crashes the list.
class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.number,
    required super.status,
    required super.totalMinor,
    required super.currency,
    required super.itemCount,
    required super.createdAt,
  });

  factory OrderModel.fromJson(JsonMap json) {
    return OrderModel(
      id: stringOf(json, 'id'),
      number: stringOf(json, 'number'),
      status: statusFromJson(stringOrNull(json, 'status')),
      totalMinor: intOf(json, 'total_cents'),
      currency: stringOf(json, 'currency'),
      itemCount: intOf(json, 'item_count'),
      createdAt: dateOf(json, 'created_at'),
    );
  }

  JsonMap toJson() {
    return {
      'id': id,
      'number': number,
      'status': status.name,
      'total_cents': totalMinor,
      'currency': currency,
      'item_count': itemCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// An unknown or missing status is not a bad row: newer backends add statuses.
  static OrderStatus statusFromJson(String? value) {
    return switch (value) {
      'pending' => OrderStatus.pending,
      'paid' => OrderStatus.paid,
      'shipped' => OrderStatus.shipped,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.unknown,
    };
  }
}
