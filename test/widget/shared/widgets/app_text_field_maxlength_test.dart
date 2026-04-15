import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/app_text_field.dart';

void main() {
  Widget buildField({
    required TextEditingController controller,
    int? maxLength,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: AppTextField(
          label: 'Name',
          controller: controller,
          maxLength: maxLength,
        ),
      ),
    );
  }

  group('AppTextField maxLength', () {
    testWidgets('clamps input to the specified length', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildField(controller: controller, maxLength: 10),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'abcdefghijklmnopqrst',
      );
      await tester.pump();

      expect(controller.text.length, 10);
      expect(controller.text, 'abcdefghij');
    });

    testWidgets('counter appears when maxLength is set', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildField(controller: controller, maxLength: 50),
      );

      expect(find.textContaining('/50'), findsOneWidget);
    });
  });
}
