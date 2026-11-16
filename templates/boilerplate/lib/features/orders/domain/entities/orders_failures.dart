import 'package:kit_app/core/errors/failures.dart';

/// The backend turned orders off for this account (error code `orders_disabled`).
///
/// It extends ForbiddenFailure, so code that only knows the core kinds still treats it as "not allowed"; the
/// orders screen shows its own, clearer text.
class OrdersDisabledFailure extends ForbiddenFailure {
  const OrdersDisabledFailure() : super(code: backendCode);

  static const backendCode = 'orders_disabled';
}
