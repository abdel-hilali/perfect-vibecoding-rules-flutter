import 'package:flutter/foundation.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/storage/app_preferences.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/entities/app_settings.dart';
import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';
import 'package:kit_app/features/settings/domain/repositories/settings_repository.dart';

/// The settings, kept in shared_preferences through AppPreferences (F14).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._preferences);

  final AppPreferences _preferences;

  @override
  Future<Result<AppSettings>> load() {
    return _guard(() async {
      // An unknown saved value (from an older build) falls back to the default instead of failing.
      final theme =
          ThemeChoice.values.asNameMap()[await _preferences.themeChoice()] ??
          ThemeChoice.system;
      return AppSettings(
        theme: theme,
        languageCode: await _preferences.languageCode(),
      );
    });
  }

  @override
  Future<Result<void>> saveTheme(ThemeChoice choice) =>
      _guard(() => _preferences.setThemeChoice(choice.name));

  @override
  Future<Result<void>> saveLanguage(String? languageCode) {
    return _guard(() => _preferences.setLanguageCode(languageCode));
  }

  // The device store can fail (a full disk, a platform channel error): a typed failure, never a crash.
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('Settings store failed: ${e.runtimeType}');
      }
      return FailureResult<T>(const UnknownFailure());
    }
  }
}
