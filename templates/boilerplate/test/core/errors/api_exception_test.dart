import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/errors/api_exception.dart';
import 'package:kit_app/core/errors/failures.dart';

DioException dioError(DioExceptionType type, {int? status, Object? body}) {
  final request = RequestOptions(path: '/orders');
  return DioException(
    requestOptions: request,
    type: type,
    response: status == null
        ? null
        : Response<Object?>(
            requestOptions: request,
            statusCode: status,
            data: body,
          ),
  );
}

void main() {
  group('ApiException.fromDio', () {
    test('the three timeouts and a spent time budget are timeouts', () {
      const types = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.cancel,
      ];
      for (final type in types) {
        expect(
          ApiException.fromDio(dioError(type)).kind,
          ApiErrorKind.timeout,
          reason: type.name,
        );
      }
    });

    test('no connection is a network error', () {
      expect(
        ApiException.fromDio(dioError(DioExceptionType.connectionError)).kind,
        ApiErrorKind.network,
      );
    });

    test('a bad response keeps the status and the backend code', () {
      final e = ApiException.fromDio(
        dioError(
          DioExceptionType.badResponse,
          status: 403,
          body: {
            'error': {'code': 'orders_disabled', 'message': 'internal text'},
          },
        ),
      );
      expect(e.kind, ApiErrorKind.http);
      expect(e.statusCode, 403);
      expect(e.code, 'orders_disabled');
      // The server's own text never travels: it is not for the user (F5).
      expect(e.message, isNot(contains('internal text')));
    });

    test('a body without an error object has no code', () {
      final e = ApiException.fromDio(
        dioError(DioExceptionType.badResponse, status: 500, body: 'oops'),
      );
      expect(e.code, isNull);
    });
  });

  group('toFailure', () {
    final byStatus = <int, Matcher>{
      400: isA<ValidationFailure>(),
      401: isA<UnauthorizedFailure>(),
      403: isA<ForbiddenFailure>(),
      404: isA<NotFoundFailure>(),
      409: isA<ConflictFailure>(),
      422: isA<ValidationFailure>(),
      429: isA<RateLimitFailure>(),
      500: isA<ServerFailure>(),
      503: isA<ServerFailure>(),
      418: isA<UnknownFailure>(),
    };
    for (final MapEntry(key: status, value: matcher) in byStatus.entries) {
      test('HTTP $status', () {
        expect(
          ApiException(ApiErrorKind.http, statusCode: status).toFailure(),
          matcher,
        );
      });
    }

    test('the backend code reaches the failure, to branch on', () {
      const e = ApiException(
        ApiErrorKind.http,
        statusCode: 429,
        code: 'too_many_orders',
      );
      expect(e.toFailure().code, 'too_many_orders');
    });
  });
}
