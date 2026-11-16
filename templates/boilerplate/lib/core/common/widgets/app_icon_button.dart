import 'package:kit_app/core/common/widgets/app_icon.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icon_size.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// An icon-only button (F10, F16): always a label, read by screen readers and shown as a tooltip on long press,
/// and a 48 dp tap target whatever the icon size.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      constraints: const BoxConstraints(
        minWidth: AppSpacing.tapTarget,
        minHeight: AppSpacing.tapTarget,
      ),
      icon: AppIcon(
        icon,
        size: AppIconSize.lg,
        color: color ?? context.colors.onSurface,
      ),
    );
  }
}
