// Tests that expose BUG-004: startFromRoutine uses weight=0 for first-time
// exercises instead of equipment-type smart defaults.
//
// When there is no previous session data for an exercise, the manual "Add Set"
// path in the active workout screen calls defaultSetValues(equipmentType,
// weightUnit) to supply sensible starting weights (e.g., 20 kg for barbell,
// 10 kg for dumbbell). The startFromRoutine path does not apply this same
// logic — it hard-codes `weight: prev?.weight ?? 0`.
//
// This test documents the expected behaviour (smart defaults) and will fail
// until the notifier is fixed to apply defaultSetValues as the final fallback.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/data/base_repository.dart';
import 'package:repsaga/features/analytics/data/analytics_repository.dart';
import 'package:repsaga/features/analytics/data/models/analytics_event.dart';
import 'package:repsaga/features/analytics/providers/analytics_providers.dart';
import 'package:repsaga/features/auth/data/auth_repository.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/workouts/data/workout_local_storage.dart';
import 'package:repsaga/features/workouts/data/workout_repository.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/routine_start_config.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/models/weight_unit.dart';
import 'package:repsaga/features/workouts/providers/workout_providers.dart';
import 'package:repsaga/features/workouts/utils/set_defaults.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../fixtures/test_factories.dart';

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockWorkoutLocalStorage extends Mock implements WorkoutLocalStorage {}

class MockAuthRepository extends Mock implements AuthRepository {}

class FakeActiveWorkoutState extends Fake implements ActiveWorkoutState {}

/// No-op analytics repo used in unit tests — avoids hitting
/// `Supabase.instance` while still letting the notifier call `insertEvent`.
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

User _fakeUser() => const User(
  id: 'user-001',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  isAnonymous: false,
);

Workout _makeWorkout() =>
    Workout.fromJson(TestWorkoutFactory.create(isActive: true));

Exercise _makeExercise(String equipmentType, {String id = 'ex-001'}) {
  return Exercise.fromJson(
    TestExerciseFactory.create(id: id, equipmentType: equipmentType),
  );
}

