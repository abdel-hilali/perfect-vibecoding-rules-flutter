import 'dart:async';

import 'package:flutter/services.dart';
import 'package:kit_app/core/common/widgets/app_icon.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icon_size.dart';
import 'package:kit_app/core/theme/app_motion.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';

/// One tab of the bottom bar. [badgeCount] 0 shows no badge.
typedef AppTab = ({
  IconData icon,
  IconData activeIcon,
  String label,
  int badgeCount,
});

/// The app's bottom bar, drawn by MainShell (F9, F12).
///
/// It paints the page colour with a hairline on top, and runs that colour under the gesture bar
/// (DecoratedBox > SafeArea(top: false)): from Android 15 the system bar is transparent, and only what the app
/// paints shows there. The active tab is bold in the brand colour, the others muted; a change takes 180 ms.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<AppTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _TabButton(
                  tab: tabs[i],
                  active: i == currentIndex,
                  onTap: () => _select(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _select(int index) {
    // A click for a change only; tapping the open tab again is not a selection.
    if (index != currentIndex) {
      unawaited(HapticFeedback.selectionClick());
    }
    onSelect(index);
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final AppTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.primary : colors.onSurfaceMuted;
    final duration = AppMotion.of(context, AppMotion.tab);
    final style = context.text.caption.copyWith(
      color: color,
      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
    );
    // One node per tab for screen readers: its label once, its state, and that it is a button.
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.tapTarget + AppSpacing.sm,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TabIcon(
                  tab: tab,
                  active: active,
                  color: color,
                  duration: duration,
                ),
                const SizedBox(height: AppSpacing.xxs),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: style,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.tab,
    required this.active,
    required this.color,
    required this.duration,
  });

  final AppTab tab;
  final bool active;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedSwitcher(
      duration: duration,
      child: AppIcon(
        active ? tab.activeIcon : tab.icon,
        key: ValueKey<bool>(active),
        size: AppIconSize.lg,
        color: color,
      ),
    );
    if (tab.badgeCount <= 0) {
      return icon;
    }
    final colors = context.colors;
    return Badge(
      backgroundColor: colors.danger,
      textColor: colors.onDanger,
      // The only place the text scale is clamped (F16): a badge must stay inside its pill.
      label: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Text(tab.badgeCount.toString()),
      ),
      child: icon,
    );
  }
}
