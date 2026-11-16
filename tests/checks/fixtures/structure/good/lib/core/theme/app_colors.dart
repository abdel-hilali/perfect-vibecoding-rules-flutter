import 'package:flutter/material.dart';

// Colours live here and only here (F8).
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.surface, required this.onSurface});

  final Color surface;
  final Color onSurface;

  static const light = AppColors(surface: Color(0xFFFFFFFF), onSurface: Color(0xFF111111));
  static const dark = AppColors(surface: Color(0xFF111111), onSurface: Colors.white);

  @override
  AppColors copyWith({Color? surface, Color? onSurface}) =>
      AppColors(surface: surface ?? this.surface, onSurface: onSurface ?? this.onSurface);

  @override
  AppColors lerp(AppColors? other, double t) => other == null
      ? this
      : AppColors(
          surface: Color.lerp(surface, other.surface, t) ?? surface,
          onSurface: Color.lerp(onSurface, other.onSurface, t) ?? onSurface,
        );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
