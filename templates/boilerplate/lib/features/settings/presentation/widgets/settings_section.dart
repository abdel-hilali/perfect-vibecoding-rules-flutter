import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_radius.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';

/// A titled group of rows on a raised card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.caption),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: AppRadius.card,
            border: Border.all(color: colors.outline, width: 0.5),
          ),
          // Clip, so the ink of the first and last rows stays inside the rounded corners.
          child: ClipRRect(
            borderRadius: AppRadius.card,
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}
