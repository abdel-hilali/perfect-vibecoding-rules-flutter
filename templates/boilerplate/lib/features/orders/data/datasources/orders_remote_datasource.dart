import 'package:kit_app/core/common/data/json_fields.dart';

/// The orders endpoint, as raw JSON (F6). Two implementations answer with the same shapes:
/// HttpOrdersRemoteDataSource (the backend) and FakeOrdersRemoteDataSource (on the phone, no server). Both throw
/// ApiException and nothing else.
abstract interface class OrdersRemoteDataSource {
  /// One page, already out of the `{"data": ...}` envelope:
  /// `{"items": [order, ...], "next_cursor": "c_20"}`, with `next_cursor` null on the last page.
  Future<JsonMap> fetchOrders({String? cursor, required int limit});
}
