/// Unit tests for WeeklyPlanNotifier.markRoutineComplete week_complete event.
///
/// Covers:
/// - Fires week_complete exactly once on the transition from "some routines
///   incomplete" to "all routines complete".
/// - Does NOT fire when completing a routine mid-plan (not all done yet).
/// - Does NOT fire when called on an already-complete plan (idempotent re-tap
///   guard).
/// - Passes plan size, sessions completed, and PR count from the cached
///   prListProvider (or 0 if cold).
/// - Does NOT fire when no user is authenticated.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/data/base_repository.dart';
import 'package:gymbuddy_app/features/analytics/data/analytics_repository.dart';
import 'package:gymbuddy_app/features/analytics/data/models/analytics_event.dart';
import 'package:gymbuddy_app/features/analytics/providers/analytics_providers.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/weekly_plan_repository.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

// ---------------------------------------------------------------------------
// Mocks / Fakes
// ---------------------------------------------------------------------------

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockWeeklyPlanRepository extends Mock implements WeeklyPlanRepository {}

/// Records every AnalyticsEvent passed to [insertEvent] so tests can assert
/// whether week_complete was fired (and with which props). Does NOT touch
/// Supabase, so it keeps the test off the `Supabase.instance` assertion path.
class _FakeAnalyticsRepository extends BaseRepository
    implements AnalyticsRepository {
  _FakeAnalyticsRepository();

  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  Future<void> insertEvent({
    required String userId,
    required AnalyticsEvent event,
    required String? platform,
    required String? appVersion,
  }) async {
    events.add(event);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _fakeUser = User(
  id: 'user-001',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// Builds a [WeeklyPlan] where each entry in [routineIds] is a bucket routine;
/// if its index is in [completedIndices], it is marked completed.
WeeklyPlan _makePlan({
  required List<String> routineIds,
  Set<int> completedIndices = const <int>{},
  DateTime? weekStart,
}) {
  final routines = routineIds.asMap().entries.map((e) {
    final isDone = completedIndices.contains(e.key);
    return BucketRoutine(
      routineId: e.value,
      order: e.key + 1,
      completedWorkoutId: isDone ? 'workout-${e.value}' : null,
      completedAt: isDone ? DateTime(2026, 4, 7) : null,
    );
  }).toList();
  return WeeklyPlan(
    id: 'plan-001',
    userId: 'user-001',
    weekStart: weekStart ?? DateTime(2026, 4, 6), // Monday
    routines: routines,
    createdAt: DateTime(2026, 4, 6),
    updatedAt: DateTime(2026, 4, 6),
  );
}

PersonalRecord _makePR({required String id, required DateTime achievedAt}) {
  return PersonalRecord(
    id: id,
    userId: _fakeUser.id,
    exerciseId: 'exercise-001',
    recordType: RecordType.maxWeight,
    value: 100.0,
    achievedAt: achievedAt,
  );
}

/// Creates a container with the notifier pre-seeded to [initialPlan] and all
/// downstream providers faked out.
({
  ProviderContainer container,
  _FakeAnalyticsRepository analytics,
  _MockWeeklyPlanRepository mockRepo,
})
_makeContainer({
  required WeeklyPlan? initialPlan,
  required WeeklyPlan afterMarkPlan,
  User? user = _fakeUser,
  List<PersonalRecord> prList = const <PersonalRecord>[],
}) {
  final mockAuth = _MockAuthRepository();
  when(() => mockAuth.currentUser).thenReturn(user);

  final mockRepo = _MockWeeklyPlanRepository();
  when(
    () => mockRepo.markRoutineComplete(
      planId: any(named: 'planId'),
      routineId: any(named: 'routineId'),
      workoutId: any(named: 'workoutId'),
      currentRoutines: any(named: 'currentRoutines'),
    ),
  ).thenAnswer((_) async => afterMarkPlan);

  final analytics = _FakeAnalyticsRepository();

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockAuth),
      weeklyPlanRepositoryProvider.overrideWithValue(mockRepo),
      analyticsRepositoryProvider.overrideWithValue(analytics),
      // Pre-warm the PR list with a synchronous future so `valueOrNull`
      // returns a concrete list (not null) when read during the event fire.
      prListProvider.overrideWith((ref) async => prList),
    ],
  );

  // Force the notifier to exist, then seed state directly.
  container.read(weeklyPlanProvider.notifier);
  container
      .read(weeklyPlanProvider.notifier)
      // ignore: invalid_use_of_protected_member
      .state = AsyncData(
    initialPlan,
  );

  return (container: container, analytics: analytics, mockRepo: mockRepo);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const BucketRoutine(routineId: 'fallback', order: 0));
    registerFallbackValue(<BucketRoutine>[]);
    registerFallbackValue(DateTime(2026));
  });

  group('WeeklyPlanNotifier.markRoutineComplete week_complete event', () {
    test(
      'fires week_complete when completing the final routine of the week',
      () async {
        // Start: 3 routines, 2 already complete, one pending.
        final before = _makePlan(
          routineIds: ['r-a', 'r-b', 'r-c'],
          completedIndices: {0, 1},
        );
        // After: all three complete.
        final after = _makePlan(
          routineIds: ['r-a', 'r-b', 'r-c'],
          completedIndices: {0, 1, 2},
        );

        final bundle = _makeContainer(
          initialPlan: before,
          afterMarkPlan: after,
        );
        addTearDown(bundle.container.dispose);

        // Warm up prListProvider so valueOrNull returns a concrete list.
        await bundle.container.read(prListProvider.future);

        await bundle.container
            .read(weeklyPlanProvider.notifier)
            .markRoutineComplete(routineId: 'r-c', workoutId: 'w-c');

        expect(bundle.analytics.events, hasLength(1));
        final event = bundle.analytics.events.single;
        expect(event, isA<AnalyticsEvent>());
        expect(event.name, 'week_complete');
        expect(event.props['sessions_completed'], 3);
        expect(event.props['plan_size'], 3);
        expect(event.props['pr_count_this_week'], 0);
        // week_number is computed from auth.user.createdAt (2026-01-01). We
        // only assert it is a positive ordinal number — the exact value
        // depends on DateTime.now() at run time, which is not the subject
        // of this test. See weekly_plan_provider_week_number_test.dart
        // for the deterministic coverage.
        expect(event.props['week_number'], isA<int>());
        expect(event.props['week_number'] as int, greaterThanOrEqualTo(1));
      },
    );

    test(
      'does NOT fire week_complete when completing a mid-plan routine',
      () async {
        // Start: 3 routines, none complete.
        final before = _makePlan(routineIds: ['r-a', 'r-b', 'r-c']);
        // After: one complete, two remaining.
        final after = _makePlan(
          routineIds: ['r-a', 'r-b', 'r-c'],
          completedIndices: {0},
        );

        final bundle = _makeContainer(
          initialPlan: before,
          afterMarkPlan: after,
        );
        addTearDown(bundle.container.dispose);

        await bundle.container
            .read(weeklyPlanProvider.notifier)
            .markRoutineComplete(routineId: 'r-a', workoutId: 'w-a');

        expect(bundle.analytics.events, isEmpty);
      },
    );

    test(
      'does NOT fire week_complete on already-complete plan (idempotent re-tap)',
      () async {
        // Already all complete — the markRoutineComplete guard in the
        // notifier should early-return before even reaching the event fire
        // (no incomplete routine matches `routineId`). This asserts the
        // transition guard's second layer of defense.
        final before = _makePlan(
          routineIds: ['r-a', 'r-b'],
          completedIndices: {0, 1},
        );
        final after = before; // No change expected.

        final bundle = _makeContainer(
          initialPlan: before,
          afterMarkPlan: after,
        );
        addTearDown(bundle.container.dispose);

        await bundle.container
            .read(weeklyPlanProvider.notifier)
            .markRoutineComplete(routineId: 'r-a', workoutId: 'w-a');

        expect(bundle.analytics.events, isEmpty);
      },
    );

    test('does NOT fire week_complete when no user is authenticated', () async {
      final before = _makePlan(routineIds: ['r-a'], completedIndices: <int>{});
      final after = _makePlan(routineIds: ['r-a'], completedIndices: {0});

      final bundle = _makeContainer(
        initialPlan: before,
        afterMarkPlan: after,
        user: null,
      );
      addTearDown(bundle.container.dispose);

      await bundle.container
          .read(weeklyPlanProvider.notifier)
          .markRoutineComplete(routineId: 'r-a', workoutId: 'w-a');

      expect(bundle.analytics.events, isEmpty);
    });

    test(
      'pr_count_this_week counts only PRs achieved within the week window',
      () async {
        final weekStart = DateTime(2026, 4, 6); // Monday
        final before = _makePlan(
          routineIds: ['r-a', 'r-b'],
          completedIndices: {0},
          weekStart: weekStart,
        );
        final after = _makePlan(
          routineIds: ['r-a', 'r-b'],
          completedIndices: {0, 1},
          weekStart: weekStart,
        );

        final prs = <PersonalRecord>[
          // Before the week — excluded.
          _makePR(id: 'pr-old', achievedAt: DateTime(2026, 4, 5, 23)),
          // Inside the week — included.
          _makePR(id: 'pr-mid', achievedAt: DateTime(2026, 4, 8, 12)),
          _makePR(id: 'pr-late', achievedAt: DateTime(2026, 4, 12, 9)),
          // On/after the following Monday — excluded (isBefore boundary).
          _makePR(id: 'pr-next', achievedAt: DateTime(2026, 4, 13, 0)),
        ];

        final bundle = _makeContainer(
          initialPlan: before,
          afterMarkPlan: after,
          prList: prs,
        );
        addTearDown(bundle.container.dispose);

        // Warm the PR list provider so valueOrNull is concrete.
        await bundle.container.read(prListProvider.future);

        await bundle.container
            .read(weeklyPlanProvider.notifier)
            .markRoutineComplete(routineId: 'r-b', workoutId: 'w-b');

        expect(bundle.analytics.events, hasLength(1));
        expect(bundle.analytics.events.single.props['pr_count_this_week'], 2);
      },
    );

    test(
      'fires only once when the notifier is already in the all-complete state',
      () async {
        // Set up a single-routine plan in the "just became complete" state
        // via a successful markRoutineComplete call, then verify a second
        // call on the now-complete plan is a no-op.
        final before = _makePlan(routineIds: ['r-a']);
        final after = _makePlan(routineIds: ['r-a'], completedIndices: {0});

        final bundle = _makeContainer(
          initialPlan: before,
          afterMarkPlan: after,
        );
        addTearDown(bundle.container.dispose);
        await bundle.container.read(prListProvider.future);

        await bundle.container
            .read(weeklyPlanProvider.notifier)
            .markRoutineComplete(routineId: 'r-a', workoutId: 'w-a');
        // Second call: the existing guard `hasMatch` will early-return since
        // all routines are now completed — so analytics is not touched.
        await bundle.container
            .read(weeklyPlanProvider.notifier)
            .markRoutineComplete(routineId: 'r-a', workoutId: 'w-a-2');

        expect(bundle.analytics.events, hasLength(1));
      },
    );
  });
}
