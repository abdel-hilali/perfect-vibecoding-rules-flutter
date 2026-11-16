import 'package:kit_app/features/orders/domain/entities/order_status.dart';

/// An order as the app shows it. Plain Dart: no Flutter, no JSON, no dio (F2).
class Order {
  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.totalMinor,
    required this.currency,
    required this.itemCount,
    required this.createdAt,
  });

  final String id;

  /// The number people say on the phone, such as 1042. Not the id.
  final String number;
  final OrderStatus status;

  /// The total in minor units (cents), so no rounding error ever reaches a sum.
  final int totalMinor;

  /// ISO 4217, such as EUR.
  final String currency;
  final int itemCount;

  /// In UTC, as the server sent it; widgets show it in local time.
  final DateTime createdAt;
}
