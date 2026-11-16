import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/widgets/empty_state.dart';
import 'package:kit_app/core/common/widgets/error_state.dart';
import 'package:kit_app/core/common/widgets/loading_state.dart';
import 'package:kit_app/core/common/widgets/notifier_provider.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/domain/usecases/get_orders.dart';
import 'package:kit_app/features/orders/presentation/controllers/orders_controller.dart';
import 'package:kit_app/features/orders/presentation/pages/orders_page.dart';
import 'package:kit_app/features/orders/presentation/widgets/order_tile.dart';

import '../../../../fakes/fake_orders_repository.dart';
import '../../../../helpers/pump_app.dart';

/// Pumps the page as its route does, and lets the first load start (it runs after the first frame).
Future<FakeOrdersRepository> pumpOrdersPage(
  WidgetTester tester, {
  required bool dark,
}) async {
  final repository = FakeOrdersRepository();
  await pumpPage(
    tester,
    NotifierProvider<OrdersController>(
      create: () => OrdersController(GetOrders(repository)),
      child: const OrdersPage(),
    ),
    dark: dark,
  );
  await tester.pump();
  return repository;
}

void main() {
  for (final dark in [false, true]) {
    group(
      'OrdersPage, ${dark ? 'dark' : 'light'}, 320x640, text scale 1.3',
      () {
        testWidgets('loading', (tester) async {
          final repository = await pumpOrdersPage(tester, dark: dark);
          expect(repository.callCount, 1);
          expect(find.byType(LoadingState), findsOneWidget);
        });

        testWidgets('data', (tester) async {
          final repository = await pumpOrdersPage(tester, dark: dark);
          repository.answer(0, pageOf([1042, 1041, 1040]));
          await tester.pump();
          // The test font draws every glyph one em wide, so at 320 dp only the first rows fit on screen: assert on
          // what shows, and let the overflow check do the rest.
          expect(find.byType(OrderTile), findsWidgets);
          expect(find.text(l10nEn.ordersNumber('1042')), findsOneWidget);
          expect(find.text(l10nEn.ordersItemCount(3)), findsWidgets);
        });

        testWidgets(
          'data with more: the end of the list asks for the next page',
          (tester) async {
            final repository = await pumpOrdersPage(tester, dark: dark);
            repository.answer(0, pageOf([1042], next: 'c_1'));
            await tester.pump();
            await tester.pump();
            expect(repository.cursors, [null, 'c_1']);
          },
        );

        testWidgets('empty', (tester) async {
          final repository = await pumpOrdersPage(tester, dark: dark);
          repository.answer(0, pageOf([]));
          await tester.pump();
          expect(find.byType(EmptyState), findsOneWidget);
          expect(find.text(l10nEn.ordersEmptyTitle), findsOneWidget);
        });

        testWidgets('error, and retry loads again', (tester) async {
          final repository = await pumpOrdersPage(tester, dark: dark);
          repository.answer(0, const FailureResult(NetworkFailure()));
          await tester.pump();
          expect(find.byType(ErrorState), findsOneWidget);
          expect(find.text(l10nEn.commonErrorNetwork), findsOneWidget);
          await tester.ensureVisible(find.text(l10nEn.commonRetry));
          await tester.tap(find.text(l10nEn.commonRetry));
          await tester.pump();
          expect(repository.callCount, 2);
          expect(find.byType(LoadingState), findsOneWidget);
        });
      },
    );
  }
}
