import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kit_app/core/errors/failures.dart';

/// The kinds of trouble a call can meet before the app decides what it means.
enum ApiErrorKind { network, timeout, http, badPayload, unknown }

/// The only error that crosses the data layer (F5): data sources throw it (the ApiClient builds it from dio), and
/// the repository's one `_guard` turns it into a typed Failure.
class ApiException implements Exception {
  const ApiException(
    this.kind, {
    this.statusCode,
    this.code,
    this.message = '',
  });

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => ApiException(
        ApiErrorKind.timeout,
        message: e.type.name,
      ),
      // The client cancels a call only when its total time budget runs out (ApiClient.upload).
      DioExceptionType.cancel => const ApiException(
        ApiErrorKind.timeout,
        message: 'time budget',
      ),
      DioExceptionType.connectionError || DioExceptionType.badCertificate =>
        ApiException(ApiErrorKind.network, message: e.type.name),
      DioExceptionType.badResponse => ApiException(
        ApiErrorKind.http,
        statusCode: status,
        code: _errorCode(e.response?.data),
        message: 'HTTP $status',
      ),
      DioExceptionType.unknown => ApiException(
        e.error is IOException ? ApiErrorKind.network : ApiErrorKind.unknown,
        message: '${e.error.runtimeType}',
      ),
    };
  }

  /// The server answered 2xx with a body the app cannot read.
  factory ApiException.badPayload({int? statusCode, String expected = ''}) {
    return ApiException(
      ApiErrorKind.badPayload,
      statusCode: statusCode,
      message: 'expected $expected',
    );
  }

  final ApiErrorKind kind;
  final int? statusCode;

  /// The backend's error code (`{"error": {"code": "orders_disabled"}}`), to branch on.
  final String? code;

  /// For debug logs only. Never shown to the user, never parsed, never holding a token.
  final String message;

  /// The core meaning of this error. A repository checks its feature's own codes first.
  Failure toFailure() {
    return switch (kind) {
      ApiErrorKind.network => NetworkFailure(code: code),
      ApiErrorKind.timeout => TimeoutFailure(code: code),
      ApiErrorKind.badPayload => ValidationFailure(code: code),
      ApiErrorKind.unknown => UnknownFailure(code: code),
      ApiErrorKind.http => _fromStatus(),
    };
  }

  Failure _fromStatus() {
    return switch (statusCode) {
      401 => UnauthorizedFailure(code: code),
      403 => ForbiddenFailure(code: code),
      404 => NotFoundFailure(code: code),
      409 => ConflictFailure(code: code),
      400 || 422 => ValidationFailure(code: code),
      429 => RateLimitFailure(code: code),
      final int status when status >= 500 => ServerFailure(code: code),
      _ => UnknownFailure(code: code),
    };
  }

  // Reads {"error": {"code": "..."}} or {"code": "..."}; anything else has no code.
  static String? _errorCode(Object? body) {
    if (body is! Map<String, Object?>) {
      return null;
    }
    final error = body['error'];
    final code = error is Map<String, Object?> ? error['code'] : body['code'];
    return code is String ? code : null;
  }

  @override
  String toString() =>
      'ApiException(${kind.name}, status: $statusCode, code: $code, $message)';
}
