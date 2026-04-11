import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/data/base_repository.dart';
import 'package:gymbuddy_app/features/analytics/data/analytics_repository.dart';
import 'package:gymbuddy_app/features/analytics/data/models/analytics_event.dart';
import 'package:gymbuddy_app/features/analytics/providers/analytics_providers.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_local_storage.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/routine_start_config.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
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

class _MockProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async =>
      const Profile(id: 'user-test-001', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User fakeUser({String id = 'user-test-001'}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    isAnonymous: false,
  );
}

Workout makeWorkout({String? id, bool isActive = true}) {
  return Workout.fromJson(
    TestWorkoutFactory.create(id: id, isActive: isActive),
  );
}

Exercise makeExercise({
  String id = 'exercise-001',
  String name = 'Bench Press',
}) {
  return Exercise.fromJson(TestExerciseFactory.create(id: id, name: name));
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
      profileProvider.overrideWith(() => _MockProfileNotifier()),
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

  group('ActiveWorkoutNotifier — startFromRoutine', () {
    test('creates workout with routine name and correct exercises', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) = _makeContainer();
      addTearDown(container.dispose);

      final createdWorkout = makeWorkout(id: 'workout-routine');
      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.createActiveWorkout(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => createdWorkout);
      when(
        () => mockRepo.getLastWorkoutSets(any()),
      ).thenAnswer((_) async => {});

      final bench = makeExercise(id: 'ex-bench', name: 'Bench Press');
      final ohp = makeExercise(id: 'ex-ohp', name: 'OHP');

      final config = RoutineStartConfig(
        routineName: 'Push Day',
        exercises: [
          RoutineStartExercise(
            exerciseId: 'ex-bench',
            exercise: bench,
            setCount: 3,
            targetReps: 10,
            restSeconds: 90,
          ),
          RoutineStartExercise(
            exerciseId: 'ex-ohp',
            exercise: ohp,
            setCount: 2,
            targetReps: 8,
            restSeconds: 120,
          ),
        ],
      );

      await container.read(activeWorkoutProvider.future);
      await container
          .read(activeWorkoutProvider.notifier)
          .startFromRoutine(config);

      final result = container.read(activeWorkoutProvider);
      expect(result, isA<AsyncData<ActiveWorkoutState?>>());

      final state = result.value!;
      expect(state.exercises, hasLength(2));

      // First exercise: Bench Press with 3 sets
      final ex0 = state.exercises[0];
      expect(ex0.workoutExercise.exerciseId, 'ex-bench');
      expect(ex0.workoutExercise.restSeconds, 90);
      expect(ex0.workoutExercise.order, 0);
      expect(ex0.sets, hasLength(3));
      expect(ex0.sets[0].reps, 10); // targetReps
      expect(ex0.sets[0].setNumber, 1);

      // Second exercise: OHP with 2 sets
      final ex1 = state.exercises[1];
      expect(ex1.workoutExercise.exerciseId, 'ex-ohp');
      expect(ex1.workoutExercise.restSeconds, 120);
      expect(ex1.workoutExercise.order, 1);
      expect(ex1.sets, hasLength(2));
      expect(ex1.sets[0].reps, 8); // targetReps

      verify(
        () => mockRepo.createActiveWorkout(
          userId: 'user-test-001',
          name: 'Push Day',
        ),
      ).called(1);
    });

    test('pre-fills weights from last session', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) = _makeContainer();
      addTearDown(container.dispose);

      final createdWorkout = makeWorkout(id: 'workout-prefill');
      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.createActiveWorkout(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => createdWorkout);

      // Simulate last-session data: 3 sets of bench at 80kg
      final previousSets = [
        ExerciseSet.fromJson(
          TestSetFactory.create(
            id: 'prev-1',
            setNumber: 1,
            weight: 80.0,
            reps: 10,
          ),
        ),
        ExerciseSet.fromJson(
          TestSetFactory.create(
            id: 'prev-2',
            setNumber: 2,
            weight: 82.5,
            reps: 9,
          ),
        ),
      ];
      when(
        () => mockRepo.getLastWorkoutSets(any()),
      ).thenAnswer((_) async => {'ex-bench': previousSets});

      final bench = makeExercise(id: 'ex-bench', name: 'Bench Press');
      final config = RoutineStartConfig(
        routineName: 'Push Day',
        exercises: [
          RoutineStartExercise(
            exerciseId: 'ex-bench',
            exercise: bench,
            setCount: 3,
            targetReps: 10,
            restSeconds: 90,
          ),
        ],
      );

      await container.read(activeWorkoutProvider.future);
      await container
          .read(activeWorkoutProvider.notifier)
          .startFromRoutine(config);

      final state = container.read(activeWorkoutProvider).value!;
      final sets = state.exercises[0].sets;

      // Set 0 uses previous set 0 weight
      expect(sets[0].weight, 80.0);
      // Set 1 uses previous set 1 weight
      expect(sets[1].weight, 82.5);
      // Set 2 has no matching previous set index, so uses last previous set
      expect(sets[2].weight, 82.5);
    });

    test('handles missing last-session data gracefully', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) = _makeContainer();
      addTearDown(container.dispose);

      final createdWorkout = makeWorkout(id: 'workout-no-prev');
      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.createActiveWorkout(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => createdWorkout);
      when(
        () => mockRepo.getLastWorkoutSets(any()),
      ).thenAnswer((_) async => {}); // empty — no previous data

      final bench = makeExercise(id: 'ex-bench', name: 'Bench Press');
      final config = RoutineStartConfig(
        routineName: 'Push Day',
        exercises: [
          RoutineStartExercise(
            exerciseId: 'ex-bench',
            exercise: bench,
            setCount: 2,
            targetReps: 10,
            restSeconds: 90,
          ),
        ],
      );

      await container.read(activeWorkoutProvider.future);
      await container
          .read(activeWorkoutProvider.notifier)
          .startFromRoutine(config);

      final state = container.read(activeWorkoutProvider).value!;
      final sets = state.exercises[0].sets;

      // Falls back to equipment-type defaults (barbell: 20kg) and targetReps
      expect(sets[0].weight, 20.0);
      expect(sets[0].reps, 10);
      expect(sets[1].weight, 20.0);
      expect(sets[1].reps, 10);
      expect(sets[0].isCompleted, false);
    });

    test('sets have correct sequential setNumber starting from 1', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) = _makeContainer();
      addTearDown(container.dispose);

      final createdWorkout = makeWorkout(id: 'workout-sn');
      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.createActiveWorkout(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => createdWorkout);
      when(
        () => mockRepo.getLastWorkoutSets(any()),
      ).thenAnswer((_) async => {});

      final bench = makeExercise(id: 'ex-bench', name: 'Bench');
      final config = RoutineStartConfig(
        routineName: 'Test',
        exercises: [
          RoutineStartExercise(
            exerciseId: 'ex-bench',
            exercise: bench,
            setCount: 4,
          ),
        ],
      );

      await container.read(activeWorkoutProvider.future);
      await container
          .read(activeWorkoutProvider.notifier)
          .startFromRoutine(config);

      final sets = container
          .read(activeWorkoutProvider)
          .value!
          .exercises[0]
          .sets;
      expect(sets.map((s) => s.setNumber).toList(), [1, 2, 3, 4]);
    });
  });
}
