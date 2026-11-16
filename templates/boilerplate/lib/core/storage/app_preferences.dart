import 'package:flutter/foundation.dart';
import 'package:kit_app/core/common/data/random_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plain, non-secret settings on the device (F14): the theme choice, the language, the device id. Tokens never go
/// here: they go to SecureStore.
///
/// The async API reads the platform store on each call, so a value written by a background isolate is never
/// hidden behind a stale in-memory cache.
class AppPreferences {
  AppPreferences([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _themeKey = 'settings.theme';
  static const _languageKey = 'settings.language';
  static const _deviceIdKey = 'device.id';

  Future<String?> themeChoice() => _prefs.getString(_themeKey);

  Future<void> setThemeChoice(String value) =>
      _prefs.setString(_themeKey, value);

  /// null means "follow the phone".
  Future<String?> languageCode() => _prefs.getString(_languageKey);

  Future<void> setLanguageCode(String? value) {
    return value == null
        ? _prefs.remove(_languageKey)
        : _prefs.setString(_languageKey, value);
  }

  /// A random id made on first start and kept until the app is uninstalled, sent as X-Device-Id. It is not a
  /// secret and says nothing about the user.
  Future<String> deviceId() async {
    try {
      final saved = await _prefs.getString(_deviceIdKey);
      if (saved != null && saved.isNotEmpty) {
        return saved;
      }
      final id = randomId();
      await _prefs.setString(_deviceIdKey, id);
      return id;
    } on Exception catch (e) {
      // A header is not worth a crash at start: this run gets a fresh id, the next start tries to save again.
      if (kDebugMode) {
        debugPrint('AppPreferences.deviceId failed: ${e.runtimeType}');
      }
      return randomId();
    }
  }
}
