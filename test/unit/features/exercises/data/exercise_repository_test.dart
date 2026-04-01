import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/features/exercises/data/exercise_repository.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../fixtures/test_factories.dart';

/// A fake SupabaseClient that returns a fake query builder for 'exercises'.
class FakeSupabaseClient extends Fake implements supabase.SupabaseClient {
  FakeSupabaseClient(this.fakeBuilder);

  final FakeQueryBuilder fakeBuilder;

  @override
  supabase.SupabaseQueryBuilder from(String table) => fakeBuilder;
}

/// A fake query builder that records method calls and returns preset data.
class FakeQueryBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  FakeQueryBuilder({this.data = const [], this.error});

  final List<Map<String, dynamic>> data;
  final Exception? error;

  final List<String> calledMethods = [];
  final Map<String, dynamic> calledArgs = {};

  @override
  FakeFilterBuilder select([String columns = '*']) {
    calledMethods.add('select');
    return FakeFilterBuilder(this);
  }

  @override
  FakeFilterBuilder insert(dynamic values, {bool defaultToNull = true}) {
    calledMethods.add('insert');
    calledArgs['insert'] = values;
    return FakeFilterBuilder(this);
  }

  @override
  FakeFilterBuilder update(Map values) {
    calledMethods.add('update');
    calledArgs['update'] = values;
    return FakeFilterBuilder(this);
  }
}

class FakeFilterBuilder extends Fake
    implements supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  FakeFilterBuilder(this._parent);

  final FakeQueryBuilder _parent;

  @override
  FakeFilterBuilder isFilter(String column, Object? value) {
    _parent.calledMethods.add('isFilter:$column');
    return this;
  }

  @override
  FakeFilterBuilder eq(String column, Object value) {
    _parent.calledMethods.add('eq:$column=$value');
    return this;
  }

  @override
  FakeFilterBuilder ilike(String column, Object value) {
    _parent.calledMethods.add('ilike:$column=$value');
    return this;
  }

  @override
  FakeFilterBuilder select([String columns = '*']) {
    _parent.calledMethods.add('chainSelect');
    return this;
  }

  @override
  FakeTransformBuilder<Map<String, dynamic>> single() {
    _parent.calledMethods.add('single');
    return FakeTransformBuilder<Map<String, dynamic>>(
      _parent,
      _parent.data.first,
    );
  }

  @override
  FakeTransformBuilder<List<Map<String, dynamic>>> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    _parent.calledMethods.add('order:$column');
    return FakeTransformBuilder<List<Map<String, dynamic>>>(
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

class FakeTransformBuilder<T> extends Fake
    implements supabase.PostgrestTransformBuilder<T> {
  FakeTransformBuilder(this._parent, this._result);

  final FakeQueryBuilder _parent;
  final T _result;

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    if (_parent.error != null) {
      // Delegate to a real Future so await/try-catch works properly.
      return Future<T>.error(_parent.error!).then<S>(onValue, onError: onError);
    }
    return Future.value(onValue(_result));
  }
}

void main() {
  group('ExerciseRepository', () {
    group('getExercises', () {
      test('returns list of exercises', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [
            TestExerciseFactory.create(),
            TestExerciseFactory.create(
              id: 'exercise-002',
              name: 'Squat',
              muscleGroup: 'legs',
            ),
          ],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.getExercises();

        expect(result, hasLength(2));
        expect(result[0].name, 'Bench Press');
        expect(result[1].name, 'Squat');
        expect(fakeBuilder.calledMethods, contains('isFilter:deleted_at'));
        expect(fakeBuilder.calledMethods, contains('order:name'));
      });

      test('applies muscle group filter', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [TestExerciseFactory.create()],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.getExercises(muscleGroup: MuscleGroup.chest);

        expect(result, hasLength(1));
        expect(fakeBuilder.calledMethods, contains('eq:muscle_group=chest'));
      });

      test('applies equipment type filter', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [TestExerciseFactory.create()],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.getExercises(
          equipmentType: EquipmentType.barbell,
        );

        expect(result, hasLength(1));
        expect(
          fakeBuilder.calledMethods,
          contains('eq:equipment_type=barbell'),
        );
      });
    });

    group('searchExercises', () {
      test('performs case-insensitive search', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [TestExerciseFactory.create()],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.searchExercises('bench');

        expect(result, hasLength(1));
        expect(fakeBuilder.calledMethods, contains('ilike:name=%bench%'));
      });

      test('escapes special LIKE characters in search query', () async {
        final fakeBuilder = FakeQueryBuilder(data: []);
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        await repo.searchExercises('100%_effort');

        expect(
          fakeBuilder.calledMethods,
          contains(r'ilike:name=%100\%\_effort%'),
        );
      });

      test('applies filters with search', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [TestExerciseFactory.create()],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.searchExercises(
          'press',
          muscleGroup: MuscleGroup.chest,
          equipmentType: EquipmentType.barbell,
        );

        expect(result, hasLength(1));
        expect(fakeBuilder.calledMethods, contains('ilike:name=%press%'));
        expect(fakeBuilder.calledMethods, contains('eq:muscle_group=chest'));
        expect(
          fakeBuilder.calledMethods,
          contains('eq:equipment_type=barbell'),
        );
      });
    });

    group('getExerciseById', () {
      test('returns single exercise', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [TestExerciseFactory.create()],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.getExerciseById('exercise-001');

        expect(result.id, 'exercise-001');
        expect(result.name, 'Bench Press');
        expect(fakeBuilder.calledMethods, contains('eq:id=exercise-001'));
        expect(fakeBuilder.calledMethods, contains('single'));
      });
    });

    group('createExercise', () {
      test('inserts and returns exercise', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [
            TestExerciseFactory.create(
              name: 'My Exercise',
              isDefault: false,
              userId: 'user-001',
            ),
          ],
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        final result = await repo.createExercise(
          name: 'My Exercise',
          muscleGroup: MuscleGroup.chest,
          equipmentType: EquipmentType.barbell,
          userId: 'user-001',
        );

        expect(result.name, 'My Exercise');
        expect(result.userId, 'user-001');
        expect(result.isDefault, false);
        expect(fakeBuilder.calledMethods, contains('insert'));
        expect(fakeBuilder.calledMethods, contains('single'));
      });

      test('maps unique constraint violation to ValidationException', () async {
        final fakeBuilder = FakeQueryBuilder(
          data: [TestExerciseFactory.create()],
          error: const supabase.PostgrestException(
            message: 'duplicate key value',
            code: '23505',
          ),
        );
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        await expectLater(
          () => repo.createExercise(
            name: 'Bench Press',
            muscleGroup: MuscleGroup.chest,
            equipmentType: EquipmentType.barbell,
            userId: 'user-001',
          ),
          throwsA(
            isA<ValidationException>()
                .having((e) => e.field, 'field', 'name')
                .having(
                  (e) => e.message,
                  'message',
                  'An exercise with this name already exists',
                ),
          ),
        );
      });
    });

    group('softDeleteExercise', () {
      test('updates deleted_at for the exercise', () async {
        final fakeBuilder = FakeQueryBuilder();
        final repo = ExerciseRepository(FakeSupabaseClient(fakeBuilder));

        await repo.softDeleteExercise('exercise-001', userId: 'user-001');

        expect(fakeBuilder.calledMethods, contains('update'));
        expect(fakeBuilder.calledMethods, contains('eq:id=exercise-001'));
        expect(fakeBuilder.calledMethods, contains('eq:user_id=user-001'));
        final updateData = fakeBuilder.calledArgs['update'] as Map;
        expect(updateData.containsKey('deleted_at'), true);
      });
    });
  });
}
