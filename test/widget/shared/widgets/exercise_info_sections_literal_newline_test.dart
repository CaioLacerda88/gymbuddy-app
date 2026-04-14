// Tests that expose BUG-002: form tips stored with literal '\n' (backslash+n)
// in the database render as a single block of text rather than split bullet points.
//
// The SQL migration 00010_seed_exercise_descriptions.sql uses standard single-quoted
// strings: form_tips = 'Tip one\nTip two'. In PostgreSQL with
// standard_conforming_strings=on (the default), '\n' inside single quotes is
// stored as the two-character sequence backslash + 'n', NOT as a newline (U+000A).
//
// ExerciseFormTipsSection.split('\n') only splits on actual newline characters
// (U+000A), so the literal '\n' separator is never recognized and the entire
// string renders as a single undivided tip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/exercise_info_sections.dart';

import '../../../fixtures/test_finders.dart';

Widget _build(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

// The exact string format stored in the database by
// 00010_seed_exercise_descriptions.sql: literal backslash+n as separator.
const String kDbFormTips =
    r'Plant feet flat on the floor and squeeze shoulder blades together'
    r'\n'
    r'Lower the bar to mid-chest with elbows at roughly 45 degrees'
    r'\n'
    r'Press up and slightly back to lockout';

void main() {
  group('ExerciseFormTipsSection — database literal \\n separator (BUG-002)', () {
    testWidgets(
      'form tips stored with literal \\n (database format) render as separate tips',
      (tester) async {
        // This is what the database returns for all default exercises from
        // migration 00010_seed_exercise_descriptions.sql.
        await tester.pumpWidget(
          _build(const ExerciseFormTipsSection(formTips: kDbFormTips)),
        );

        // BUG-002: Each tip should be a separate bullet. Currently the whole
        // string renders as one tip because split('\n') doesn't match literal '\n'.
        expect(
          find.text(
            'Plant feet flat on the floor and squeeze shoulder blades together',
          ),
          findsOneWidget,
          reason:
              'BUG-002: first tip must render separately. '
              'Currently the entire string renders as one block because '
              r"ExerciseFormTipsSection splits on '\n' (U+000A) but the "
              r"database stores '\n' (two chars: backslash + n).",
        );
        expect(
          find.text(
            'Lower the bar to mid-chest with elbows at roughly 45 degrees',
          ),
          findsOneWidget,
          reason: 'BUG-002: second tip must render as its own bullet',
        );
        expect(
          find.text('Press up and slightly back to lockout'),
          findsOneWidget,
          reason: 'BUG-002: third tip must render as its own bullet',
        );
      },
    );

    testWidgets('form tips with literal \\n show three bullet dots (not one)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(const ExerciseFormTipsSection(formTips: kDbFormTips)),
      );

      // BUG-002: With database content there should be 3 bullets (one per tip).
      // Currently only 1 appears if the entire string is treated as one "tip".
      // P9 replaced the check_circle_outline icon with a 6x6 circular Container.
      expect(
        findBulletDots(),
        findsNWidgets(3),
        reason:
            'BUG-002: three tips should each render a bullet dot. '
            'Currently one appears if the string is not split.',
      );
    });

    testWidgets(
      'form tips containing only literal \\n separators with no tips shows nothing',
      (tester) async {
        // Edge case: a string that is just literal backslash-n sequences.
        const onlySeparators = r'\n\n\n';
        await tester.pumpWidget(
          _build(const ExerciseFormTipsSection(formTips: onlySeparators)),
        );

        // After correct fix: all parts trim to empty → render nothing.
        // Current behavior: renders as one tip (the string is not empty after
        // trim because it contains backslash chars).
        // This test documents the expected final behavior post-fix.
        expect(find.text('FORM TIPS'), findsNothing);
        expect(findBulletDots(), findsNothing);
      },
    );

    testWidgets(
      'form tips with actual newline characters (U+000A) still work correctly',
      (tester) async {
        // Regression guard: the fix must not break the case where actual
        // newlines ARE present (e.g., data entered by users via the app UI).
        const withRealNewlines =
            'Tip one\nTip two\nTip three'; // actual newlines, not literal \n

        await tester.pumpWidget(
          _build(const ExerciseFormTipsSection(formTips: withRealNewlines)),
        );

        expect(find.text('Tip one'), findsOneWidget);
        expect(find.text('Tip two'), findsOneWidget);
        expect(find.text('Tip three'), findsOneWidget);
        expect(findBulletDots(), findsNWidgets(3));
      },
    );
  });
}
