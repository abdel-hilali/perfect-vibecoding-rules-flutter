/// Spacing steps (F8). A raw number for padding is fine only for a one-off optical correction, with a comment.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// The side margin of every page.
  static const double page = 16;

  /// The smallest tap target, in both directions (F16).
  static const double tapTarget = 48;
}
