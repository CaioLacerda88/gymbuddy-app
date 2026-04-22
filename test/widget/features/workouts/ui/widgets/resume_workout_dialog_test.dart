import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/workouts/ui/widgets/resume_workout_dialog.dart';
import '../../../../../helpers/test_material_app.dart';

/// Pumps the dialog via a builder so [Navigator.pop] works correctly and the
/// returned result is captured.
Future<ResumeWorkoutResult?> _showDialog(
  WidgetTester tester, {
  required String workoutName,
  required DateTime startedAt,
  DateTime? now,
}) async {
  ResumeWorkoutResult? captured;

  await tester.pumpWidget(
    TestMaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              captured = await ResumeWorkoutDialog.show(
                context,
                workoutName: workoutName,
                startedAt: startedAt,
                now: now,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  // Returned once Navigator.pop fires via button taps.
  return captured;
}

void main() {
  group('ResumeWorkoutDialog — fresh branch (<6h)', () {
    testWidgets('title is "Resume workout?"', (tester) async {
      await _showDialog(
        tester,
        workoutName: 'Push Day',
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      expect(find.text('Resume workout?'), findsOneWidget);
      expect(find.text('Pick up where you left off?'), findsNothing);
    });

    testWidgets('body mentions the workout name', (tester) async {
      await _showDialog(
        tester,
        workoutName: 'Leg Day',
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      expect(find.textContaining('Leg Day'), findsOneWidget);
    });

    testWidgets('primary button label is "Resume"', (tester) async {
      await _showDialog(
        tester,
        workoutName: 'Push Day',
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
      expect(find.text('Resume anyway'), findsNothing);
    });

    testWidgets('Discard button is visible', (tester) async {
      await _showDialog(
        tester,
        workoutName: 'Push Day',
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
    });
  });

  group('ResumeWorkoutDialog — stale branch (>=6h)', () {
    testWidgets('title is "Pick up where you left off?"', (tester) async {
      await _showDialog(
        tester,
        workoutName: 'Push Day',
        startedAt: DateTime.now().subtract(const Duration(hours: 8)),
      );

      expect(find.text('Pick up where you left off?'), findsOneWidget);
      expect(find.text('Resume workout?'), findsNothing);
    });

    testWidgets('body surfaces both the workout name and an age hint', (
      tester,
    ) async {
      // Pinned clock so the "hours ago" assertion does not flake when the
      // suite runs near midnight (subtracting 8h from wall time would cross
      // into the previous calendar day and hit the "yesterday at ..." branch).
      final now = DateTime(2026, 4, 15, 14, 0);
      await _showDialog(
        tester,
        workoutName: 'Leg Day',
        startedAt: now.subtract(const Duration(hours: 8)),
        now: now,
      );

      // Text.rich concatenates the spans into a single RichText — search on
      // the combined textual content. The name is wrapped in literal quote
      // characters to match the fresh branch's quoting style, so we assert
      // the quotes are rendered (not just the substring).
      expect(find.textContaining('"Leg Day"'), findsOneWidget);
      expect(find.textContaining('hours ago'), findsOneWidget);
    });

    testWidgets('primary button label is "Resume anyway"', (tester) async {
      await _showDialog(
        tester,
        workoutName: 'Push Day',
        startedAt: DateTime.now().subtract(const Duration(hours: 8)),
      );

      expect(
        find.widgetWithText(FilledButton, 'Resume anyway'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Resume'), findsNothing);
    });
  });

  group('ResumeWorkoutDialog — actions', () {
    testWidgets('tapping Discard returns ResumeWorkoutResult.discard', (
      tester,
    ) async {
      ResumeWorkoutResult? captured;

      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  captured = await ResumeWorkoutDialog.show(
                    context,
                    workoutName: 'Push Day',
                    startedAt: DateTime.now().subtract(
                      const Duration(minutes: 30),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(captured, ResumeWorkoutResult.discard);
    });

    testWidgets('tapping Resume returns ResumeWorkoutResult.resume', (
      tester,
    ) async {
      ResumeWorkoutResult? captured;

      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  captured = await ResumeWorkoutDialog.show(
                    context,
                    workoutName: 'Push Day',
                    startedAt: DateTime.now().subtract(
                      const Duration(minutes: 30),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(captured, ResumeWorkoutResult.resume);
    });

    testWidgets('tapping "Resume anyway" on stale dialog returns '
        'ResumeWorkoutResult.resume', (tester) async {
      ResumeWorkoutResult? captured;

      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  captured = await ResumeWorkoutDialog.show(
                    context,
                    workoutName: 'Push Day',
                    startedAt: DateTime.now().subtract(
                      const Duration(hours: 8),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resume anyway'));
      await tester.pumpAndSettle();

      expect(captured, ResumeWorkoutResult.resume);
    });
  });
}
