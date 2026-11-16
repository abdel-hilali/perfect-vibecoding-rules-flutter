import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_500.dart';

/// Every icon of the app, from one family (F10): Lucide, regular weight, and the 500 weight for an active tab.
///
/// Pages never name LucideIcons or Icons directly: they use these constants through the AppIcon widget, so a
/// change of family is a change in this file only. With a designer's SVG set, this file becomes a list of asset
/// paths (assets/icons/common/, assets/icons/nav/x.svg and x_active.svg) and AppIcon draws them with srcIn.
abstract final class AppIcons {
  static const IconData orders = LucideIcons.package;
  static const IconData ordersActive = LucideIcons500.package;
  static const IconData settings = LucideIcons.settings;
  static const IconData settingsActive = LucideIcons500.settings;

  /// The Dir variants mirror in right-to-left languages, so "back" points the right way in Arabic.
  static const IconData back = LucideIcons.arrowLeftDir;
  static const IconData forward = LucideIcons.chevronRightDir;

  static const IconData retry = LucideIcons.refreshCw;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData empty = LucideIcons.inbox;
  static const IconData check = LucideIcons.check;
  static const IconData imageBroken = LucideIcons.imageOff;
  static const IconData theme = LucideIcons.sunMoon;
  static const IconData language = LucideIcons.languages;
  static const IconData signIn = LucideIcons.logIn;
}
