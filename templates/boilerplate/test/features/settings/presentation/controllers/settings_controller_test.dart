import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/entities/app_settings.dart';
import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';
import 'package:kit_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:kit_app/features/settings/domain/usecases/load_settings.dart';
import 'package:kit_app/features/settings/domain/usecases/save_language.dart';
import 'package:kit_app/features/settings/domain/usecases/save_theme_choice.dart';
import 'package:kit_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

/// A hand-written settings store (F17): what it saved, and the failures the test asks for.
class FakeSettingsRepository implements SettingsRepository {
  AppSettings saved = const AppSettings();
  Failure? failSaves;

  /// When set, load() waits for it: the test then acts while the saved settings are being read.
  Completer<void>? holdLoad;

  @override
  Future<Result<AppSettings>> load() async {
    await holdLoad?.future;
    return Success(saved);
  }

  @override
  Future<Result<void>> saveTheme(ThemeChoice choice) async {
    final failure = failSaves;
    if (failure != null) {
      return FailureResult(failure);
    }
    saved = AppSettings(theme: choice, languageCode: saved.languageCode);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveLanguage(String? languageCode) async {
    final failure = failSaves;
    if (failure != null) {
      return FailureResult(failure);
    }
    saved = AppSettings(theme: saved.theme, languageCode: languageCode);
    return const Success<void>(null);
  }
}

void main() {
  late FakeSettingsRepository repository;
  late SettingsController controller;

  setUp(() {
    repository = FakeSettingsRepository();
    controller = SettingsController(
      loadSettings: LoadSettings(repository),
      saveThemeChoice: SaveThemeChoice(repository),
      saveLanguage: SaveLanguage(repository),
    );
  });

  test(
    'before anything is saved: the phone decides the theme and the language',
    () async {
      await controller.load();
      expect(controller.themeMode, ThemeMode.system);
      expect(controller.locale, isNull);
    },
  );

  test('load reads the saved theme and language', () async {
    repository.saved = const AppSettings(
      theme: ThemeChoice.dark,
      languageCode: 'fr',
    );
    await controller.load();
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.locale, const Locale('fr'));
  });

  test('a theme choice applies at once, then is saved', () async {
    var notified = 0;
    controller.addListener(() => notified++);
    final saving = controller.setThemeChoice(ThemeChoice.light);
    expect(controller.themeMode, ThemeMode.light);
    expect(notified, 1);
    expect(await saving, isNull);
    expect(repository.saved.theme, ThemeChoice.light);
  });

  test('a failed save keeps the choice for this run and says why', () async {
    repository.failSaves = const UnknownFailure();
    expect(
      await controller.setThemeChoice(ThemeChoice.dark),
      isA<UnknownFailure>(),
    );
    expect(controller.themeChoice, ThemeChoice.dark);
    expect(controller.failure, isA<UnknownFailure>());
  });

  test(
    'a choice made while the saved one is read wins (stale answer dropped)',
    () async {
      repository.saved = const AppSettings(theme: ThemeChoice.dark);
      final hold = Completer<void>();
      repository.holdLoad = hold;
      final loading = controller.load();
      await controller.setThemeChoice(ThemeChoice.light);
      hold.complete();
      await loading;
      expect(controller.themeChoice, ThemeChoice.light);
    },
  );

  test('language null follows the phone again', () async {
    await controller.setLanguage('ar');
    expect(controller.locale, const Locale('ar'));
    await controller.setLanguage(null);
    expect(controller.locale, isNull);
    expect(repository.saved.languageCode, isNull);
  });

  test('never notifies after dispose', () async {
    final hold = Completer<void>();
    repository.holdLoad = hold;
    var notified = 0;
    controller.addListener(() => notified++);
    final loading = controller.load();
    controller.dispose();
    hold.complete();
    await loading;
    expect(notified, 0);
  });
}
