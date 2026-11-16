import 'package:kit_app/core/common/widgets/app_icon.dart';
import 'package:kit_app/core/theme/app_icon_size.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';

/// The layout the empty and error states share: an icon, a title, a message and an optional action.
///
/// It scrolls when it must: at a large text scale on a small phone it would overflow otherwise (F16).
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  /// Lines stay readable on a tablet.
  static const double maxWidth = 420;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: AppIconSize.lg, color: iconColor),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: text.title, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: text.bodyMuted, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