({
  ProviderContainer container,
  MockWorkoutRepository mockRepo,
  MockWorkoutLocalStorage mockStorage,
  MockAuthRepository mockAuth,
})
_makeContainer() {
  final mockRepo = MockWorkoutRepository();
  final mockStorage = MockWorkoutLocalStorage();
  final mockAuth = MockAuthRepository();

  when(() => mockStorage.loadActiveWorkout()).thenReturn(null);
  when(() => mockStorage.saveActiveWorkout(any())).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(mockRepo),
      workoutLocalStorageProvider.overrideWithValue(mockStorage),
      authRepositoryProvider.overrideWithValue(mockAuth),
      analyticsRepositoryProvider.overrideWithValue(
        const _FakeAnalyticsRepository(),
      ),
    ],
  );
  return (
    container: container,
    mockRepo: mockRepo,
    mockStorage: mockStorage,
    mockAuth: mockAuth,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActiveWorkoutState());
  });

  group('ActiveWorkoutNotifier.startFromRoutine — smart defaults (BUG-004)', () {
    test(
      'barbell exercise with no previous data should use 20 kg default, not 0',
      () async {
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            _makeContainer();
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => _makeWorkout());
        // No previous session data for this exercise
        when(
          () => mockRepo.getLastWorkoutSets(any()),
        ).thenAnswer((_) async => {});

        final barbellExercise = _makeExercise('barbell');
        final config = RoutineStartConfig(
          routineName: 'Push Day',
          exercises: [
            RoutineStartExercise(
              exerciseId: barbellExercise.id,
              exercise: barbellExercise,
              setCount: 3,
            ),
          ],
        );

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startFromRoutine(config);

        final state = container.read(activeWorkoutProvider).value!;
        final sets = state.exercises[0].sets;

        // Expected smart default for barbell in kg (WeightUnit.kg is the default)
        final expected = defaultSetValues(EquipmentType.barbell, WeightUnit.kg);

        // BUG-004: currently weight is 0 because startFromRoutine does not call
        // defaultSetValues. This assertion FAILS until the bug is fixed.
        expect(
          sets[0].weight,
          expected.weight,
          reason:
              'BUG-004: barbell exercise with no previous data should default to '
              '${expected.weight} kg (equipment smart default), not 0.',
        );
        expect(sets[0].reps, expected.reps);
        expect(sets[1].weight, expected.weight);
        expect(sets[2].weight, expected.weight);
      },
    );

    test(
      'dumbbell exercise with no previous data should use 10 kg default, not 0',
      () async {
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            _makeContainer();
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => _makeWorkout());
        when(
          () => mockRepo.getLastWorkoutSets(any()),
        ).thenAnswer((_) async => {});

        final dumbbellExercise = _makeExercise('dumbbell');
        final config = RoutineStartConfig(
          routineName: 'Arm Day',
          exercises: [
            RoutineStartExercise(
              exerciseId: dumbbellExercise.id,
              exercise: dumbbellExercise,
              setCount: 2,
            ),
          ],
        );

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startFromRoutine(config);

        final state = container.read(activeWorkoutProvider).value!;
        final sets = state.exercises[0].sets;

        final expected = defaultSetValues(
          EquipmentType.dumbbell,
          WeightUnit.kg,
        );

        // BUG-004: currently 0, should be 10 kg
        expect(
          sets[0].weight,
          expected.weight,
          reason:
              'BUG-004: dumbbell exercise with no previous data should default '
              'to ${expected.weight} kg, not 0.',
        );
      },
    );

    test(
      'bodyweight exercise with no previous data correctly uses weight 0',
      () async {
        // Bodyweight exercises have weight=0 by design — smart defaults also
        // return 0. This test verifies the correct behavior is preserved whether
        // or not BUG-004 fix is applied.
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            _makeContainer();
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => _makeWorkout());
        when(
          () => mockRepo.getLastWorkoutSets(any()),
        ).thenAnswer((_) async => {});

        final bwExercise = _makeExercise('bodyweight');
        final config = RoutineStartConfig(
          routineName: 'Calisthenics',
          exercises: [
            RoutineStartExercise(
              exerciseId: bwExercise.id,
              exercise: bwExercise,
              setCount: 2,
              targetReps: 15,
            ),
          ],
        );

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startFromRoutine(config);

        final state = container.read(activeWorkoutProvider).value!;
        final sets = state.exercises[0].sets;

        // Bodyweight: weight=0 is always correct (no change needed for this type).
        expect(sets[0].weight, 0.0);
        expect(sets[0].reps, 15); // targetReps
      },
    );

    test(
      'exercise with previous session data uses previous weight (regression guard)',
      () async {
        // Regression guard: when previous data exists, it must still be preferred
        // over smart defaults. The BUG-004 fix must not break this.
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            _makeContainer();
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => _makeWorkout());

        // Simulate previous session: 100 kg sets
        final previousSets = [
          ExerciseSet.fromJson(
            TestSetFactory.create(
              id: 'prev-1',
              setNumber: 1,
              weight: 100.0,
              reps: 5,
              workoutExerciseId: 'we-prev',
            ),
          ),
        ];
        when(
          () => mockRepo.getLastWorkoutSets(any()),
        ).thenAnswer((_) async => {'ex-001': previousSets});

        final barbellExercise = _makeExercise('barbell');
        final config = RoutineStartConfig(
          routineName: 'Push Day',
          exercises: [
            RoutineStartExercise(
              exerciseId: barbellExercise.id,
              exercise: barbellExercise,
              setCount: 2,
            ),
          ],
        );

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startFromRoutine(config);

        final state = container.read(activeWorkoutProvider).value!;
        final sets = state.exercises[0].sets;

        // Previous data (100 kg) should take precedence over any default.
        expect(
          sets[0].weight,
          100.0,
          reason:
              'Previous session weight should be preferred over smart defaults.',
        );
      },
    );

    test(
      'machine exercise with no previous data should use 20 kg default, not 0',
      () async {
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            _makeContainer();
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => _makeWorkout());
        when(
          () => mockRepo.getLastWorkoutSets(any()),
        ).thenAnswer((_) async => {});

        final machineExercise = _makeExercise('machine');
        final config = RoutineStartConfig(
          routineName: 'Machine Day',
          exercises: [
            RoutineStartExercise(
              exerciseId: machineExercise.id,
              exercise: machineExercise,
              setCount: 1,
            ),
          ],
        );

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startFromRoutine(config);

        final state = container.read(activeWorkoutProvider).value!;
        final sets = state.exercises[0].sets;

        final expected = defaultSetValues(EquipmentType.machine, WeightUnit.kg);

        // BUG-004: currently 0, should be 20 kg
        expect(
          sets[0].weight,
          expected.weight,
          reason:
              'BUG-004: machine exercise with no previous data should default to '
              '${expected.weight} kg, not 0.',
        );
      },
    );
  });
}
