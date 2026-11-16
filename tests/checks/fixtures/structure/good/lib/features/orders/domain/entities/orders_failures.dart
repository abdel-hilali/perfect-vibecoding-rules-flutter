import '../../../../core/usecases/result.dart';

// A feature's own failure (F5); the domain may import lib/core/.
class OrdersEmptyFailure {
  const OrdersEmptyFailure();

  Result<void> get asResult => const FailureResult(OrdersEmptyFailure());
}
