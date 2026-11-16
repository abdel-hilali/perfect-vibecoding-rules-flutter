import '../../../features/orders/data/datasources/http_orders_remote_datasource.dart';
import '../../../features/orders/data/repositories/orders_repository_impl.dart';
import '../../../features/orders/domain/usecases/get_orders.dart';
import '../../../features/orders/presentation/controllers/orders_controller.dart';

// The module is the one place that names concrete classes (F4): core may import every layer.
class OrdersModule {
  OrdersModule._();

  static final instance = OrdersModule._();

  late final _repository = OrdersRepositoryImpl(HttpOrdersRemoteDataSource());

  OrdersController createOrdersController() => OrdersController(GetOrders(_repository));
}
