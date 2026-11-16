import 'package:go_router/go_router.dart';

import '../../core/config/injection-modules/orders_module.dart';
import 'presentation/pages/orders_page.dart';

List<RouteBase> ordersRoutes() => [
  GoRoute(
    path: OrdersPage.path,
    builder: (context, state) => OrdersPage(controller: OrdersModule.instance.createOrdersController()),
  ),
];
