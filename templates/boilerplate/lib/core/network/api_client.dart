import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kit_app/core/errors/api_exception.dart';
import 'package:kit_app/core/network/auth_interceptor.dart';
import 'package:kit_app/core/network/debug_log_interceptor.dart';
import 'package:kit_app/core/network/idempotency_key.dart';
import 'package:kit_app/core/network/response_unwrap_interceptor.dart';
import 'package:kit_app/core/network/unauthorized_interceptor.dart';

/// The one HTTP client of the app (F6), built once by SessionModule.
///
/// Data sources call it with a path. It adds the headers, unwraps the envelope, refreshes the token once for every
/// call that failed together, and turns every error into an ApiException: nothing above the data layer sees dio.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required Map<String, String> headers,
    required Future<String?> Function() readAccessToken,
    required Future<String?> Function(Dio dio) refreshAccessToken,
    required Future<void> Function() onUnauthorized,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl.toString(),
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: headers,
    );
    // The order matters: the token goes on first, the envelope comes off before the 401 check retries a call,
    // and the log sees what really went out.
    _dio.interceptors.addAll([
      AuthInterceptor(readAccessToken),
      const ResponseUnwrapInterceptor(),
      UnauthorizedInterceptor(
        dio: _dio,
        readAccessToken: readAccessToken,
        refresh: () => refreshAccessToken(_dio),
        onUnauthorized: onUnauthorized,
      ),
      if (kDebugMode) const DebugLogInterceptor(),
    ]);
  }

  static const connectTimeout = Duration(seconds: 15);
  static const sendTimeout = Duration(seconds: 15);

  /// dio's receive timeout is the longest pause between two chunks, so it also catches a stalled download.
  static const receiveTimeout = Duration(seconds: 20);

  /// Uploads and downloads: dio's timeouts only watch pauses, so a slow but steady transfer needs a total limit.
  static const transferBudget = Duration(minutes: 2);

  static const appVersionHeader = 'X-App-Version';
  static const platformHeader = 'X-Platform';
  static const deviceIdHeader = 'X-Device-Id';

  final Dio _dio;

  Future<T> get<T>(String path, {Map<String, Object?>? query}) {
    return _send<T>(() => _dio.get<Object?>(path, queryParameters: query));
  }

  /// A create carries an Idempotency-Key, so a retry after a lost answer never creates twice. To retry the same
  /// create, pass the same key again; after a NetworkFailure, read the list again before you retry (F6).
  Future<T> create<T>(
    String path, {
    required Object? body,
    String? idempotencyKey,
  }) {
    final headers = {
      IdempotencyKey.header: idempotencyKey ?? IdempotencyKey.generate(),
    };
    return _send<T>(
      () => _dio.post<Object?>(
        path,
        data: body,
        options: Options(headers: headers),
      ),
    );
  }

  /// A POST that creates nothing (an action, a search).
  Future<T> post<T>(String path, {Object? body}) {
    return _send<T>(() => _dio.post<Object?>(path, data: body));
  }

  Future<T> patch<T>(String path, {required Object? body}) {
    return _send<T>(() => _dio.patch<Object?>(path, data: body));
  }

  Future<T> delete<T>(String path) =>
      _send<T>(() => _dio.delete<Object?>(path));

  /// A file upload, under a total time budget on top of the pause timeouts.
  Future<T> upload<T>(
    String path, {
    required FormData form,
    String? idempotencyKey,
    Duration budget = transferBudget,
    void Function(int sent, int total)? onProgress,
  }) {
    final headers = {
      IdempotencyKey.header: idempotencyKey ?? IdempotencyKey.generate(),
    };
    return _withBudget<T>(budget, (cancel) {
      return _dio.post<Object?>(
        path,
        data: form,
        cancelToken: cancel,
        onSendProgress: onProgress,
        options: Options(headers: headers),
      );
    });
  }

  Future<T> _withBudget<T>(
    Duration budget,
    Future<Response<Object?>> Function(CancelToken cancel) call,
  ) async {
    final cancel = CancelToken();
    final timer = Timer(budget, cancel.cancel);
    try {
      return await _send<T>(() => call(cancel));
    } finally {
      timer.cancel();
    }
  }

  // Every call asks dio for Object? and checks the type here, so a surprising body becomes an ApiException that
  // the repository maps, never a TypeError thrown from inside dio.
  Future<T> _send<T>(Future<Response<Object?>> Function() call) async {
    final Response<Object?> response;
    try {
      response = await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    final data = response.data;
    if (data is T) {
      return data;
    }
    throw ApiException.badPayload(
      statusCode: response.statusCode,
      expected: '$T',
    );
  }
}
