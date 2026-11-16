import '../../domain/entities/order.dart';

class OrderModel extends Order {
  const OrderModel({required super.id});

  factory OrderModel.fromJson(Map<String, Object?> json) => OrderModel(id: json['id'] as int? ?? 0);
}
