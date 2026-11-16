import 'dart:async';

import 'package:kit_app/core/common/widgets/app_icon_button.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';

/// The top bar of every page (F9, F12).
///
/// It paints the page colour under the status bar and pads itself by the bar's height, so the page needs no
/// SafeArea on top. The back button shows only when there is a page to go back to.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack,
  });

  /// From the catalog, never typed here.
  final String title;
  final List<Widget> actions;

  /// null means: only on a pushed page.
  final bool? showBack;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final canGoBack =
        showBack ?? (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    return ColoredBox(
      color: context.colors.surface,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: MediaQuery.paddingOf(context).top,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Row(
            children: [
              if (canGoBack)
                AppIconButton(
                  icon: AppIcons.back,
                  label: context.l10n.commonBack,
                  onPressed: () => unawaited(Navigator.of(context).maybePop()),
                )
              else
                const SizedBox(width: AppSpacing.page),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: context.text.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ...actions,
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
