import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/exercise_info_sections.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('ExerciseDescriptionSection', () {
    testWidgets('renders ABOUT header and text when description is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseDescriptionSection(
            description: 'A hip-hinge movement targeting the hamstrings.',
          ),
        ),
      );

      expect(find.text('ABOUT'), findsOneWidget);
      expect(
        find.text('A hip-hinge movement targeting the hamstrings.'),
        findsOneWidget,
      );
    });

    testWidgets('returns SizedBox.shrink when description is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const ExerciseDescriptionSection(description: null)),
      );

      expect(find.text('ABOUT'), findsNothing);
      // The widget should render as a SizedBox with zero size.
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((b) => b.width == 0 && b.height == 0), isTrue);
    });

    testWidgets('returns SizedBox.shrink when description is empty string', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const ExerciseDescriptionSection(description: '')),
      );

      expect(find.text('ABOUT'), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when description is whitespace only', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const ExerciseDescriptionSection(description: '   ')),
      );

      expect(find.text('ABOUT'), findsNothing);
    });

    testWidgets('description text is rendered inside the section', (
      tester,
    ) async {
      const descText = 'Targets chest and anterior deltoids.';
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseDescriptionSection(description: descText),
        ),
      );

      expect(find.text(descText), findsOneWidget);
    });
  });

  group('ExerciseFormTipsSection', () {
    testWidgets('renders FORM TIPS header when tips are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(
            formTips: 'Keep bar close\nHinge at hips',
          ),
        ),
      );

      expect(find.text('FORM TIPS'), findsOneWidget);
    });

    testWidgets('renders check_circle_outline icons for each tip', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(
            formTips: 'Keep bar close\nHinge at hips\nSqueeze glutes',
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(3));
    });

    testWidgets('splits on newlines and renders each tip separately', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(
            formTips: 'Keep bar close\nHinge at hips',
          ),
        ),
      );

      expect(find.text('Keep bar close'), findsOneWidget);
      expect(find.text('Hinge at hips'), findsOneWidget);
    });

    testWidgets('filters out empty lines between tips', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(
            formTips: 'First tip\n\nSecond tip\n\n',
          ),
        ),
      );

      expect(find.text('First tip'), findsOneWidget);
      expect(find.text('Second tip'), findsOneWidget);
      // Only 2 icons — empty lines not rendered.
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
    });

    testWidgets('trims whitespace from individual tips', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(
            formTips: '  Keep bar close  \n  Hinge at hips  ',
          ),
        ),
      );

      expect(find.text('Keep bar close'), findsOneWidget);
      expect(find.text('Hinge at hips'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when formTips is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const ExerciseFormTipsSection(formTips: null)),
      );

      expect(find.text('FORM TIPS'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when formTips is empty string', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const ExerciseFormTipsSection(formTips: '')),
      );

      expect(find.text('FORM TIPS'), findsNothing);
    });

    testWidgets(
      'returns SizedBox.shrink when formTips contains only whitespace/newlines',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(const ExerciseFormTipsSection(formTips: '\n\n   \n')),
        );

        expect(find.text('FORM TIPS'), findsNothing);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      },
    );

    testWidgets('renders single tip correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(formTips: 'Only one tip'),
        ),
      );

      expect(find.text('FORM TIPS'), findsOneWidget);
      expect(find.text('Only one tip'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
