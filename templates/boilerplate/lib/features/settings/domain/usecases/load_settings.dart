import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/settings/domain/entities/app_settings.dart';
import 'package:kit_app/features/settings/domain/repositories/settings_repository.dart';

/// Reads the saved settings once, before the first frame, so the app opens in the right theme and language.
class LoadSettings {
  const LoadSettings(this._repository);

  final SettingsRepository _repository;

  Future<Result<AppSettings>> call() => _repository.load();
}
