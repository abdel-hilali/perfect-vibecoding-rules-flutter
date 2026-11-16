import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/repositories/settings_repository.dart';

class SaveLanguage {
  const SaveLanguage(this._repository);

  final SettingsRepository _repository;

  /// null follows the phone's language again.
  Future<Result<void>> call(String? languageCode) =>
      _repository.saveLanguage(languageCode);
}
