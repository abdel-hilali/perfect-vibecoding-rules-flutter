import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kit_app/core/common/widgets/app_bottom_bar.dart';
import 'package:kit_app/core/common/widgets/show_app_sheet.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/router/main_shell.dart';
import 'package:kit_app/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

const _openSheet = Key('open-sheet');

void main() {
  // Regression: a sheet opened from a tab once opened on the tab's own navigator. It ended on top of the bottom
  // bar, and the bar stayed tappable under the scrim.
  testWidgets('a sheet opened from a tab covers the bottom bar', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => MainShell(shell: shell),
          branches: [
            for (final path in ['/a', '/b'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => const _OpensSheet(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.byKey(_openSheet));
    await tester.pumpAndSettle();
    final sheetBottom = tester.getBottomLeft(find.byType(BottomSheet)).dy;
    final barTop = tester.getTopLeft(find.byType(AppBottomBar)).dy;
    expect(sheetBottom, greaterThan(barTop));
  });
}

class _OpensSheet extends StatelessWidget {
  const _OpensSheet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: _openSheet,
        onPressed: () => showAppSheet<void>(
          context,
          builder: (context) => const SizedBox(height: 120),
        ),
        child: const SizedBox.square(dimension: 48),
      ),
    );
  }
}
