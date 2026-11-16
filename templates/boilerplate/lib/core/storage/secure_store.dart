import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one door to the keystore (F14). It never throws.
///
/// A broken keystore (a backup restored to a new phone, a changed lock screen) makes the plugin throw on read.
/// Here that reads as "nothing saved", which the app treats as signed out, instead of a crash at every start.
class SecureStore {
  SecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception catch (e) {
      _log('read', key, e);
      return null;
    }
  }

  /// false when the keystore refused the value: the caller keeps it in memory for this run only.
  Future<bool> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } on Exception catch (e) {
      _log('write', key, e);
      return false;
    }
  }

  Future<bool> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } on Exception catch (e) {
      _log('delete', key, e);
      return false;
    }
  }

  static void _log(String action, String key, Object error) {
    // The key and the error type only: never the value, it may be a token.
    if (kDebugMode) {
      debugPrint('SecureStore.$action($key) failed: ${error.runtimeType}');
    }
  }
}
