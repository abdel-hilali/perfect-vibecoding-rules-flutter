import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/core/network/api_client.dart';
import 'package:kit_app/features/orders/data/datasources/orders_remote_datasource.dart';

/// The real orders endpoint, over the one ApiClient. Only this class knows the path (F6).
class HttpOrdersRemoteDataSource implements OrdersRemoteDataSource {
  const HttpOrdersRemoteDataSource(this._client);

  final ApiClient _client;

  static const ordersPath = '/orders';

  @override
  Future<JsonMap> fetchOrders({String? cursor, required int limit}) {
    return _client.get<JsonMap>(
      ordersPath,
      query: {'limit': limit, 'cursor': ?cursor},
    );
  }
}
