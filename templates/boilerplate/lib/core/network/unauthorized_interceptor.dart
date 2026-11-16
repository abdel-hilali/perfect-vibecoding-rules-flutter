import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kit_app/core/network/auth_interceptor.dart';

/// On a 401: ONE token refresh shared by every call that failed at the same time, one retry per call, never on
/// `/auth/` paths, then sign-out (F6).
///
/// Without the shared refresh, five calls that fail together send five refreshes, and a backend that rotates
/// refresh tokens accepts only the first: the other four sign the user out.
class UnauthorizedInterceptor extends Interceptor {
  // Private named parameters: callers pass `dio:`, `refresh:` and so on, and the fields stay private.
  UnauthorizedInterceptor({
    required this._dio,
    required this._readAccessToken,
    required this._refresh,
    required this._onUnauthorized,
  });

  final Dio _dio;
  final Future<String?> Function() _readAccessToken;
  final Future<String?> Function() _refresh;
  final Future<void> Function() _onUnauthorized;
  Future<String?>? _inFlight;

  /// Sign-in, sign-up and refresh answer 401 for a wrong password or an expired refresh token: refreshing there
  /// would loop.
  static const authPathPrefix = '/auth/';
  static const _retriedKey = 'kit.retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.path.startsWith(authPathPrefix)) {
      return handler.next(err);
    }
    if (request.extra[_retriedKey] == true) {
      await _onUnauthorized();
      return handler.next(err);
    }
    final token = await _freshToken(request);
    if (token == null) {
      await _onUnauthorized();
      return handler.next(err);
    }
    request.headers[AuthInterceptor.header] = 'Bearer $token';
    request.extra[_retriedKey] = true;
    // dio sends a FormData only once: the retry of an upload sends a fresh copy of it.
    final body = request.data;
    if (body is FormData) {
      request.data = body.clone();
    }
    try {
      handler.resolve(await _dio.fetch<Object?>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  // A call sent with an old token may fail after another call already refreshed: it retries with the current
  // token instead of starting a second refresh.
  Future<String?> _freshToken(RequestOptions request) async {
    final current = await _readAccessToken();
    if (current != null &&
        request.headers[AuthInterceptor.header] != 'Bearer $current') {
      return current;
    }
    return _sharedRefresh();
  }

  Future<String?> _sharedRefresh() {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    final started = _refreshSafely();
    _inFlight = started;
    // Cleared only once it settles, and only if it is still the current one, so a refresh that fails at once
    // cannot leave a finished future behind for every later 401.
    unawaited(
      started.whenComplete(() {
        if (identical(_inFlight, started)) {
          _inFlight = null;
        }
      }),
    );
    return started;
  }

  Future<String?> _refreshSafely() async {
    try {
      return await _refresh();
    } on Exception catch (e) {
      // A refresh that fails for any reason ends the session; the caller signs out. Never the error's text: it
      // may hold a token.
      if (kDebugMode) {
        debugPrint('Token refresh failed: ${e.runtimeType}');
      }
      return null;
    }
  }
}
