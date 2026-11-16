import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_theme.dart';
import 'package:kit_app/core/theme/system_bars.dart';

void main() {
  final palettes = {'light': AppColors.light, 'dark': AppColors.dark};

  for (final MapEntry(key: name, value: colors) in palettes.entries) {
    group('systemOverlayFor, $name theme', () {
      final style = systemOverlayFor(colors);

      test('icons on both bars are the opposite of the page', () {
        final expected = colors.isDark ? Brightness.light : Brightness.dark;
        expect(style.statusBarIconBrightness, expected);
        expect(style.systemNavigationBarIconBrightness, expected);
      });

      test('iOS reads the brightness of the page', () {
        expect(style.statusBarBrightness, colors.brightness);
      });

      test('the status bar is transparent and the navigation bar takes the page colour', () {
        expect(style.statusBarColor?.a, 0);
        expect(style.systemNavigationBarColor, colors.surface);
        expect(style.systemNavigationBarDividerColor?.a, 0);
      });

      test('Android lays no contrast scrim over the bars', () {
        expect(style.systemNavigationBarContrastEnforced, isFalse);
        expect(style.systemStatusBarContrastEnforced, isFalse);
      });
    });
  }

  test('the app bar theme carries the same style, in both themes', () {
    expect(
      AppTheme.light().appBarTheme.systemOverlayStyle,
      systemOverlayFor(AppColors.light),
    );
    expect(
      AppTheme.dark().appBarTheme.systemOverlayStyle,
      systemOverlayFor(AppColors.dark),
    );
  });

  test('a light page gets dark icons, the standard dark style', () {
    final style = systemOverlayFor(AppColors.light);
    expect(
      style.statusBarIconBrightness,
      SystemUiOverlayStyle.dark.statusBarIconBrightness,
    );
  });
}
