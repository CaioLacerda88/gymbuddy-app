import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/models/workout_exercise.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

User fakeUser({String id = 'user-test-001'}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026).toIso8601String(),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sentinel to distinguish "caller passed null" from "caller didn't pass
/// anything" -- needed because TestSetFactory defaults weight to 60.0 and
/// reps to 10 when the parameter is null.
const _unset = Object();

/// Build an [ExerciseSet] with explicit control over null weight/reps.
///
/// Pass `weight: null` (explicitly) to get a set with null weight. Omit
/// the parameter entirely to get the factory default (60.0).
ExerciseSet makeSet({
  String? id,
  String? workoutExerciseId,
  int? setNumber,
  Object? reps = _unset,
  Object? weight = _unset,
  bool isCompleted = true,
}) {
  final map = <String, dynamic>{
    'id': id ?? 'set-${DateTime.now().microsecondsSinceEpoch}',
    'workout_exercise_id': workoutExerciseId ?? 'we-001',
    'set_number': setNumber ?? 1,
    'reps': reps == _unset ? 10 : reps,
    'weight': weight == _unset ? 60.0 : weight,
    'set_type': 'working',
    'is_completed': isCompleted,
    'created_at': '2026-01-01T10:05:00Z',
  };
  return ExerciseSet.fromJson(map);
}

/// Build a [WorkoutDetail] with the given sets grouped under one exercise.
WorkoutDetail makeWorkoutDetail({
  required List<ExerciseSet> sets,
  String workoutExerciseId = 'we-001',
}) {
  final workout = Workout.fromJson(TestWorkoutFactory.create());
  final we = WorkoutExercise.fromJson(
    TestWorkoutExerciseFactory.create(id: workoutExerciseId),
  );
  return (
    workout: workout,
    exercises: [we],
    setsByExercise: {workoutExerciseId: sets},
  );
}

// ---------------------------------------------------------------------------
// Notifier stubs (for lastSessionProvider tests)
// ---------------------------------------------------------------------------

class _WorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  _WorkoutHistoryNotifier(this.workouts);
  final List<Workout> workouts;

  @override
  Future<List<Workout>> build() async => workouts;

  @override
  bool get hasMore => false;

  @override
  bool get isLoadingMore => false;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

