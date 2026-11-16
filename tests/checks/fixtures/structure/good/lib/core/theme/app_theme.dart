import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => ThemeData(extensions: const [AppColors.light]);
  static ThemeData dark() => ThemeData(brightness: Brightness.dark, extensions: const [AppColors.dark]);
}
