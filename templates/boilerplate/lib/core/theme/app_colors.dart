import 'package:material_ui/material_ui.dart';

/// The app's colours, named by role, never by hue (F8).
///
/// Widgets read them through `context.colors`, which depends on the theme: a theme change rebuilds every reader by
/// itself, where a static colour would stay stale until a full redraw. Every parameter is `required`, so a token
/// added to one theme and forgotten in the other does not compile.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.surface,
    required this.surfaceRaised,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.outline,
    required this.success,
    required this.warning,
    required this.danger,
    required this.onDanger,
    required this.scrim,
  });

  /// Whether this palette is light or dark: the system bars pick their icon colour from it.
  final Brightness brightness;

  /// The page background, painted edge to edge under both system bars.
  final Color surface;

  /// Cards, sheets and dialogs: one step above the page.
  final Color surfaceRaised;
  final Color onSurface;

  /// Secondary text and inactive icons. Still 4.5:1 on both surfaces (tested).
  final Color onSurfaceMuted;
  final Color primary;
  final Color onPrimary;

  /// A quiet brand tint behind selected rows and chips.
  final Color primarySoft;

  /// Hairlines and borders.
  final Color outline;
  final Color success;
  final Color warning;
  final Color danger;
  final Color onDanger;

  /// The dim layer behind sheets and dialogs.
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  // Keep `surface` equal to app_surface in android/app/src/main/res/values*/colors.xml: the window shows that colour
  // before the first frame, so a difference flashes at start.
  static const light = AppColors(
    brightness: Brightness.light,
    surface: Color(0xFFF7F7F5),
    surfaceRaised: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1C1E),
    onSurfaceMuted: Color(0xFF5D6166),
    primary: Color(0xFF2F5BD3),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE4EBFB),
    outline: Color(0xFFE1E2DE),
    success: Color(0xFF1E7A46),
    warning: Color(0xFF8F5300),
    danger: Color(0xFFC2271F),
    onDanger: Color(0xFFFFFFFF),
    scrim: Color(0x66000000),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    surface: Color(0xFF121416),
    surfaceRaised: Color(0xFF1C1F22),
    onSurface: Color(0xFFE8EAED),
    onSurfaceMuted: Color(0xFFA2A7AD),
    primary: Color(0xFF8AB0FF),
    onPrimary: Color(0xFF0A1F4F),
    primarySoft: Color(0xFF1E2C4D),
    outline: Color(0xFF2D3135),
    success: Color(0xFF5CCB8A),
    warning: Color(0xFFEBB052),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF3B0906),
    scrim: Color(0x99000000),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? surface,
    Color? surfaceRaised,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? outline,
    Color? success,
    Color? warning,
    Color? danger,
    Color? onDanger,
    Color? scrim,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: _mix(surface, other.surface, t),
      surfaceRaised: _mix(surfaceRaised, other.surfaceRaised, t),
      onSurface: _mix(onSurface, other.onSurface, t),
      onSurfaceMuted: _mix(onSurfaceMuted, other.onSurfaceMuted, t),
      primary: _mix(primary, other.primary, t),
      onPrimary: _mix(onPrimary, other.onPrimary, t),
      primarySoft: _mix(primarySoft, other.primarySoft, t),
      outline: _mix(outline, other.outline, t),
      success: _mix(success, other.success, t),
      warning: _mix(warning, other.warning, t),
      danger: _mix(danger, other.danger, t),
      onDanger: _mix(onDanger, other.onDanger, t),
      scrim: _mix(scrim, other.scrim, t),
    );
  }

  // Color.lerp answers null only when both colours are null, which two tokens never are.
  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;
}

extension AppColorsContext on BuildContext {
  /// The palette of the theme in force here. Reading it subscribes this widget to theme changes.
  AppColors get colors {
    final colors = Theme.of(this).extension<AppColors>();
    if (colors == null) {
      throw FlutterError(
        'AppColors is missing: build the theme with AppTheme.light() or AppTheme.dark().',
      );
    }
    return colors;
  }
}
