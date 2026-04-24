import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/data/base_repository.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/analytics/data/analytics_repository.dart';
import 'package:repsaga/features/analytics/data/models/analytics_event.dart';
import 'package:repsaga/features/analytics/providers/analytics_providers.dart';
import 'package:repsaga/features/auth/data/auth_repository.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/personal_records/domain/pr_detection_service.dart';
import 'package:repsaga/features/personal_records/models/personal_record.dart';
import 'package:repsaga/features/personal_records/models/record_type.dart';
import 'package:repsaga/features/personal_records/ui/pr_celebration_screen.dart';
import 'package:repsaga/features/profile/models/profile.dart';
import 'package:repsaga/features/profile/providers/profile_providers.dart';
import 'package:repsaga/shared/widgets/reward_accent.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../helpers/test_material_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// No-op analytics repo — prevents tests from touching `Supabase.instance`
/// when the screen fires `pr_celebration_seen` in `initState`.
class _FakeAnalyticsRepository extends BaseRepository
    implements AnalyticsRepository {
  const _FakeAnalyticsRepository();

  @override
  Future<void> insertEvent({
    required String userId,
    required AnalyticsEvent event,
    required String? platform,
    required String? appVersion,
  }) async {}
}

void main() {
  Widget buildTestWidget({
    required PRDetectionResult result,
    required Map<String, String> exerciseNames,
  }) {
    final mockAuth = _MockAuthRepository();
    when(() => mockAuth.currentUser).thenReturn(null);

    return ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        authRepositoryProvider.overrideWithValue(mockAuth),
        analyticsRepositoryProvider.overrideWithValue(
          const _FakeAnalyticsRepository(),
        ),
      ],
      child: TestMaterialApp(
        theme: AppTheme.dark,
        home: PRCelebrationScreen(result: result, exerciseNames: exerciseNames),
      ),
    );
  }

  PersonalRecord makeRecord({
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

  group('PRCelebrationScreen', () {
    testWidgets('shows first workout message when isFirstWorkout is true', (
      tester,
    ) async {
      final result = PRDetectionResult(
        newRecords: [
          makeRecord(recordType: RecordType.maxWeight, value: 100),
          makeRecord(recordType: RecordType.maxReps, value: 10),
        ],
        isFirstWorkout: true,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First Workout Complete!'), findsOneWidget);
      expect(find.text('These are your starting benchmarks'), findsOneWidget);
    });

    testWidgets('shows NEW PR banner for subsequent PRs', (tester) async {
      final result = PRDetectionResult(
        newRecords: [makeRecord(recordType: RecordType.maxWeight, value: 120)],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEW PR'), findsOneWidget);
    });

    testWidgets('shows exercise name and record values', (tester) async {
      final result = PRDetectionResult(
        newRecords: [
          makeRecord(
            exerciseId: 'exercise-001',
            recordType: RecordType.maxWeight,
            value: 120,
          ),
        ],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('120 kg'), findsOneWidget);
    });

    testWidgets('continue button is present', (tester) async {
      final result = PRDetectionResult(
        newRecords: [makeRecord()],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
    });

    testWidgets('flash overlay fires in reward-gold, not violet '
        '(§17.0c reward-scarcity)', (tester) async {
      // The flash is the full-screen `IgnorePointer > AnimatedOpacity >
      // Container` overlay at the end of the Stack. We assert the Container's
      // `color` matches RewardAccent.color (heroGold). Prior behavior flashed
      // `theme.colorScheme.primary` (violet), which diluted the reward beat.
      final result = PRDetectionResult(
        newRecords: [makeRecord(recordType: RecordType.maxWeight, value: 120)],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      // One pump to register initState + schedule the post-frame callback.
      // Do NOT pumpAndSettle here — the flash fades out; we want to inspect
      // the flash Container while it's still in the tree.
      await tester.pump();

      // Walk every descendant of the AnimatedOpacity and pick the first
      // Container that has `color` set (the flash). Its color should be the
      // RewardAccent gold token, NOT the primary violet.
      final flashContainers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(AnimatedOpacity),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.color != null)
          .toList();

      expect(
        flashContainers,
        isNotEmpty,
        reason:
            'Expected at least one colored Container inside the flash '
            'AnimatedOpacity overlay.',
      );
      expect(flashContainers.first.color, RewardAccent.color);
      // Negative fence: if someone reverts the flash back to the generic
      // theme primary (violet), this test must fail. Violet is the daily
      // CTA — gold is quarantined to rare/earned moments like this one.
      expect(
        flashContainers.first.color,
        isNot(equals(AppColors.primaryViolet)),
        reason: 'PR flash must NOT be the CTA violet — gold only.',
      );

      // Drain the 300ms haptic-pulse timer that initState schedules so
      // the test framework does not complain about a pending timer.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('mounted guard: no exception when widget removed before '
        'addPostFrameCallback fires (C3)', (tester) async {
      // Regression: PRCelebrationScreen.initState schedules an
      // addPostFrameCallback that calls setState. If the widget is removed
      // from the tree before that callback fires, it must not throw.
      final result = PRDetectionResult(
        newRecords: [makeRecord()],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );

      // pumpWidget internally calls pump(), which fires the
      // addPostFrameCallback. The callback schedules a 300ms Future.delayed
      // for a second haptic pulse. We need to drain that timer after
      // removing the widget to avoid "Timer still pending" errors.

      // Remove the PRCelebrationScreen from the tree.
      await tester.pumpWidget(
        const TestMaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      // Drain the 300ms haptic timer that was scheduled by initState's
      // post-frame callback before the widget was removed.
      await tester.pump(const Duration(milliseconds: 400));

      // If the mounted guard were missing, the post-frame callback would
      // throw a "setState() called after dispose" exception. Reaching here
      // means the guard works.
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async {
    return const Profile(id: 'user-001', weightUnit: 'kg');
  }

  @override
  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
    int trainingFrequencyPerWeek = 3,
  }) async {}

  @override
  Future<void> updateTrainingFrequency(int frequency) async {}

  @override
  Future<void> toggleWeightUnit() async {}
}
