import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The typed configuration, read once in main() (F13).
///
/// Everything here ships inside the app and can be read by anyone who has the APK: public values only. A missing
/// or malformed required key stops the app at start with a message that names the key, instead of a null deep in
/// a screen later.
final class Env {
  const Env({required this.apiBaseUrl, required this.appVersion});

  /// Pure, so a test checks the rules without the asset bundle. A `--dart-define` value wins over the file.
  factory Env.fromValues(
    Map<String, String> file, {
    Map<String, String> defines = const {},
  }) {
    String read(String key) {
      final defined = defines[key] ?? '';
      final value = defined.isNotEmpty ? defined : (file[key] ?? '').trim();
      if (value.isEmpty) {
        throw StateError(
          '$key is missing: add it to $assetPath (see assets/.env.example) or pass --dart-define=$key=...',
        );
      }
      return value;
    }

    final baseUrl = Uri.tryParse(read('API_BASE_URL'));
    // HTTPS only (F6): Android blocks cleartext traffic and iOS keeps App Transport Security on.
    if (baseUrl == null || baseUrl.scheme != 'https' || baseUrl.host.isEmpty) {
      throw StateError(
        'API_BASE_URL must be an https URL, such as https://api.example.com',
      );
    }
    return Env(apiBaseUrl: baseUrl, appVersion: read('APP_VERSION'));
  }

  static const assetPath = 'assets/.env';

  final Uri apiBaseUrl;

  /// Sent as X-App-Version, so the backend can ask an old build to update.
  final String appVersion;

  static Env? _current;

  /// The configuration loaded by [load]. Reading it before is a programming error.
  static Env get current {
    final env = _current;
    if (env == null) {
      throw StateError(
        'Env.load() must run in main() before Env.current is read.',
      );
    }
    return env;
  }

  static Future<Env> load() async {
    await dotenv.load(fileName: assetPath);
    final env = Env.fromValues(dotenv.env, defines: _defines);
    _current = env;
    return env;
  }

  // String.fromEnvironment needs a constant name, so each key is listed once here.
  static const Map<String, String> _defines = {
    'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
    'APP_VERSION': String.fromEnvironment('APP_VERSION'),
  };
}
