import 'package:kit_app/core/common/data/paged.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';

/// The orders, as the domain sees them (F2): typed results, no transport, no JSON.
abstract interface class OrdersRepository {
  /// The first page when [cursor] is null, else the page after it. Never throws.
  Future<Result<Paged<Order>>> getOrders({String? cursor});
}
