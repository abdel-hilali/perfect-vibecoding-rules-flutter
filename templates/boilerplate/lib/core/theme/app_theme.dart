import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_radius.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:kit_app/core/theme/system_bars.dart';
import 'package:material_ui/material_ui.dart';

/// The two themes of the app, built from the same tokens (F8). MaterialApp gets both and the user's ThemeMode, so
/// light and dark follow the phone (the default) or the user's choice with no code in the pages.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final text = AppTextStyles(c);
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: _scheme(c),
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: text.toTextTheme(),
      // Widgets read the tokens through context.colors; this is where they come from.
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayFor(c),
      ),
      // No fixed colour in showAppSheet: the sheet reads it here on each build, so a live theme switch repaints it.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        modalBackgroundColor: c.surfaceRaised,
        modalBarrierColor: c.scrim,
        showDragHandle: true,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        barrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        titleTextStyle: text.title,
        contentTextStyle: text.body,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.onSurface,
        contentTextStyle: text.body.copyWith(color: c.surface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      filledButtonTheme: _filledButtons(c, text),
      textButtonTheme: _textButtons(c, text),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      dividerTheme: DividerThemeData(
        color: c.outline,
        thickness: 0.5,
        space: 0.5,
      ),
    );
  }

  static FilledButtonThemeData _filledButtons(AppColors c, AppTextStyles text) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        // A busy PrimaryButton is disabled: its spinner stays readable on a faded brand colour, not on grey.
        disabledBackgroundColor: c.primary.withValues(alpha: 0.55),
        disabledForegroundColor: c.onPrimary,
        minimumSize: const Size(AppSpacing.tapTarget, AppSpacing.tapTarget),
        textStyle: text.label,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
    );
  }

  static TextButtonThemeData _textButtons(AppColors c, AppTextStyles text) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(AppSpacing.tapTarget, AppSpacing.tapTarget),
        textStyle: text.label,
      ),
    );
  }

  // Material widgets the app does not restyle (the date picker, the text selection menu) read this scheme.
  static ColorScheme _scheme(AppColors c) {
    return ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.onSurface,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.danger,
      onError: c.onDanger,
      surface: c.surface,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceMuted,
      surfaceContainerLow: c.surfaceRaised,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceRaised,
      outline: c.outline,
      outlineVariant: c.outline,
      scrim: c.scrim,
    );
  }
}
