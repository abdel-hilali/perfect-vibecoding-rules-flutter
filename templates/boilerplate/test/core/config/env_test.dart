import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/config/env.dart';

void main() {
  const file = {
    'API_BASE_URL': 'https://api.example.com',
    'APP_VERSION': '1.0.0',
  };

  test('reads every key from the file', () {
    final env = Env.fromValues(file);
    expect(env.apiBaseUrl, Uri.parse('https://api.example.com'));
    expect(env.appVersion, '1.0.0');
  });

  test('a --dart-define value wins over the file', () {
    final env = Env.fromValues(
      file,
      defines: const {'APP_VERSION': '2.0.0', 'API_BASE_URL': ''},
    );
    expect(env.appVersion, '2.0.0');
    expect(env.apiBaseUrl.host, 'api.example.com');
  });

  test('a missing key stops the start and names the key', () {
    expect(
      () => Env.fromValues(const {'APP_VERSION': '1.0.0'}),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('API_BASE_URL'),
        ),
      ),
    );
  });

  test('a base URL without HTTPS is refused', () {
    expect(
      () => Env.fromValues(const {
        'API_BASE_URL': 'http://api.example.com',
        'APP_VERSION': '1.0.0',
      }),
      throwsStateError,
    );
  });
}
