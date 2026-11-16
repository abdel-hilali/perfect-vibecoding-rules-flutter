import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';
import 'package:kit_app/features/settings/domain/usecases/load_settings.dart';
import 'package:kit_app/features/settings/domain/usecases/save_language.dart';
import 'package:kit_app/features/settings/domain/usecases/save_theme_choice.dart';
import 'package:material_ui/material_ui.dart';

/// The app-wide settings (F3, F8, F11): the theme choice and the language.
///
/// SettingsModule creates it once. App listens to it for `themeMode` and `locale`, so a change repaints the whole
/// app at once; the settings page changes it. A choice applies at once and is saved after.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this._loadSettings,
    required this._saveThemeChoice,
    required this._saveLanguage,
  });

  final LoadSettings _loadSettings;
  final SaveThemeChoice _saveThemeChoice;
  final SaveLanguage _saveLanguage;

  ThemeChoice _themeChoice = ThemeChoice.system;
  String? _languageCode;
  Failure? _failure;
  bool _disposed = false;
  int _generation = 0;

  ThemeChoice get themeChoice => _themeChoice;

  /// null follows the phone.
  String? get languageCode => _languageCode;

  /// Why the last read or save failed. The choice on screen still applies for this run.
  Failure? get failure => _failure;

  ThemeMode get themeMode {
    return switch (_themeChoice) {
      ThemeChoice.system => ThemeMode.system,
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
    };
  }

  /// null lets MaterialApp pick the phone's language among the supported ones.
  Locale? get locale {
    final code = _languageCode;
    return code == null ? null : Locale(code);
  }

  Future<void> load() async {
    final generation = ++_generation;
    final result = await _loadSettings();
    // A choice the user made while the saved one was being read wins over it.
    if (_disposed || generation != _generation) {
      return;
    }
    switch (result) {
      case Success(:final value):
        _themeChoice = value.theme;
        _languageCode = value.languageCode;
        _failure = null;
      case FailureResult(:final failure):
        _failure = failure;
    }
    _notify();
  }

  /// Returns the failure when the choice could not be saved, so the page can say so.
  Future<Failure?> setThemeChoice(ThemeChoice choice) async {
    _generation++;
    _themeChoice = choice;
    _failure = null;
    _notify();
    return _keepFailure(await _saveThemeChoice(choice));
  }

  /// null follows the phone's language again.
  Future<Failure?> setLanguage(String? languageCode) async {
    _generation++;
    _languageCode = languageCode;
    _failure = null;
    _notify();
    return _keepFailure(await _saveLanguage(languageCode));
  }

  Failure? _keepFailure(Result<void> result) {
    if (result case FailureResult(:final failure)) {
      _failure = failure;
      _notify();
      return failure;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
