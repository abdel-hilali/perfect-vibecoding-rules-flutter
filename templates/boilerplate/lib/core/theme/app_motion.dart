import 'package:flutter/widgets.dart';

/// Durations and curves (F16). Motion explains a change; it runs once and never bounces for attention.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);

  /// A tab change in the bottom bar.
  static const Duration tab = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 300);

  /// The only motion allowed to take longer: a sheet or a drawer.
  static const Duration sheet = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// [duration], or zero when the user turned animations off in the system settings.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
