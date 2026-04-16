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
    test('empty input → empty output, workoutCount == 0', () {
      final result = buildProgressPoints(const []);
      expect(result.points, isEmpty);
      expect(result.workoutCount, 0);
    });

    test('single session → one point at max completed working set weight', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: 80, reps: 10),
          _set(id: 'b', weight: 100, reps: 5),
          _set(id: 'c', weight: 90, reps: 8),
        ]),
      ]);

      expect(result.points, hasLength(1));
      expect(result.points.first.weight, 100);
      expect(result.points.first.sessionReps, 5);
      expect(result.workoutCount, 1);
    });

    test('warmup, dropset, failure, incomplete sets are excluded', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: 200, reps: 5, setType: SetType.warmup),
          _set(id: 'b', weight: 180, reps: 5, setType: SetType.dropset),
          _set(id: 'c', weight: 170, reps: 5, setType: SetType.failure),
          _set(id: 'd', weight: 150, reps: 5, isCompleted: false),
          _set(id: 'e', weight: 100, reps: 5),
        ]),
      ]);

      expect(result.points, hasLength(1));
      expect(result.points.first.weight, 100);
    });

    test('zero-weight working sets are skipped (bodyweight-only case)', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: 0, reps: 12),
        ]),
      ]);

      expect(result.points, isEmpty);
    });

    test('multiple sessions same calendar day → one point at max weight', () {
      final morning = DateTime.utc(2026, 3, 1, 8);
      final evening = DateTime.utc(2026, 3, 1, 19);
      final result = buildProgressPoints([
        _row(morning, [_set(id: 'a', weight: 80, reps: 10)]),
        _row(evening, [_set(id: 'b', weight: 110, reps: 6)]),
      ]);

      expect(result.points, hasLength(1));
      expect(result.points.first.weight, 110);
      expect(result.points.first.sessionReps, 6);
    });

    test('multiple days → sorted ascending by date', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 10, 12), [_set(weight: 105)]),
        _row(DateTime.utc(2026, 3, 1, 12), [_set(weight: 100)]),
        _row(DateTime.utc(2026, 3, 5, 12), [_set(weight: 102)]),
      ]);

      expect(result.points.map((p) => p.weight).toList(), [100, 102, 105]);
    });

    test('session with only disqualified sets produces no point', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 12), [
          _set(setType: SetType.warmup),
          _set(isCompleted: false),
        ]),
        _row(DateTime.utc(2026, 3, 2, 12), [_set(weight: 90)]),
      ]);

      expect(result.points, hasLength(1));
      expect(result.points.first.weight, 90);
    });
  });

  // BL-1 disambiguation (folded into BL-3 acceptance #14): the widget's trend
  // copy row needs to distinguish "1 workout logged" from "N workouts logged
  // (same day)". These tests pin down the workoutCount contract that the
  // widget relies on.
  group('buildProgressPoints — workoutCount (BL-1 fix)', () {
    test('0 rows → workoutCount == 0, points empty', () {
      final result = buildProgressPoints(const []);
      expect(result.workoutCount, 0);
      expect(result.points, isEmpty);
    });

    test('1 workout / 1 day → workoutCount == 1, points.length == 1', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [_set(weight: 100, reps: 5)]),
      ]);
      expect(result.workoutCount, 1);
      expect(result.points, hasLength(1));
    });

    test('2 workouts / same day → workoutCount == 2, points.length == 1', () {
      final morning = DateTime.utc(2026, 3, 1, 8);
      final evening = DateTime.utc(2026, 3, 1, 19);
      final result = buildProgressPoints([
        _row(morning, [_set(id: 'a', weight: 100, reps: 5)]),
        _row(evening, [_set(id: 'b', weight: 110, reps: 3)]),
      ]);
      expect(result.workoutCount, 2);
      expect(result.points, hasLength(1));
    });

    test(
      '2 workouts / different days → workoutCount == 2, points.length == 2',
      () {
        final result = buildProgressPoints([
          _row(DateTime.utc(2026, 3, 1, 10), [_set(weight: 100, reps: 5)]),
          _row(DateTime.utc(2026, 3, 2, 10), [_set(weight: 105, reps: 5)]),
        ]);
        expect(result.workoutCount, 2);
        expect(result.points, hasLength(2));
      },
    );

    test(
      'workout with only warmups/incompletes does NOT count toward workoutCount',
      () {
        // Same predicate as the point-generation filter: a workout must have
        // at least one isCompletedWorkingSet with weight > 0 to count.
        final result = buildProgressPoints([
          _row(DateTime.utc(2026, 3, 1, 10), [
            _set(weight: 200, reps: 5, setType: SetType.warmup),
            _set(weight: 150, reps: 5, isCompleted: false),
          ]),
          _row(DateTime.utc(2026, 3, 2, 10), [_set(weight: 100, reps: 5)]),
        ]);
        expect(result.workoutCount, 1);
        expect(result.points, hasLength(1));
      },
    );

    test('workout with only null-weight sets does NOT count', () {
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [_set(weight: null, reps: 5)]),
        _row(DateTime.utc(2026, 3, 2, 10), [_set(weight: 100, reps: 5)]),
      ]);
      expect(result.workoutCount, 1);
      expect(result.points, hasLength(1));
    });
  });

  group('toE1RmSeries', () {
    test('empty input → empty output', () {
      expect(toE1RmSeries(const []), isEmpty);
    });

    test('single row plots e1RM, not raw weight', () {
      // (100 kg × 5 reps) → e1RM ≈ 116.67
      final series = toE1RmSeries([
        _row(DateTime.utc(2026, 3, 1, 10), [_set(weight: 100, reps: 5)]),
      ]);

      expect(series, hasLength(1));
      expect(series.first.weight, closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('same-day sessions collapse to max e1RM, not max raw weight', () {
      // Heavier weight with fewer reps can have lower e1RM:
      //   (100 kg × 10) → 133.33  (higher e1RM)
      //   (110 kg × 3)  → 121.0
      // toE1RmSeries should pick 133.33 for that day.
      final series = toE1RmSeries([
        _row(DateTime.utc(2026, 3, 1, 8), [_set(weight: 100, reps: 10)]),
        _row(DateTime.utc(2026, 3, 1, 18), [_set(weight: 110, reps: 3)]),
      ]);

      expect(series, hasLength(1));
      expect(series.first.weight, closeTo(100 * (1 + 10 / 30), 1e-9));
    });

    test('multiple days → one point per day, sorted ascending', () {
      final series = toE1RmSeries([
        _row(DateTime.utc(2026, 3, 3, 10), [_set(weight: 100, reps: 5)]),
        _row(DateTime.utc(2026, 3, 1, 10), [_set(weight: 80, reps: 10)]),
      ]);

      expect(series, hasLength(2));
      // March 1 should come first.
      expect(series.first.date.isBefore(series.last.date), isTrue);
      // March 1: (80 × 10) → 106.67
      expect(series.first.weight, closeTo(80 * (1 + 10 / 30), 1e-9));
      // March 3: (100 × 5) → 116.67
      expect(series.last.weight, closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('excludes warmup/dropset/failure/incomplete/zero-weight sets', () {
      final series = toE1RmSeries([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(weight: 200, reps: 5, setType: SetType.warmup),
          _set(weight: 180, reps: 5, setType: SetType.dropset),
          _set(weight: 170, reps: 5, setType: SetType.failure),
          _set(weight: 150, reps: 5, isCompleted: false),
          _set(weight: 0, reps: 5),
          _set(weight: 100, reps: 5),
        ]),
      ]);

      expect(series, hasLength(1));
      expect(series.first.weight, closeTo(100 * (1 + 5 / 30), 1e-9));
    });
  });

  group('peakPoint', () {
    test('empty list → null', () {
      expect(peakPoint(const []), isNull);
    });

    test('returns highest-weight point, not first or last', () {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 80, sessionReps: 10),
        ProgressPoint(date: DateTime(2026, 3, 2), weight: 120, sessionReps: 3),
        ProgressPoint(date: DateTime(2026, 3, 3), weight: 100, sessionReps: 5),
      ];

      final peak = peakPoint(points);
      expect(peak, isNotNull);
      expect(peak!.weight, 120);
      expect(peak.date, DateTime(2026, 3, 2));
    });

    test('returns the sole point when length is 1', () {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 100, sessionReps: 5),
      ];

      expect(peakPoint(points)!.weight, 100);
    });
  });

  group('trendDelta', () {
    test('null when empty', () {
      expect(trendDelta(const []), isNull);
    });

    test('null when length < 2', () {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 100, sessionReps: 5),
      ];
      expect(trendDelta(points), isNull);
    });

    test('returns last - first when length >= 2 (positive)', () {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 100, sessionReps: 5),
        ProgressPoint(date: DateTime(2026, 3, 2), weight: 105, sessionReps: 5),
      ];
      expect(trendDelta(points), closeTo(5, 1e-9));
    });

    test('returns last - first when length >= 2 (negative)', () {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 110, sessionReps: 5),
        ProgressPoint(date: DateTime(2026, 3, 2), weight: 100, sessionReps: 5),
      ];
      expect(trendDelta(points), closeTo(-10, 1e-9));
    });

    test('ignores intermediate points — only endpoints matter', () {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 100, sessionReps: 5),
        ProgressPoint(date: DateTime(2026, 3, 2), weight: 200, sessionReps: 5),
        ProgressPoint(date: DateTime(2026, 3, 3), weight: 110, sessionReps: 5),
      ];
      expect(trendDelta(points), closeTo(10, 1e-9));
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

    test('returns empty result when user is not signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      final container = buildContainer();

      final result = await container.read(
        exerciseProgressProvider(
          const ExerciseProgressKey(
            exerciseId: 'ex-1',
            window: TimeWindow.last90Days,
          ),
        ).future,
      );

      expect(result.points, isEmpty);
      expect(result.workoutCount, 0);
      verifyNever(
        () => mockRepo.getExerciseHistory(
          any(),
          userId: any(named: 'userId'),
          since: any(named: 'since'),
        ),
      );
    });

    test('last30Days window passes a ~30d since to the repo', () async {
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
            window: TimeWindow.last30Days,
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
      expect(now.difference(since).inDays, inInclusiveRange(29, 31));
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
        final result = await container.read(
          exerciseProgressProvider(
            const ExerciseProgressKey(
              exerciseId: 'ex-1',
              window: TimeWindow.allTime,
            ),
          ).future,
        );

        expect(result.points, hasLength(2));
        expect(result.points[0].weight, 95);
        expect(result.points[1].weight, 100);
        // Three repo rows, all with qualifying sets → workoutCount = 3.
        expect(result.workoutCount, 3);
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
      final result = buildProgressPoints([
        _row(DateTime.utc(2026, 3, 1, 10), [
          _set(id: 'a', weight: null, reps: 10),
        ]),
      ]);

      // null weight → `set.weight ?? 0` → 0 → `<= 0` guard → no point
      expect(result.points, isEmpty);
    });

    test(
      'null-weight sets are ignored but valid-weight sets still produce a point',
      () {
        final result = buildProgressPoints([
          _row(DateTime.utc(2026, 3, 1, 10), [
            _set(id: 'a', weight: null, reps: 5),
            _set(id: 'b', weight: 80, reps: 5),
          ]),
        ]);

        expect(result.points, hasLength(1));
        expect(result.points.first.weight, 80);
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
