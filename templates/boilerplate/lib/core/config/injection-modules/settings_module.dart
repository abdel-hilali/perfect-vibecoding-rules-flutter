import 'package:kit_app/core/storage/app_preferences.dart';
import 'package:kit_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:kit_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:kit_app/features/settings/domain/usecases/load_settings.dart';
import 'package:kit_app/features/settings/domain/usecases/save_language.dart';
import 'package:kit_app/features/settings/domain/usecases/save_theme_choice.dart';
import 'package:kit_app/features/settings/presentation/controllers/settings_controller.dart';

/// Builds the settings feature (F4).
class SettingsModule {
  SettingsModule._();

  static final SettingsModule instance = SettingsModule._();

  late final AppPreferences preferences = AppPreferences();
  late final SettingsRepository repository = SettingsRepositoryImpl(
    preferences,
  );

  /// App-wide, never disposed: App reads it for the theme and the locale, the settings page changes it.
  late final SettingsController settingsController = SettingsController(
    loadSettings: LoadSettings(repository),
    saveThemeChoice: SaveThemeChoice(repository),
    saveLanguage: SaveLanguage(repository),
  );
}
