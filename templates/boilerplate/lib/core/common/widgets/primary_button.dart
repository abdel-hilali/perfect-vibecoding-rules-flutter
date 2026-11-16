import 'dart:async';

import 'package:flutter/services.dart';
import 'package:kit_app/core/common/widgets/app_icon.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icon_size.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// The main action of a screen (F12, F16): full width, at least 48 dp tall, a light haptic on press, and a spinner
/// in place of the label while it works. The button keeps its size, so nothing on the screen jumps.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;

  /// null disables the button.
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = this.icon;
    final action = onPressed;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading || action == null ? null : () => _press(action),
        child: isLoading
            ? SizedBox.square(
                dimension: AppIconSize.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    AppIcon(icon, color: colors.onPrimary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }

  static void _press(VoidCallback action) {
    unawaited(HapticFeedback.lightImpact());
    action();
  }
}
