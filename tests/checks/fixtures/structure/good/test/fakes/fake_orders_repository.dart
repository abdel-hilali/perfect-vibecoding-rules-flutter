import 'package:shop/features/orders/domain/entities/order.dart';
import 'package:shop/features/orders/domain/repositories/orders_repository.dart';

class FakeOrdersRepository implements OrdersRepository {
  @override
  Future<List<Order>> getOrders() async => const [];
}
