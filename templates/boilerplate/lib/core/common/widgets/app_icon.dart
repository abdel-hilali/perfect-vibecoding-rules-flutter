import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icon_size.dart';
import 'package:material_ui/material_ui.dart';

/// The only way an icon reaches the screen (F10): one family (AppIcons), a size from AppIconSize, a colour from the
/// tokens. With a designer's SVG set, this widget draws `SvgPicture.asset` with `BlendMode.srcIn` instead, and no
/// page changes.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = AppIconSize.md,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;

  /// null means the text colour of the page.
  final Color? color;

  /// Only for an icon that means something on its own. A decorative icon has none and screen readers skip it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? context.colors.onSurface,
      semanticLabel: semanticLabel,
    );
  }
}
