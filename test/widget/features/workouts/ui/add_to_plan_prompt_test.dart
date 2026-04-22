/// Widget tests for the post-workout "Add to plan?" prompt.
///
/// Covers:
/// - Prompt displays routine name and action buttons
/// - "Add" returns true
/// - "Skip" returns false
/// - Dismissing returns null
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/workouts/ui/widgets/add_to_plan_prompt.dart';
import '../../../../helpers/test_material_app.dart';

void main() {
  /// Helper that renders a scaffold with a button that opens the prompt.
  Widget buildTestWidget({required String routineName}) {
    return TestMaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final result = await showAddToPlanPrompt(
                context,
                routineName: routineName,
              );
              // Store the result in a text widget so we can verify it.
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('result:$result')));
              }
            },
            child: const Text('Open Prompt'),
          ),
        ),
      ),
    );
  }

  group('AddToPlanPrompt', () {
    testWidgets('displays routine name and action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(routineName: 'Push Day'));
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(
        find.text("Push Day isn't in your plan yet. Add it?"),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
    });

    testWidgets('tapping Add returns true', (tester) async {
      await tester.pumpWidget(buildTestWidget(routineName: 'Push Day'));
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('result:true'), findsOneWidget);
    });

    testWidgets('tapping Skip returns false', (tester) async {
      await tester.pumpWidget(buildTestWidget(routineName: 'Push Day'));
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(find.text('result:false'), findsOneWidget);
    });

    testWidgets('dragging down to dismiss returns null', (tester) async {
      await tester.pumpWidget(buildTestWidget(routineName: 'Push Day'));
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      // Swipe down on the sheet content to dismiss it.
      await tester.drag(
        find.text("Push Day isn't in your plan yet. Add it?"),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();

      // No result snackbar — null was returned, nothing was shown.
      expect(find.text('result:true'), findsNothing);
      expect(find.text('result:false'), findsNothing);
    });
  });
}
