import 'package:kit_app/core/storage/secure_store.dart';

/// A keystore in memory (F17): the session reads, writes and deletes through the same three calls, and no test
/// touches the computer's own keystore.
class FakeSecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> write(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async => values.remove(key) != null;
}
