import 'package:kit_app/core/common/data/paged.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/domain/repositories/orders_repository.dart';

/// One action per file (F2): read one page of orders. Controllers call this, never the repository's source.
class GetOrders {
  const GetOrders(this._repository);

  final OrdersRepository _repository;

  Future<Result<Paged<Order>>> call({String? cursor}) =>
      _repository.getOrders(cursor: cursor);
}
