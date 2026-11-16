import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/entities/app_settings.dart';
import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';

/// The device's settings store, as the domain sees it. Never throws.
abstract interface class SettingsRepository {
  Future<Result<AppSettings>> load();

  Future<Result<void>> saveTheme(ThemeChoice choice);

  Future<Result<void>> saveLanguage(String? languageCode);
}
