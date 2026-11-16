import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';
import 'package:kit_app/features/settings/domain/repositories/settings_repository.dart';

class SaveThemeChoice {
  const SaveThemeChoice(this._repository);

  final SettingsRepository _repository;

  Future<Result<void>> call(ThemeChoice choice) =>
      _repository.saveTheme(choice);
}
