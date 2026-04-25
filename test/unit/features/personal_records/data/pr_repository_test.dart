import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:repsaga/core/local_storage/cache_service.dart';
import 'package:repsaga/features/exercises/data/exercise_repository.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/data/pr_repository.dart';
import 'package:repsaga/features/personal_records/models/personal_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../fixtures/test_factories.dart';

class _MockExerciseRepository extends Mock implements ExerciseRepository {}

// ---------------------------------------------------------------------------
// Fake Supabase infrastructure
// ---------------------------------------------------------------------------

class FakeSupabaseClient extends Fake implements supabase.SupabaseClient {
  FakeSupabaseClient(this.fakeBuilder);
  final FakePRQueryBuilder fakeBuilder;

  @override
  supabase.SupabaseQueryBuilder from(String table) => fakeBuilder;
}

/// A fake client that routes `from(table)` to different builders,
/// used when a method queries multiple tables.
class FakeRoutingSupabaseClient extends Fake
    implements supabase.SupabaseClient {
  FakeRoutingSupabaseClient(this.builders);
  final Map<String, FakePRQueryBuilder> builders;

  @override
  supabase.SupabaseQueryBuilder from(String table) =>
      builders[table] ?? (throw StateError('Unexpected table: $table'));
}

/// Records every chained call so tests can assert on query shape.
class FakePRQueryBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  FakePRQueryBuilder({this.data = const [], this.error});

  final List<Map<String, dynamic>> data;
  final Exception? error;

  final List<String> calledMethods = [];

  @override
  FakePRFilterBuilder select([String columns = '*']) {
    calledMethods.add('select:$columns');
    return FakePRFilterBuilder(this);
  }

  @override
  FakePRFilterBuilder upsert(
    dynamic values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    calledMethods.add('upsert');
    return FakePRFilterBuilder(this);
  }
}

class FakePRFilterBuilder extends Fake
    implements supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  FakePRFilterBuilder(this._parent);

  final FakePRQueryBuilder _parent;

  @override
  FakePRFilterBuilder select([String columns = '*']) {
    _parent.calledMethods.add('chainSelect');
    return this;
  }

  @override
  FakePRFilterBuilder eq(String column, Object value) {
    _parent.calledMethods.add('eq:$column=$value');
    return this;
  }

  @override
  FakePRFilterBuilder inFilter(String column, List values) {
    _parent.calledMethods.add('inFilter:$column');
    return this;
  }

  @override
  FakePRTransformBuilder<List<Map<String, dynamic>>> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    _parent.calledMethods.add('order:$column');
    return FakePRTransformBuilder<List<Map<String, dynamic>>>(
      _parent,
      _parent.data,
    );
  }

  @override
  Future<S> then<S>(
    FutureOr<S> Function(List<Map<String, dynamic>>) onValue, {
    Function? onError,
  }) {
    if (_parent.error != null) {
      return Future<List<Map<String, dynamic>>>.error(
        _parent.error!,
      ).then<S>(onValue, onError: onError);
    }
    return Future.value(onValue(_parent.data));
  }
}

