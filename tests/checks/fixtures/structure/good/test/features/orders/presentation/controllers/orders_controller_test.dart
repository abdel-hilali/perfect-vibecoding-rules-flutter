import 'package:flutter_test/flutter_test.dart';
import 'package:shop/features/orders/domain/usecases/get_orders.dart';
import 'package:shop/features/orders/presentation/controllers/orders_controller.dart';

import '../../../../fakes/fake_orders_repository.dart';

// main() is longer than the function limit: a test file's main() only registers its tests.
void main() {
  group('OrdersController', () {
    test('case 0', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 1', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 2', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 3', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 4', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 5', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 6', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 7', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 8', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 9', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 10', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 11', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 12', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 13', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 14', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
    test('case 15', () => expect(OrdersController(GetOrders(FakeOrdersRepository())).orders, isEmpty));
  });
}