class _EmptyWorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  @override
  Future<List<Workout>> build() async => [];

  @override
  bool get hasMore => false;

  @override
  bool get isLoadingMore => false;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('lastSessionProvider', () {
    test('returns null when workout history is empty', () async {
      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _EmptyWorkoutHistoryNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the async notifier to build.
      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNull);
    });

    test(
      'returns workout name and relative date for most recent workout',
      () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final workout = Workout.fromJson(
          TestWorkoutFactory.create(
            name: 'Push Day',
            finishedAt: yesterday.toIso8601String(),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            workoutHistoryProvider.overrideWith(
              () => _WorkoutHistoryNotifier([workout]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(workoutHistoryProvider.future);

        final lastSession = container.read(lastSessionProvider);
        expect(lastSession, isNotNull);
        expect(lastSession!.name, 'Push Day');
        expect(lastSession.relativeDate, 'Yesterday');
      },
    );

    test('returns "Today" for same-day workout', () async {
      final now = DateTime.now();
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Leg Day',
          finishedAt: now.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      expect(lastSession!.relativeDate, 'Today');
    });

    test('returns "3 days ago" for workout 3 days old', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Pull Day',
          finishedAt: threeDaysAgo.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      expect(lastSession!.relativeDate, '3 days ago');
      expect(lastSession.name, 'Pull Day');
    });

    test('uses finishedAt over startedAt when both present', () async {
      final now = DateTime.now();
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Upper Body',
          startedAt: now.subtract(const Duration(days: 5)).toIso8601String(),
          finishedAt: now.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      // Should use finishedAt (today), not startedAt (5 days ago).
      expect(lastSession!.relativeDate, 'Today');
    });

    test('returns "1w ago" for workout exactly 7 days old', () async {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Back Day',
          finishedAt: sevenDaysAgo.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      expect(lastSession!.relativeDate, '1w ago');
    });

    test('returns "2w ago" for workout 14 days old', () async {
      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Chest Day',
          finishedAt: fourteenDaysAgo.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      expect(lastSession!.relativeDate, '2w ago');
    });

    test('returns "1mo ago" for workout 30 days old', () async {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Shoulders',
          finishedAt: thirtyDaysAgo.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      expect(lastSession!.relativeDate, '1mo ago');
    });

    test('returns "3mo ago" for workout 90 days old', () async {
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(
          name: 'Arms',
          finishedAt: ninetyDaysAgo.toIso8601String(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier([workout]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workoutHistoryProvider.future);

      final lastSession = container.read(lastSessionProvider);
      expect(lastSession, isNotNull);
      expect(lastSession!.relativeDate, '3mo ago');
    });
  });

  group('weekVolumeProvider (override-based)', () {
    test('returns overridden value', () async {
      final container = ProviderContainer(
        overrides: [
          weekVolumeProvider.overrideWith((ref) => Future.value(12400.0)),
        ],
      );
      addTearDown(container.dispose);

      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 12400.0);
    });

    test('returns 0 when overridden with 0', () async {
      final container = ProviderContainer(
        overrides: [weekVolumeProvider.overrideWith((ref) => Future.value(0))],
      );
      addTearDown(container.dispose);

      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 0);
    });
  });

  group('weekVolumeProvider (calculation logic)', () {
    late MockWorkoutRepository mockRepo;
    late MockAuthRepository mockAuth;

    setUp(() {
      mockRepo = MockWorkoutRepository();
      mockAuth = MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(fakeUser());
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(mockRepo),
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('sums weight * reps for completed sets', () async {
      // 3 sets: 60kg x 10, 80kg x 8, 100kg x 5 = 600 + 640 + 500 = 1740
      final detail = makeWorkoutDetail(
        sets: [
          makeSet(id: 's1', setNumber: 1, weight: 60, reps: 10),
          makeSet(id: 's2', setNumber: 2, weight: 80, reps: 8),
          makeSet(id: 's3', setNumber: 3, weight: 100, reps: 5),
        ],
      );

      when(
        () => mockRepo.getFinishedWorkoutsSince(any(), any()),
      ).thenAnswer((_) async => [detail]);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 1740.0);
    });

    test('only counts completed sets (isCompleted: false excluded)', () async {
      // 2 completed (60x10=600, 80x8=640), 1 incomplete (100x5=skipped)
      final detail = makeWorkoutDetail(
        sets: [
          makeSet(id: 's1', setNumber: 1, weight: 60, reps: 10),
          makeSet(id: 's2', setNumber: 2, weight: 80, reps: 8),
          makeSet(
            id: 's3',
            setNumber: 3,
            weight: 100,
            reps: 5,
            isCompleted: false,
          ),
        ],
      );

      when(
        () => mockRepo.getFinishedWorkoutsSince(any(), any()),
      ).thenAnswer((_) async => [detail]);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 1240.0);
    });

    test('null weight contributes 0 volume', () async {
      // null weight x 10 reps = 0, 60 x 10 = 600
      final detail = makeWorkoutDetail(
        sets: [
          makeSet(id: 's1', setNumber: 1, weight: null, reps: 10),
          makeSet(id: 's2', setNumber: 2, weight: 60, reps: 10),
        ],
      );

      when(
        () => mockRepo.getFinishedWorkoutsSince(any(), any()),
      ).thenAnswer((_) async => [detail]);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 600.0);
    });

    test('null reps contributes 0 volume', () async {
      // 60 x null = 0, 80 x 5 = 400
      final detail = makeWorkoutDetail(
        sets: [
          makeSet(id: 's1', setNumber: 1, weight: 60, reps: null),
          makeSet(id: 's2', setNumber: 2, weight: 80, reps: 5),
        ],
      );

      when(
        () => mockRepo.getFinishedWorkoutsSince(any(), any()),
      ).thenAnswer((_) async => [detail]);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 400.0);
    });

    test('empty workouts returns 0', () async {
      when(
        () => mockRepo.getFinishedWorkoutsSince(any(), any()),
      ).thenAnswer((_) async => []);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 0.0);
    });

    test('returns 0 when user is not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 0.0);

      // Should never call the repository.
      verifyNever(() => mockRepo.getFinishedWorkoutsSince(any(), any()));
    });

    test('sums across multiple workouts', () async {
      // Workout 1: 60x10 = 600
      final detail1 = makeWorkoutDetail(
        workoutExerciseId: 'we-001',
        sets: [makeSet(id: 's1', setNumber: 1, weight: 60, reps: 10)],
      );
      // Workout 2: 80x5 = 400
      final detail2 = makeWorkoutDetail(
        workoutExerciseId: 'we-002',
        sets: [
          makeSet(
            id: 's2',
            workoutExerciseId: 'we-002',
            setNumber: 1,
            weight: 80,
            reps: 5,
          ),
        ],
      );

      when(
        () => mockRepo.getFinishedWorkoutsSince(any(), any()),
      ).thenAnswer((_) async => [detail1, detail2]);

      final container = makeContainer();
      final volume = await container.read(weekVolumeProvider.future);
      expect(volume, 1000.0);
    });
  });
}