class FakePRTransformBuilder<T> extends Fake
    implements supabase.PostgrestTransformBuilder<T> {
  FakePRTransformBuilder(this._parent, this._result);

  final FakePRQueryBuilder _parent;
  final T _result;

  @override
  FakePRTransformBuilder<T> limit(int count, {String? referencedTable}) {
    _parent.calledMethods.add('limit:$count');
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    if (_parent.error != null) {
      return Future<T>.error(_parent.error!).then<S>(onValue, onError: onError);
    }
    return Future.value(onValue(_result));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Exercise _ex({
  String id = 'exercise-001',
  String name = 'Bench Press',
  EquipmentType equipmentType = EquipmentType.barbell,
}) {
  return Exercise.fromJson(
    TestExerciseFactory.create(
      id: id,
      name: name,
      equipmentType: equipmentType.name,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  late _MockExerciseRepository mockExerciseRepo;

  setUp(() {
    mockExerciseRepo = _MockExerciseRepository();
    // Default: empty exercise map. Individual tests override this.
    when(
      () => mockExerciseRepo.getExercisesByIds(
        locale: any(named: 'locale'),
        userId: any(named: 'userId'),
        ids: any(named: 'ids'),
      ),
    ).thenAnswer((_) async => <String, Exercise>{});
  });

  group('PRRepository.getRecentRecordsWithExercises', () {
    test('returns parsed list with exercise details from batch RPC', () async {
      final rows = <Map<String, dynamic>>[
        TestPersonalRecordFactory.create(id: 'pr-001', exerciseId: 'ex-1'),
        TestPersonalRecordFactory.create(
          id: 'pr-002',
          exerciseId: 'ex-2',
          recordType: 'max_volume',
          value: 5000.0,
        ),
        TestPersonalRecordFactory.create(
          id: 'pr-003',
          exerciseId: 'ex-3',
          recordType: 'max_reps',
          value: 20.0,
        ),
      ];

      when(
        () => mockExerciseRepo.getExercisesByIds(
          locale: 'en',
          userId: 'user-001',
          ids: any(named: 'ids'),
        ),
      ).thenAnswer(
        (_) async => {
          'ex-1': _ex(id: 'ex-1', name: 'Bench Press'),
          'ex-2': _ex(id: 'ex-2', name: 'Squat'),
          'ex-3': _ex(
            id: 'ex-3',
            name: 'Pull-up',
            equipmentType: EquipmentType.bodyweight,
          ),
        },
      );

      final fakeBuilder = FakePRQueryBuilder(data: rows);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      final result = await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
      );

      expect(result, hasLength(3));

      expect(result[0].record.id, 'pr-001');
      expect(result[0].exerciseName, 'Bench Press');
      expect(result[0].equipmentType, EquipmentType.barbell);

      expect(result[1].record.id, 'pr-002');
      expect(result[1].exerciseName, 'Squat');

      expect(result[2].record.id, 'pr-003');
      expect(result[2].exerciseName, 'Pull-up');
      expect(result[2].equipmentType, EquipmentType.bodyweight);
    });

    test('issues server-side LIMIT with default value of 3', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
      );

      expect(fakeBuilder.calledMethods, contains('limit:3'));
    });

    test('issues server-side LIMIT with custom value', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
        limit: 5,
      );

      expect(fakeBuilder.calledMethods, contains('limit:5'));
    });

    test('filters by user_id', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getRecentRecordsWithExercises(
        userId: 'user-abc',
        locale: 'en',
      );

      expect(fakeBuilder.calledMethods, contains('eq:user_id=user-abc'));
    });

    test('orders by achieved_at descending', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
      );

      expect(fakeBuilder.calledMethods, contains('order:achieved_at'));
    });

    test('returns empty list when no records exist', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      final result = await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
      );

      expect(result, isEmpty);
    });

    test(
      'falls back to "Unknown Exercise" when exercise is missing from batch',
      () async {
        // PR row references ex-missing, but the batch RPC returns no entry for it.
        final row = TestPersonalRecordFactory.create(exerciseId: 'ex-missing');
        final fakeBuilder = FakePRQueryBuilder(data: [row]);
        final repo = PRRepository(
          FakeSupabaseClient(fakeBuilder),
          const CacheService(),
          mockExerciseRepo,
        );

        final result = await repo.getRecentRecordsWithExercises(
          userId: 'user-001',
          locale: 'en',
        );

        expect(result[0].exerciseName, 'Unknown Exercise');
        expect(result[0].equipmentType, EquipmentType.barbell);
      },
    );

    test('return type is List of named record tuples', () async {
      final row = TestPersonalRecordFactory.create(exerciseId: 'ex-1');
      when(
        () => mockExerciseRepo.getExercisesByIds(
          locale: 'en',
          userId: 'user-001',
          ids: any(named: 'ids'),
        ),
      ).thenAnswer((_) async => {'ex-1': _ex(id: 'ex-1')});

      final fakeBuilder = FakePRQueryBuilder(data: [row]);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      final result = await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
      );

      // Verify the structural type: each element carries record, exerciseName,
      // and equipmentType fields.
      final item = result.first;
      expect(item.record, isA<PersonalRecord>());
      expect(item.exerciseName, isA<String>());
      expect(item.equipmentType, isA<EquipmentType>());
    });

    test(
      'collects distinct exercise IDs from page rows for the batch lookup',
      () async {
        // Two rows reference ex-1, one references ex-2 — batch should be called
        // with the deduped set.
        final rows = <Map<String, dynamic>>[
          TestPersonalRecordFactory.create(id: 'pr-1', exerciseId: 'ex-1'),
          TestPersonalRecordFactory.create(id: 'pr-2', exerciseId: 'ex-2'),
          TestPersonalRecordFactory.create(id: 'pr-3', exerciseId: 'ex-1'),
        ];

        when(
          () => mockExerciseRepo.getExercisesByIds(
            locale: 'en',
            userId: 'user-001',
            ids: any(named: 'ids'),
          ),
        ).thenAnswer(
          (_) async => {
            'ex-1': _ex(id: 'ex-1', name: 'A'),
            'ex-2': _ex(id: 'ex-2', name: 'B'),
          },
        );

        final fakeBuilder = FakePRQueryBuilder(data: rows);
        final repo = PRRepository(
          FakeSupabaseClient(fakeBuilder),
          const CacheService(),
          mockExerciseRepo,
        );

        await repo.getRecentRecordsWithExercises(
          userId: 'user-001',
          locale: 'en',
        );

        final captured =
            verify(
                  () => mockExerciseRepo.getExercisesByIds(
                    locale: 'en',
                    userId: 'user-001',
                    ids: captureAny(named: 'ids'),
                  ),
                ).captured.single
                as List<String>;

        expect(captured.toSet(), {'ex-1', 'ex-2'});
      },
    );

    test('skips exercise lookup entirely when no rows are returned', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getRecentRecordsWithExercises(
        userId: 'user-001',
        locale: 'en',
      );

      verifyNever(
        () => mockExerciseRepo.getExercisesByIds(
          locale: any(named: 'locale'),
          userId: any(named: 'userId'),
          ids: any(named: 'ids'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getPRsForWorkout
  // -------------------------------------------------------------------------

  group('PRRepository.getPRsForWorkout', () {
    /// Builds a sets row as Supabase returns it (with the nested join).
    Map<String, dynamic> setRow(String id, String workoutId) => {
      'id': id,
      'workout_exercises': {'workout_id': workoutId},
    };

    test('returns PRs whose set_id belongs to the workout', () async {
      const workoutId = 'workout-001';
      const userId = 'user-001';

      final setsBuilder = FakePRQueryBuilder(
        data: [setRow('set-001', workoutId), setRow('set-002', workoutId)],
      );

      final prRow1 = TestPersonalRecordFactory.create(
        id: 'pr-001',
        userId: userId,
        setId: 'set-001',
      );
      final prRow2 = TestPersonalRecordFactory.create(
        id: 'pr-002',
        userId: userId,
        setId: 'set-002',
      );
      final prBuilder = FakePRQueryBuilder(data: [prRow1, prRow2]);

      final repo = PRRepository(
        FakeRoutingSupabaseClient({
          'sets': setsBuilder,
          'personal_records': prBuilder,
        }),
        const CacheService(),
        mockExerciseRepo,
      );

      final result = await repo.getPRsForWorkout(workoutId, userId);

      expect(result, hasLength(2));
      expect(result[0].id, 'pr-001');
      expect(result[1].id, 'pr-002');
    });

    test('returns empty list when workout has no sets', () async {
      const workoutId = 'workout-empty';
      const userId = 'user-001';

      // No sets for this workout.
      final setsBuilder = FakePRQueryBuilder(data: []);
      // PR builder should never be queried — use empty data just in case.
      final prBuilder = FakePRQueryBuilder(data: []);

      final repo = PRRepository(
        FakeRoutingSupabaseClient({
          'sets': setsBuilder,
          'personal_records': prBuilder,
        }),
        const CacheService(),
        mockExerciseRepo,
      );

      final result = await repo.getPRsForWorkout(workoutId, userId);

      expect(result, isEmpty);
      // The second query (inFilter) must not have been called.
      expect(prBuilder.calledMethods, isEmpty);
    });

    test('returns empty list when no PRs match the set IDs', () async {
      const workoutId = 'workout-001';
      const userId = 'user-001';

      final setsBuilder = FakePRQueryBuilder(
        data: [setRow('set-001', workoutId)],
      );
      // Sets table exists but no PR row references those sets.
      final prBuilder = FakePRQueryBuilder(data: []);

      final repo = PRRepository(
        FakeRoutingSupabaseClient({
          'sets': setsBuilder,
          'personal_records': prBuilder,
        }),
        const CacheService(),
        mockExerciseRepo,
      );

      final result = await repo.getPRsForWorkout(workoutId, userId);

      expect(result, isEmpty);
    });

    test('filters PR query by user_id', () async {
      const workoutId = 'workout-001';
      const userId = 'user-abc';

      final setsBuilder = FakePRQueryBuilder(
        data: [setRow('set-001', workoutId)],
      );
      final prBuilder = FakePRQueryBuilder(data: []);

      final repo = PRRepository(
        FakeRoutingSupabaseClient({
          'sets': setsBuilder,
          'personal_records': prBuilder,
        }),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getPRsForWorkout(workoutId, userId);

      expect(prBuilder.calledMethods, contains('eq:user_id=$userId'));
    });

    test('filters PR query by set_id using inFilter', () async {
      const workoutId = 'workout-001';

      final setsBuilder = FakePRQueryBuilder(
        data: [setRow('set-001', workoutId), setRow('set-002', workoutId)],
      );
      final prBuilder = FakePRQueryBuilder(data: []);

      final repo = PRRepository(
        FakeRoutingSupabaseClient({
          'sets': setsBuilder,
          'personal_records': prBuilder,
        }),
        const CacheService(),
        mockExerciseRepo,
      );

      await repo.getPRsForWorkout(workoutId, 'user-001');

      expect(prBuilder.calledMethods, contains('inFilter:set_id'));
    });
  });
}
