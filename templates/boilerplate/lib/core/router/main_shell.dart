import 'package:go_router/go_router.dart';
import 'package:kit_app/core/common/widgets/app_bottom_bar.dart';
import 'package:kit_app/core/common/widgets/root_back_handler.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The tab shell (F7, F12): the open tab's page, the app's bottom bar, and back-twice-to-leave on a tab root.
///
/// Scaffold sets the body's bottom inset to 0 under a bottomNavigationBar, so the pages pad their lists with
/// `N + MediaQuery.paddingOf(context).bottom` and look right both inside the shell and pushed above it.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RootBackHandler(
      child: Scaffold(
        body: shell,
        bottomNavigationBar: AppBottomBar(
          currentIndex: shell.currentIndex,
          onSelect: _select,
          tabs: [
            (
              icon: AppIcons.orders,
              activeIcon: AppIcons.ordersActive,
              label: l10n.navOrders,
              badgeCount: 0,
            ),
            (
              icon: AppIcons.settings,
              activeIcon: AppIcons.settingsActive,
              label: l10n.navSettings,
              badgeCount: 0,
            ),
          ],
        ),
      ),
    );
  }

  // Tapping the open tab again goes back to its first page; another tab opens where the user left it.
  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
}
