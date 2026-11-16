import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/core/errors/api_exception.dart';
import 'package:kit_app/core/network/api_client.dart';

/// A server on the test's side: dio sends every call here instead of the network.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Answers 200 to the token 'new', 401 to anything else.
ResponseBody acceptNewToken(RequestOptions options) {
  return options.headers['Authorization'] == 'Bearer new'
      ? jsonBody(200, {
          'data': {'ok': true},
        })
      : jsonBody(401, {
          'error': {'code': 'token_expired'},
        });
}

void main() {
  late String token;
  late int refreshes;
  late int signOuts;
  late FakeAdapter adapter;

  ApiClient client(Future<String?> Function() refresh) {
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      headers: const {},
      dio: dio,
      readAccessToken: () async => token,
      refreshAccessToken: (_) => refresh(),
      onUnauthorized: () async => signOuts++,
    );
  }

  Future<String?> goodRefresh() async {
    refreshes++;
    // Lets the other failing calls arrive while this refresh runs.
    await Future<void>.delayed(Duration.zero);
    token = 'new';
    return token;
  }

  setUp(() {
    token = 'old';
    refreshes = 0;
    signOuts = 0;
    adapter = FakeAdapter(acceptNewToken);
  });

  test(
    'three calls that fail together share ONE refresh, then each retries once',
    () async {
      final api = client(goodRefresh);
      final answers = await Future.wait([
        for (var i = 0; i < 3; i++) api.get<JsonMap>('/orders'),
      ]);
      expect(answers, everyElement({'ok': true}));
      expect(refreshes, 1);
      expect(signOuts, 0);
    },
  );

  test('a call sent with the old token after another call refreshed retries at once, no second refresh', () async {
    adapter = FakeAdapter((options) {
      if (options.headers['Authorization'] == 'Bearer old') {
        // While this call is on the wire, another call's refresh lands.
        token = 'new';
        return jsonBody(401, const <String, Object?>{});
      }
      return acceptNewToken(options);
    });
    final api = client(goodRefresh);
    expect(await api.get<JsonMap>('/orders'), {'ok': true});
    expect(refreshes, 0);
  });

  test('a refused refresh signs out and the call fails with 401', () async {
    final api = client(() async {
      refreshes++;
      return null;
    });
    await expectLater(
      api.get<JsonMap>('/orders'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(signOuts, 1);
  });

  test('never refreshes on /auth/ paths: a wrong password is not an expired session', () async {
    final api = client(goodRefresh);
    await expectLater(
      api.get<JsonMap>('/auth/sign-in'),
      throwsA(isA<ApiException>()),
    );
    expect(refreshes, 0);
    expect(signOuts, 0);
  });

  // Regression: a refresh that failed before its first await once left a finished future behind, and every
  // later 401 signed the user out without trying again.
  test('a refresh that throws at once does not stick: the next 401 refreshes again', () async {
    var fail = true;
    final api = client(() {
      if (fail) {
        refreshes++;
        throw const ApiException(ApiErrorKind.network);
      }
      return goodRefresh();
    });
    await expectLater(
      api.get<JsonMap>('/orders'),
      throwsA(isA<ApiException>()),
    );
    expect(signOuts, 1);
    fail = false;
    expect(await api.get<JsonMap>('/orders'), {'ok': true});
    expect(refreshes, 2);
  });

  // Regression: dio sends a FormData only once, so the retry of an upload that met a 401 once failed with an
  // unknown error, after a good refresh.
  test('an upload that meets a 401 is sent again after the refresh', () async {
    final api = client(goodRefresh);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(Uint8List(8), filename: 'photo.jpg'),
    });
    final answer = await api.upload<JsonMap>('/orders/ord_1/photo', form: form);
    expect(answer, {'ok': true});
    expect(adapter.paths, ['/orders/ord_1/photo', '/orders/ord_1/photo']);
    expect(refreshes, 1);
  });

  test(
    'the envelope is unwrapped and a surprising body becomes a bad payload',
    () async {
      adapter = FakeAdapter((_) => jsonBody(200, {'data': 'not an object'}));
      final api = client(goodRefresh);
      await expectLater(
        api.get<JsonMap>('/orders'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.badPayload,
          ),
        ),
      );
    },
  );
}
