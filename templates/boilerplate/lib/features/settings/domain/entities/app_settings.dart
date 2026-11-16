import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';

/// The settings saved on this device.
class AppSettings {
  const AppSettings({this.theme = ThemeChoice.system, this.languageCode});

  final ThemeChoice theme;

  /// A language code from the catalogs (en, fr, ar), or null to follow the phone.
  final String? languageCode;
}
