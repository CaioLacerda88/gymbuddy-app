import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/shared/widgets/exercise_info_sections.dart';

import '../../../fixtures/test_finders.dart';
import '../../../helpers/test_material_app.dart';

Widget buildTestWidget(Widget child) {
  return TestMaterialApp(
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

    testWidgets(
      'renders a circular bullet for each tip (not a check_circle icon)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            const ExerciseFormTipsSection(
              formTips: 'Keep bar close\nHinge at hips\nSqueeze glutes',
            ),
          ),
        );

        expect(findBulletDots(), findsNWidgets(3));
        // P9: the old check_circle_outline icon is gone — the bullet is a
        // neutral dot, not a "done" checkmark.
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      },
    );

    testWidgets('bullet uses the primary color at full opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const ExerciseFormTipsSection(formTips: 'Single tip')),
      );

      final bullets = tester.widgetList<Container>(findBulletDots()).toList();
      expect(bullets, hasLength(1));

      final decoration = bullets.single.decoration! as BoxDecoration;
      final expectedPrimary = AppTheme.dark.colorScheme.primary;
      expect(decoration.color, expectedPrimary);
      // Flutter 3.x stores alpha as a Float64 channel. Future normalisation
      // changes could return 0.9999... instead of a precise 1.0, so we match
      // the tolerant pattern used in exercise_image_test.dart.
      expect(decoration.color!.a, closeTo(1.0, 0.001));
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
      // Only 2 bullets — empty lines not rendered.
      expect(findBulletDots(), findsNWidgets(2));
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
      expect(findBulletDots(), findsNothing);
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
        expect(findBulletDots(), findsNothing);
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
      expect(findBulletDots(), findsOneWidget);
    });

    testWidgets('tip text renders at full opacity (not muted)', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseFormTipsSection(formTips: 'Full opacity tip'),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Full opacity tip'));
      final resolvedColor = textWidget.style?.color;
      expect(resolvedColor, isNotNull);
      expect(resolvedColor!.a, closeTo(1.0, 0.001));
    });
  });

  group('ExerciseDescriptionSection opacity', () {
    testWidgets('description text renders at full opacity (not muted)', (
      tester,
    ) async {
      const bodyText = 'The description must read as primary content.';
      await tester.pumpWidget(
        buildTestWidget(
          const ExerciseDescriptionSection(description: bodyText),
        ),
      );

      final textWidget = tester.widget<Text>(find.text(bodyText));
      final resolvedColor = textWidget.style?.color;
      expect(resolvedColor, isNotNull);
      expect(resolvedColor!.a, closeTo(1.0, 0.001));
    });
  });
}
