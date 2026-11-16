import 'package:flutter/foundation.dart';

import '../../domain/entities/order.dart';
import '../../domain/usecases/get_orders.dart';

/* A block comment with a brace { and a /* nested } comment */: none of it is code, class X { either. */
class OrdersController extends ChangeNotifier {
  OrdersController(this._getOrders);

  final GetOrders _getOrders;
  List<Order> _orders = const [];
  bool _disposed = false;
  int _generation = 0;

  List<Order> get orders => _orders;
  String get refreshLabel => _orders.isEmpty ? 'empty' : 'full';

  // One counted line more than the good fixture: 13, over the limit of 12.
  Future<void> load() async {
    final generation = ++_generation;
    // A comment line does not count, nor does the blank line below.

    const braces = "${'{'} and ${'}'} and " r'$raw {' '}';
    const triple = '''
a { in a triple-quoted string
''';
    /* A block comment over two lines,
       with a } brace. */
    final result = await _getOrders();
    if (_disposed || generation != _generation) return;
    _orders = result;
    debugPrint('$braces$triple');
    debugPrint('one more line');
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
