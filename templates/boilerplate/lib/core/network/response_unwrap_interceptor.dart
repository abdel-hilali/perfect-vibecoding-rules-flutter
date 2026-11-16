import 'package:dio/dio.dart';

/// The backend wraps every answer as `{"data": ...}`. This hands the inside to the data sources, so each one parses
/// its own payload and no data source repeats the envelope.
class ResponseUnwrapInterceptor extends Interceptor {
  const ResponseUnwrapInterceptor();

  static const envelopeKey = 'data';

  // Response<dynamic> is dio's own signature: this is the JSON edge, the one place untyped bodies are allowed.
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (body is Map<String, Object?> && body.containsKey(envelopeKey)) {
      response.data = body[envelopeKey];
    }
    handler.next(response);
  }
}
