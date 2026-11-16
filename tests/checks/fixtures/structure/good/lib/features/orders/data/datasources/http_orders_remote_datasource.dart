import '../models/order_model.dart';
import 'orders_remote_datasource.dart';

class HttpOrdersRemoteDataSource implements OrdersRemoteDataSource {
  static const _path = '/orders';

  @override
  Future<List<OrderModel>> fetchOrders() async => [OrderModel.fromJson({'id': 1, 'path': _path})];
}
