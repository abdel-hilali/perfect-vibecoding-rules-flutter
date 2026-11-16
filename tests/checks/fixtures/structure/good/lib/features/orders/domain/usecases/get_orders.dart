import '../entities/order.dart';
import '../repositories/orders_repository.dart';

class GetOrders {
  const GetOrders(this._repository);

  final OrdersRepository _repository;

  Future<List<Order>> call() => _repository.getOrders();
}
