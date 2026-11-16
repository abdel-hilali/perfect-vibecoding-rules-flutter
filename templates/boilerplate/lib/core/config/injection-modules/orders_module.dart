import 'package:kit_app/features/orders/data/datasources/fake_orders_remote_datasource.dart';
import 'package:kit_app/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:kit_app/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:kit_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:kit_app/features/orders/domain/usecases/get_orders.dart';
import 'package:kit_app/features/orders/presentation/controllers/orders_controller.dart';

/// Builds the orders feature (F4). The only place that names a concrete data source.
class OrdersModule {
  OrdersModule._();

  static final OrdersModule instance = OrdersModule._();

  // The one line to change when the backend serves /orders:
  //   late final OrdersRemoteDataSource remote = HttpOrdersRemoteDataSource(SessionModule.instance.apiClient);
  late final OrdersRemoteDataSource remote = FakeOrdersRemoteDataSource();
  late final OrdersRepository repository = OrdersRepositoryImpl(remote);
  late final GetOrders getOrders = GetOrders(repository);

  /// One controller per screen: the route creates it, NotifierProvider disposes it with the page.
  OrdersController createOrdersController() => OrdersController(getOrders);
}
