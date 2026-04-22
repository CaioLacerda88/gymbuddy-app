import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/cache_service.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/data/pr_repository.dart';
import 'package:repsaga/features/personal_records/models/personal_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../fixtures/test_factories.dart';

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
    calledMethods.add('select');
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

/// Builds a row as Supabase would return it: PR fields plus an embedded
/// `exercises` map with name and equipment_type.
Map<String, dynamic> _prRowWithExercise({
  String id = 'pr-001',
  String userId = 'user-001',
  String exerciseId = 'exercise-001',
  String recordType = 'max_weight',
  double value = 100.0,
  String achievedAt = '2026-01-01T10:30:00Z',
  String exerciseName = 'Bench Press',
  String equipmentType = 'barbell',
}) {
  return {
    ...TestPersonalRecordFactory.create(
      id: id,
      userId: userId,
      exerciseId: exerciseId,
      recordType: recordType,
      value: value,
      achievedAt: achievedAt,
    ),
    'exercises': {'name': exerciseName, 'equipment_type': equipmentType},
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PRRepository.getRecentRecordsWithExercises', () {
    test('returns parsed list with exercise details', () async {
      final rows = [
        _prRowWithExercise(
          id: 'pr-001',
          exerciseName: 'Bench Press',
          equipmentType: 'barbell',
        ),
        _prRowWithExercise(
          id: 'pr-002',
          exerciseName: 'Squat',
          equipmentType: 'barbell',
          recordType: 'max_volume',
          value: 5000.0,
        ),
        _prRowWithExercise(
          id: 'pr-003',
          exerciseName: 'Pull-up',
          equipmentType: 'bodyweight',
          recordType: 'max_reps',
          value: 20.0,
        ),
      ];

      final fakeBuilder = FakePRQueryBuilder(data: rows);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      final result = await repo.getRecentRecordsWithExercises('user-001');

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
      );

      await repo.getRecentRecordsWithExercises('user-001');

      expect(fakeBuilder.calledMethods, contains('limit:3'));
    });

    test('issues server-side LIMIT with custom value', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      await repo.getRecentRecordsWithExercises('user-001', limit: 5);

      expect(fakeBuilder.calledMethods, contains('limit:5'));
    });

    test('filters by user_id', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      await repo.getRecentRecordsWithExercises('user-abc');

      expect(fakeBuilder.calledMethods, contains('eq:user_id=user-abc'));
    });

    test('orders by achieved_at descending', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      await repo.getRecentRecordsWithExercises('user-001');

      expect(fakeBuilder.calledMethods, contains('order:achieved_at'));
    });

    test('returns empty list when no records exist', () async {
      final fakeBuilder = FakePRQueryBuilder(data: []);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      final result = await repo.getRecentRecordsWithExercises('user-001');

      expect(result, isEmpty);
    });

    test('uses Unknown Exercise when exercises data is null', () async {
      final row = {...TestPersonalRecordFactory.create(), 'exercises': null};
      final fakeBuilder = FakePRQueryBuilder(data: [row]);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      final result = await repo.getRecentRecordsWithExercises('user-001');

      expect(result[0].exerciseName, 'Unknown Exercise');
      expect(result[0].equipmentType, EquipmentType.barbell);
    });

    test('return type is List of named record tuples', () async {
      final fakeBuilder = FakePRQueryBuilder(data: [_prRowWithExercise()]);
      final repo = PRRepository(
        FakeSupabaseClient(fakeBuilder),
        const CacheService(),
      );

      final result = await repo.getRecentRecordsWithExercises('user-001');

      // Verify the structural type: each element carries record, exerciseName,
      // and equipmentType fields.
      final item = result.first;
      expect(item.record, isA<PersonalRecord>());
      expect(item.exerciseName, isA<String>());
      expect(item.equipmentType, isA<EquipmentType>());
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
      );

      await repo.getPRsForWorkout(workoutId, 'user-001');

      expect(prBuilder.calledMethods, contains('inFilter:set_id'));
    });
  });
}
