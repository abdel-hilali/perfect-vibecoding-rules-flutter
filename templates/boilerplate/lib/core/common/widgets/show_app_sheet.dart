import 'package:flutter/services.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_motion.dart';
import 'package:kit_app/core/theme/system_bars.dart';
import 'package:material_ui/material_ui.dart';

/// The ONE way to open a bottom sheet (F9, F12).
///
/// No fixed background colour: the sheet reads it from the theme on each build, so a live theme switch repaints
/// it. `useSafeArea` keeps it below the status bar; inside, it pads itself above the gesture bar and the keyboard,
/// and gives the navigation bar the sheet's colour while it is open.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Above the tab shell: from a tab, the nearest navigator is the tab's own, and the sheet would end on top of
    // the bottom bar, which stays live under it.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.of(context, AppMotion.sheet),
      reverseDuration: AppMotion.of(context, AppMotion.normal),
    ),
    builder: (sheetContext) => _AppSheet(builder: builder),
  );
}

class _AppSheet extends StatelessWidget {
  const _AppSheet({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayFor(colors)
          .copyWith(systemNavigationBarColor: colors.surfaceRaised),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(top: false, child: builder(context)),
      ),
    );
  }
}
