import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/exercises/models/progress_point.dart';
import 'package:gymbuddy_app/features/exercises/providers/exercise_progress_provider.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _MockWorkoutRepository extends Mock implements WorkoutRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

User _fakeUser({String id = 'user-test'}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026).toIso8601String(),
);

ExerciseSet _set({
  String id = 'set-001',
  double? weight = 100,
  int? reps = 5,
  SetType setType = SetType.working,
  bool isCompleted = true,
}) {
  return ExerciseSet(
    id: id,
    workoutExerciseId: 'we-001',
    setNumber: 1,
    weight: weight,
    reps: reps,
    setType: setType,
    isCompleted: isCompleted,
    createdAt: DateTime(2026),
  );
}

({DateTime finishedAt, List<ExerciseSet> sets}) _row(
  DateTime finishedAt,
  List<ExerciseSet> sets,
) => (finishedAt: finishedAt, sets: sets);

void main() {
  group('buildProgressPoints', () {
    test('empty input → empty output', () {
      expect(buildProgressPoints(const []), isEmpty);
    });

    test('single session → one point at max completed working set weight', () {
      final points = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: 80, reps: 10),
          _set(id: 'b', weight: 100, reps: 5),
          _set(id: 'c', weight: 90, reps: 8),
        ]),
      ]);

      expect(points, hasLength(1));
      expect(points.first.weight, 100);
      expect(points.first.sessionReps, 5);
    });

    test('warmup, dropset, failure, incomplete sets are excluded', () {
      final points = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: 200, reps: 5, setType: SetType.warmup),
          _set(id: 'b', weight: 180, reps: 5, setType: SetType.dropset),
          _set(id: 'c', weight: 170, reps: 5, setType: SetType.failure),
          _set(id: 'd', weight: 150, reps: 5, isCompleted: false),
          _set(id: 'e', weight: 100, reps: 5),
        ]),
      ]);

      expect(points, hasLength(1));
      expect(points.first.weight, 100);
    });

    test('zero-weight working sets are skipped (bodyweight-only case)', () {
      final points = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: 0, reps: 12),
        ]),
      ]);

      expect(points, isEmpty);
    });

    test('multiple sessions same calendar day → one point at max weight', () {
      final morning = DateTime.utc(2026, 3, 1, 8);
      final evening = DateTime.utc(2026, 3, 1, 19);
      final points = buildProgressPoints([
        _row(morning, [_set(id: 'a', weight: 80, reps: 10)]),
        _row(evening, [_set(id: 'b', weight: 110, reps: 6)]),
      ]);

      expect(points, hasLength(1));
      expect(points.first.weight, 110);
      expect(points.first.sessionReps, 6);
    });

    test('multiple days → sorted ascending by date', () {
      final points = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 10, 12), [_set(weight: 105)]),
        _row(DateTime.utc(2026, 3, 1, 12), [_set(weight: 100)]),
        _row(DateTime.utc(2026, 3, 5, 12), [_set(weight: 102)]),
      ]);

      expect(points.map((p) => p.weight).toList(), [100, 102, 105]);
    });

    test('session with only disqualified sets produces no point', () {
      final points = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 12), [
          _set(setType: SetType.warmup),
          _set(isCompleted: false),
        ]),
        _row(DateTime.utc(2026, 3, 2, 12), [_set(weight: 90)]),
      ]);

      expect(points, hasLength(1));
      expect(points.first.weight, 90);
    });
  });

  group('exerciseProgressProvider', () {
    late _MockWorkoutRepository mockRepo;
    late _MockAuthRepository mockAuth;

    setUpAll(() {
      registerFallbackValue(DateTime(2026));
    });

    setUp(() {
      mockRepo = _MockWorkoutRepository();
      mockAuth = _MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(_fakeUser());
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(mockRepo),
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns empty list when user is not signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      final container = buildContainer();

      final points = await container.read(
        exerciseProgressProvider(
          const ExerciseProgressKey(
            exerciseId: 'ex-1',
            window: TimeWindow.last90Days,
          ),
        ).future,
      );

      expect(points, isEmpty);
      verifyNever(
        () => mockRepo.getExerciseHistory(
          any(),
          userId: any(named: 'userId'),
          since: any(named: 'since'),
        ),
      );
    });

    test('last90Days window passes a non-null since to the repo', () async {
      when(
        () => mockRepo.getExerciseHistory(
          any(),
          userId: any(named: 'userId'),
          since: any(named: 'since'),
        ),
      ).thenAnswer((_) async => []);

      final container = buildContainer();
      await container.read(
        exerciseProgressProvider(
          const ExerciseProgressKey(
            exerciseId: 'ex-1',
            window: TimeWindow.last90Days,
          ),
        ).future,
      );

      final captured = verify(
        () => mockRepo.getExerciseHistory(
          'ex-1',
          userId: 'user-test',
          since: captureAny(named: 'since'),
        ),
      ).captured;
      expect(captured.single, isNotNull);
      final since = captured.single as DateTime;
      final now = DateTime.now();
      // Should be ~90 days ago; allow generous tolerance for test time drift.
      expect(now.difference(since).inDays, inInclusiveRange(89, 91));
    });

    test('allTime window passes null since to the repo', () async {
      when(
        () => mockRepo.getExerciseHistory(
          any(),
          userId: any(named: 'userId'),
          since: any(named: 'since'),
        ),
      ).thenAnswer((_) async => []);

      final container = buildContainer();
      await container.read(
        exerciseProgressProvider(
          const ExerciseProgressKey(
            exerciseId: 'ex-1',
            window: TimeWindow.allTime,
          ),
        ).future,
      );

      verify(
        () => mockRepo.getExerciseHistory(
          'ex-1',
          userId: 'user-test',
          since: null,
        ),
      ).called(1);
    });

    test(
      'transforms repo rows into progress points with same-day dedupe',
      () async {
        final day1 = DateTime.utc(2026, 2, 1, 10);
        final day1Evening = DateTime.utc(2026, 2, 1, 20);
        final day2 = DateTime.utc(2026, 2, 10, 10);

        when(
          () => mockRepo.getExerciseHistory(
            any(),
            userId: any(named: 'userId'),
            since: any(named: 'since'),
          ),
        ).thenAnswer(
          (_) async => [
            (finishedAt: day1, sets: [_set(weight: 80, reps: 10)]),
            (finishedAt: day1Evening, sets: [_set(weight: 95, reps: 6)]),
            (finishedAt: day2, sets: [_set(weight: 100, reps: 5)]),
          ],
        );

        final container = buildContainer();
        final points = await container.read(
          exerciseProgressProvider(
            const ExerciseProgressKey(
              exerciseId: 'ex-1',
              window: TimeWindow.allTime,
            ),
          ).future,
        );

        expect(points, hasLength(2));
        expect(points[0].weight, 95);
        expect(points[1].weight, 100);
      },
    );

    test('ProgressPoint equality via generated Freezed code', () {
      final a = ProgressPoint(
        date: DateTime(2026, 3, 1),
        weight: 100,
        sessionReps: 5,
      );
      final b = ProgressPoint(
        date: DateTime(2026, 3, 1),
        weight: 100,
        sessionReps: 5,
      );
      expect(a, equals(b));
    });
  });

  group('buildProgressPoints — null weight', () {
    test('null weight set is skipped (treated as 0, below threshold)', () {
      final points = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: null, reps: 10),
        ]),
      ]);

      // null weight → `set.weight ?? 0` → 0 → `<= 0` guard → no point
      expect(points, isEmpty);
    });

    test(
      'null-weight sets are ignored but valid-weight sets still produce a point',
      () {
        final points = buildProgressPoints([
          _row(DateTime.utc(2026, 3, 1, 10), [
            _set(id: 'a', weight: null, reps: 5),
            _set(id: 'b', weight: 80, reps: 5),
          ]),
        ]);

        expect(points, hasLength(1));
        expect(points.first.weight, 80);
      },
    );
  });

  group('ExerciseProgressKey', () {
    test('two keys with same exerciseId and window are equal', () {
      const a = ExerciseProgressKey(
        exerciseId: 'ex-1',
        window: TimeWindow.last90Days,
      );
      const b = ExerciseProgressKey(
        exerciseId: 'ex-1',
        window: TimeWindow.last90Days,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('keys differing by exerciseId are not equal', () {
      const a = ExerciseProgressKey(
        exerciseId: 'ex-1',
        window: TimeWindow.last90Days,
      );
      const b = ExerciseProgressKey(
        exerciseId: 'ex-2',
        window: TimeWindow.last90Days,
      );
      expect(a, isNot(equals(b)));
    });

    test('keys differing by window are not equal', () {
      const a = ExerciseProgressKey(
        exerciseId: 'ex-1',
        window: TimeWindow.last90Days,
      );
      const b = ExerciseProgressKey(
        exerciseId: 'ex-1',
        window: TimeWindow.allTime,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
