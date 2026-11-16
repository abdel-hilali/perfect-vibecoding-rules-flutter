import 'package:kit_app/core/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';

/// The type scale (F8), coloured from the tokens, so `context.text.body` is readable on the page in both themes.
@immutable
class AppTextStyles {
  const AppTextStyles(this._colors);

  final AppColors _colors;

  /// The one family of the app. null means the platform font until the design picks one; then bundle its files,
  /// declare every weight in pubspec.yaml and name the family here. Never google_fonts at run time: it downloads
  /// the font on the user's phone, and one family per weight once broke `fontWeight`.
  static const String? fontFamily = null;

  TextStyle get display => _style(28, FontWeight.w600, 1.2, _colors.onSurface);
  TextStyle get title => _style(20, FontWeight.w600, 1.3, _colors.onSurface);
  TextStyle get titleSmall =>
      _style(16, FontWeight.w600, 1.35, _colors.onSurface);
  TextStyle get body => _style(15, FontWeight.w400, 1.45, _colors.onSurface);
  TextStyle get bodyMuted =>
      _style(15, FontWeight.w400, 1.45, _colors.onSurfaceMuted);
  TextStyle get label => _style(14, FontWeight.w500, 1.3, _colors.onSurface);
  TextStyle get caption =>
      _style(12, FontWeight.w500, 1.3, _colors.onSurfaceMuted);

  /// The same scale for Material's own widgets: buttons, dialogs, the date picker, the text selection menu.
  TextTheme toTextTheme() {
    return TextTheme(
      headlineSmall: display,
      titleLarge: title,
      titleMedium: titleSmall,
      titleSmall: label,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: caption,
      labelSmall: caption,
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    double height,
    Color color,
  ) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      // Splits the extra line height evenly above and below, so text centres in a fixed-height row.
      leadingDistribution: TextLeadingDistribution.even,
    );
  }
}

extension AppTextStylesContext on BuildContext {
  /// The type scale in the colours of the theme in force here.
  AppTextStyles get text => AppTextStyles(colors);
}
