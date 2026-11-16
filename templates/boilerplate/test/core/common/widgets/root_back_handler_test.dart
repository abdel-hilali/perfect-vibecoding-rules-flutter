import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/widgets/root_back_handler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late int exits;
  late DateTime now;

  Future<void> pumpHandler(WidgetTester tester) async {
    exits = 0;
    now = DateTime.utc(2026, 3, 14, 9);
    await pumpPage(
      tester,
      RootBackHandler(
        onExit: () async => exits++,
        clock: () => now,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    );
  }

  // What Android's back button sends to the app.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  testWidgets(
    'the first back shows the toast, a second one within the window leaves',
    (tester) async {
      await pumpHandler(tester);
      await pressBack(tester);
      expect(find.text(l10nEn.commonPressBackAgain), findsOneWidget);
      expect(exits, 0);
      now = now.add(const Duration(seconds: 1));
      await pressBack(tester);
      expect(exits, 1);
      // Lets the toast's timer run out, so no timer outlives the test.
      await tester.pumpAndSettle(const Duration(seconds: 4));
    },
  );

  testWidgets('a second back after the window only shows the toast again', (
    tester,
  ) async {
    await pumpHandler(tester);
    await pressBack(tester);
    now = now.add(RootBackHandler.window + const Duration(milliseconds: 1));
    await pressBack(tester);
    expect(exits, 0);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
