import 'package:go_router/go_router.dart';

import 'presentation/pages/members_page.dart';

List<RouteBase> membersRoutes() => [GoRoute(path: MembersPage.path, builder: (context, state) => const MembersPage())];
