/// Widget tests for the plan prompt integration in PRCelebrationScreen.
///
/// Covers:
/// - Prompt is shown when planPromptRoutineId/Name are provided
/// - Prompt is NOT shown when planPromptRoutineId is null
/// - Tapping Add calls addRoutineToPlan on the weekly plan notifier
/// - Tapping Skip navigates home without calling addRoutineToPlan
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/personal_records/domain/pr_detection_service.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';
import 'package:gymbuddy_app/features/personal_records/ui/pr_celebration_screen.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PersonalRecord _makeRecord({
  String exerciseId = 'exercise-001',
  RecordType recordType = RecordType.maxWeight,
  double value = 100,
}) {
  return PersonalRecord(
    id: 'pr-${recordType.name}-$exerciseId',
    userId: 'user-001',
    exerciseId: exerciseId,
    recordType: recordType,
    value: value,
    achievedAt: DateTime(2026),
  );
}

PRDetectionResult _defaultPRResult() =>
    PRDetectionResult(newRecords: [_makeRecord()], isFirstWorkout: false);

const _exerciseNames = {'exercise-001': 'Bench Press'};

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async {
    return const Profile(id: 'user-001', weightUnit: 'kg');
  }

  @override
  // ignore: must_call_super
  dynamic noSuchMethod(Invocation invocation) {}
}

class _TrackingWeeklyPlanNotifier extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  _TrackingWeeklyPlanNotifier(this._plan);
  final WeeklyPlan? _plan;
  final List<String> addedRoutineIds = [];

  @override
  Future<WeeklyPlan?> build() async => _plan;

  @override
  Future<bool> addRoutineToPlan(String routineId) async {
    addedRoutineIds.add(routineId);
    return true;
  }

  @override
  // ignore: must_call_super
  dynamic noSuchMethod(Invocation invocation) {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  required PRDetectionResult result,
  Map<String, String> exerciseNames = _exerciseNames,
  String? planPromptRoutineId,
  String? planPromptRoutineName,
  required List<Override> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/pr-celebration',
    routes: [
      GoRoute(
        path: '/pr-celebration',
        builder: (context, state) => PRCelebrationScreen(
          result: result,
          exerciseNames: exerciseNames,
          planPromptRoutineId: planPromptRoutineId,
          planPromptRoutineName: planPromptRoutineName,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PRCelebrationScreen plan prompt', () {
    testWidgets(
      'shows prompt after tapping Continue when prompt data present',
      (tester) async {
        final notifier = _TrackingWeeklyPlanNotifier(null);

        await tester.pumpWidget(
          _buildTestWidget(
            result: _defaultPRResult(),
            planPromptRoutineId: 'routine-abc',
            planPromptRoutineName: 'Push Day',
            overrides: [
              profileProvider.overrideWith(() => _FakeProfileNotifier()),
              weeklyPlanProvider.overrideWith(() => notifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap Continue.
        await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
        await tester.pumpAndSettle();

        // Prompt should be visible.
        expect(
          find.text("Push Day isn't in your plan yet. Add it?"),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping Add in prompt calls addRoutineToPlan', (tester) async {
      final notifier = _TrackingWeeklyPlanNotifier(null);

      await tester.pumpWidget(
        _buildTestWidget(
          result: _defaultPRResult(),
          planPromptRoutineId: 'routine-abc',
          planPromptRoutineName: 'Push Day',
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
            weeklyPlanProvider.overrideWith(() => notifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Tap Add.
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(notifier.addedRoutineIds, contains('routine-abc'));
      // Should have navigated to home.
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('tapping Skip in prompt does NOT call addRoutineToPlan', (
      tester,
    ) async {
      final notifier = _TrackingWeeklyPlanNotifier(null);

      await tester.pumpWidget(
        _buildTestWidget(
          result: _defaultPRResult(),
          planPromptRoutineId: 'routine-abc',
          planPromptRoutineName: 'Push Day',
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
            weeklyPlanProvider.overrideWith(() => notifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Tap Skip.
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(notifier.addedRoutineIds, isEmpty);
      // Should have navigated to home.
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('no prompt when planPromptRoutineId is null', (tester) async {
      final notifier = _TrackingWeeklyPlanNotifier(null);

      await tester.pumpWidget(
        _buildTestWidget(
          result: _defaultPRResult(),
          // No plan prompt data.
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
            weeklyPlanProvider.overrideWith(() => notifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Should navigate directly to home without showing prompt.
      expect(find.text('Home Screen'), findsOneWidget);
      expect(
        find.text("Push Day isn't in your plan yet. Add it?"),
        findsNothing,
      );
    });
  });
}
