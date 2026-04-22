/// Unit tests for WeeklyPlanNotifier.addRoutineToPlan.
///
/// Covers:
/// - Returns true and appends the routine when the plan exists and the
///   routine is not already present.
/// - Returns false (no-op) when the routine is already in the plan.
/// - Returns false (no-op) when the plan state is null (no plan this week).
/// - Appended routine gets order = existing.length + 1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/auth/data/auth_repository.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:repsaga/features/weekly_plan/data/weekly_plan_repository.dart';
import 'package:repsaga/features/weekly_plan/providers/weekly_plan_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockWeeklyPlanRepository extends Mock implements WeeklyPlanRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A minimal [User] stub that satisfies [AuthRepository.currentUser].
const _fakeUser = User(
  id: 'user-001',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// Builds a [WeeklyPlan] with the given [routineIds] as [BucketRoutine]s.
WeeklyPlan _makePlan({List<String> routineIds = const []}) {
  final routines = routineIds
      .asMap()
      .entries
      .map((e) => BucketRoutine(routineId: e.value, order: e.key + 1))
      .toList();
  return WeeklyPlan(
    id: 'plan-001',
    userId: 'user-001',
    weekStart: DateTime(2026, 4, 7),
    routines: routines,
    createdAt: DateTime(2026, 4, 7),
    updatedAt: DateTime(2026, 4, 7),
  );
}

/// Creates a [ProviderContainer] with the weekly plan pre-seeded to [plan].
///
/// The auth repository mock returns a null user so `build()` returns null,
/// but we override the initial state immediately after construction.
ProviderContainer _makeContainer({
  required WeeklyPlan? initialPlan,
  required _MockWeeklyPlanRepository mockRepo,
}) {
  final mockAuth = _MockAuthRepository();
  when(() => mockAuth.currentUser).thenReturn(null);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockAuth),
      weeklyPlanRepositoryProvider.overrideWithValue(mockRepo),
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

  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    // Register fallback values for mocktail argument matchers.
    registerFallbackValue(const BucketRoutine(routineId: 'fallback', order: 0));
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<BucketRoutine>[]);
  });

  group('WeeklyPlanNotifier.addRoutineToPlan', () {
    late _MockWeeklyPlanRepository mockRepo;

    setUp(() {
      mockRepo = _MockWeeklyPlanRepository();
    });

    test('returns false immediately when plan state is null', () async {
      final container = _makeContainer(initialPlan: null, mockRepo: mockRepo);
      addTearDown(container.dispose);

      final result = await container
          .read(weeklyPlanProvider.notifier)
          .addRoutineToPlan('routine-x');

      expect(result, isFalse);
      verifyNever(
        () => mockRepo.upsertPlan(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
          routines: any(named: 'routines'),
        ),
      );
    });

    test('returns false when routine is already present in the plan', () async {
      final plan = _makePlan(routineIds: ['routine-a', 'routine-b']);
      final container = _makeContainer(initialPlan: plan, mockRepo: mockRepo);
      addTearDown(container.dispose);

      final result = await container
          .read(weeklyPlanProvider.notifier)
          .addRoutineToPlan('routine-a');

      expect(result, isFalse);
      verifyNever(
        () => mockRepo.upsertPlan(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
          routines: any(named: 'routines'),
        ),
      );
    });

    test(
      'returns false when a second duplicate routine id is checked',
      () async {
        final plan = _makePlan(routineIds: ['routine-a']);
        final container = _makeContainer(initialPlan: plan, mockRepo: mockRepo);
        addTearDown(container.dispose);

        final result = await container
            .read(weeklyPlanProvider.notifier)
            .addRoutineToPlan('routine-a');

        expect(result, isFalse);
      },
    );

    test(
      'calls upsertPlan and returns true when routine is not in the plan',
      () async {
        final plan = _makePlan(routineIds: ['routine-a', 'routine-b']);
        final updatedPlan = _makePlan(
          routineIds: ['routine-a', 'routine-b', 'routine-c'],
        );

        // Auth mock must return a non-null user so the notifier's upsertPlan()
        // does not bail out at the `if (userId == null) return;` guard.
        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.currentUser).thenReturn(_fakeUser);

        when(
          () => mockRepo.upsertPlan(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
            routines: any(named: 'routines'),
          ),
        ).thenAnswer((_) async => updatedPlan);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            weeklyPlanRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);
        container.read(weeklyPlanProvider.notifier);
        // ignore: invalid_use_of_protected_member
        container.read(weeklyPlanProvider.notifier).state = AsyncData(plan);

        final result = await container
            .read(weeklyPlanProvider.notifier)
            .addRoutineToPlan('routine-c');

        expect(result, isTrue);
      },
    );

    test(
      'new routine is appended with order = existing routines count + 1',
      () async {
        // Plan has 2 routines (order 1 and 2); new one should get order 3.
        final plan = _makePlan(routineIds: ['routine-a', 'routine-b']);

        List<BucketRoutine>? capturedRoutines;

        final updatedPlan = _makePlan(
          routineIds: ['routine-a', 'routine-b', 'routine-new'],
        );

        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.currentUser).thenReturn(_fakeUser);

        when(
          () => mockRepo.upsertPlan(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
            routines: any(named: 'routines'),
          ),
        ).thenAnswer((invocation) async {
          capturedRoutines =
              invocation.namedArguments[const Symbol('routines')]
                  as List<BucketRoutine>;
          return updatedPlan;
        });

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            weeklyPlanRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);
        container.read(weeklyPlanProvider.notifier);
        // ignore: invalid_use_of_protected_member
        container.read(weeklyPlanProvider.notifier).state = AsyncData(plan);

        await container
            .read(weeklyPlanProvider.notifier)
            .addRoutineToPlan('routine-new');

        expect(capturedRoutines, isNotNull);
        final newEntry = capturedRoutines!.last;
        expect(newEntry.routineId, 'routine-new');
        // order should be existing count (2) + 1 = 3
        expect(newEntry.order, 3);
      },
    );

    test(
      'new routine gets order 1 when plan has no existing routines',
      () async {
        final plan = _makePlan(routineIds: []);

        List<BucketRoutine>? capturedRoutines;
        final updatedPlan = _makePlan(routineIds: ['routine-only']);

        final mockAuth = _MockAuthRepository();
        when(() => mockAuth.currentUser).thenReturn(_fakeUser);

        when(
          () => mockRepo.upsertPlan(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
            routines: any(named: 'routines'),
          ),
        ).thenAnswer((invocation) async {
          capturedRoutines =
              invocation.namedArguments[const Symbol('routines')]
                  as List<BucketRoutine>;
          return updatedPlan;
        });

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            weeklyPlanRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);
        container.read(weeklyPlanProvider.notifier);
        // ignore: invalid_use_of_protected_member
        container.read(weeklyPlanProvider.notifier).state = AsyncData(plan);

        await container
            .read(weeklyPlanProvider.notifier)
            .addRoutineToPlan('routine-only');

        expect(capturedRoutines, isNotNull);
        expect(capturedRoutines!.single.order, 1);
      },
    );
  });
}
