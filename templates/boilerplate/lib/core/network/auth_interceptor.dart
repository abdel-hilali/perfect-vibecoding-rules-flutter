import 'package:dio/dio.dart';

/// Puts the current access token on every call. It reads the token on each call, never once at start, so a call
/// sent after a refresh carries the new one.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._readAccessToken);

  final Future<String?> Function() _readAccessToken;

  static const header = 'Authorization';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readAccessToken();
    if (token != null) {
      options.headers[header] = 'Bearer $token';
    }
    handler.next(options);
  }
}
