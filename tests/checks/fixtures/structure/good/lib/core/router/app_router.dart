import 'package:go_router/go_router.dart';

import '../../features/members/members_routes.dart';
import '../../features/orders/orders_routes.dart';

final appRouter = GoRouter(routes: [...ordersRoutes(), ...membersRoutes()]);
