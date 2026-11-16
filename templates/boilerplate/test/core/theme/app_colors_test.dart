import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The WCAG contrast ratio of two opaque colours, from 1 to 21.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final palettes = {'light': AppColors.light, 'dark': AppColors.dark};

  for (final MapEntry(key: name, value: c) in palettes.entries) {
    group('AppColors.$name', () {
      // Every pair the app draws as text: 4.5:1 at least, the WCAG level for body text (F8, F16).
      final textPairs = {
        'onSurface on surface': (c.onSurface, c.surface),
        'onSurface on surfaceRaised': (c.onSurface, c.surfaceRaised),
        'onSurfaceMuted on surface': (c.onSurfaceMuted, c.surface),
        'onSurfaceMuted on surfaceRaised': (c.onSurfaceMuted, c.surfaceRaised),
        'onPrimary on primary': (c.onPrimary, c.primary),
        'primary on surface (active tab)': (c.primary, c.surface),
        'primary on surfaceRaised (status chip)': (c.primary, c.surfaceRaised),
        'success on surfaceRaised': (c.success, c.surfaceRaised),
        'warning on surfaceRaised': (c.warning, c.surfaceRaised),
        'danger on surfaceRaised': (c.danger, c.surfaceRaised),
        'onDanger on danger (badge)': (c.onDanger, c.danger),
        'surface on onSurface (toast)': (c.surface, c.onSurface),
      };
      for (final MapEntry(key: pair, value: (fg, bg)) in textPairs.entries) {
        test('$pair is readable', () {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name: $pair',
          );
        });
      }

      test('the brightness matches the page colour', () {
        final pageIsLight = c.surface.computeLuminance() > 0.5;
        expect(c.brightness, pageIsLight ? Brightness.light : Brightness.dark);
      });
    });
  }

  test('lerp ends on each palette', () {
    expect(
      AppColors.light.lerp(AppColors.dark, 1).surface,
      AppColors.dark.surface,
    );
    expect(
      AppColors.light.lerp(AppColors.dark, 0).surface,
      AppColors.light.surface,
    );
  });

  test('each theme carries its palette, so context.colors finds it', () {
    expect(AppTheme.light().extension<AppColors>(), same(AppColors.light));
    expect(AppTheme.dark().extension<AppColors>(), same(AppColors.dark));
  });
}
