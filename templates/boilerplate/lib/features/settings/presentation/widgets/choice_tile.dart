import 'package:kit_app/core/common/widgets/app_icon.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';

/// One option of a single-choice list: the label, and a check on the chosen one. At least 48 dp tall, and read as
/// "selected, in a group" by screen readers (F16).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.tapTarget),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: context.text.body)),
                if (selected)
                  AppIcon(AppIcons.check, color: context.colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
