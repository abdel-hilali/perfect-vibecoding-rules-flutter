import 'package:go_router/go_router.dart';
import 'package:kit_app/core/common/widgets/notifier_provider.dart';
import 'package:kit_app/core/config/injection-modules/orders_module.dart';
import 'package:kit_app/features/orders/presentation/controllers/orders_controller.dart';
import 'package:kit_app/features/orders/presentation/pages/orders_page.dart';

/// The routes of the orders feature; app_router.dart only assembles them (F7).
///
/// The route builds the controller from the module and serves it; the page reads it (F3). In the tab shell the
/// page stays alive while another tab is open, so the controller and the scroll position survive a tab change.
List<RouteBase> ordersRoutes() {
  return [
    GoRoute(
      path: OrdersPage.path,
      name: OrdersPage.name,
      builder: (context, state) {
        return NotifierProvider<OrdersController>(
          create: OrdersModule.instance.createOrdersController,
          child: const OrdersPage(),
        );
      },
    ),
  ];
}
