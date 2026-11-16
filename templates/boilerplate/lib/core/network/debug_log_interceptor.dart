import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug builds only (ApiClient adds it behind kDebugMode). It prints the method, the path and the status, never
/// a header, a query or a body: they carry tokens and personal data (F13).
class DebugLogInterceptor extends Interceptor {
  const DebugLogInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('-> ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    debugPrint('<- ${response.statusCode} ${request.method} ${request.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    debugPrint(
      'xx ${err.response?.statusCode ?? err.type.name} ${request.method} ${request.path}',
    );
    handler.next(err);
  }
}
