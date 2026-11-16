import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/common/widgets/app_text_field.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'the label names the field, the field stays 48 dp tall, and a long error wraps',
    (tester) async {
      const label = 'Email';
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      Widget page({String? error}) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: AppTextField(
            controller: controller,
            label: label,
            error: error,
          ),
        ),
      );

      // At text scale 1 the field is at its smallest.
      await pumpPage(tester, page(), textScale: 1);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(AppSpacing.tapTarget),
      );
      // Once the user types, a hint in place of the label would vanish and leave the field without a name.
      await tester.enterText(find.byType(TextField), 'sam@example.com');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(label), findsOneWidget);

      // At 320 dp and text scale 1.3 the message takes two lines in the test font; cut to one, the user never
      // reads the end.
      final error = l10nEn.commonErrorValidation;
      await pumpPage(tester, page(error: error));
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(error))
            .didExceedMaxLines,
        isFalse,
      );
    },
  );
}
