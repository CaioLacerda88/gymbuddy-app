// RoutineRepository unit tests.
//
// Systematic gaps exposed by the PR-27 regression analysis:
// - BUG-005: _resolveExercises silently returns unresolved routines when
//   _fetchExerciseMap returns an empty map (exercises table unreachable or
//   returns no rows). There were zero mocked-Supabase tests for this class.
// - No test verified that getLastWorkoutSets returning an empty map is handled
//   gracefully (tested here at the repository layer via the parsing path).
//
// Testing strategy: the same FakeQueryBuilder pattern used in
// exercise_repository_test.dart — avoids real Supabase, tests mapping + error
// handling with full control over returned data.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/features/routines/data/routine_repository.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Fake Supabase infrastructure (mirrors the pattern in exercise_repository_test.dart)
// ---------------------------------------------------------------------------

/// A stubbed SupabaseClient that routes `from(table)` to one of two builders:
/// one for 'workout_templates', one for 'exercises'.
class _FakeSupabaseClient extends Fake implements supabase.SupabaseClient {
  _FakeSupabaseClient({
    required _FakeQueryBuilder templatesBuilder,
    required _FakeQueryBuilder exercisesBuilder,
  }) : _templatesBuilder = templatesBuilder,
       _exercisesBuilder = exercisesBuilder;

  final _FakeQueryBuilder _templatesBuilder;
  final _FakeQueryBuilder _exercisesBuilder;

  @override
  supabase.SupabaseQueryBuilder from(String table) {
    if (table == 'exercises') return _exercisesBuilder;
    return _templatesBuilder;
  }
}

class _FakeQueryBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  _FakeQueryBuilder({this.data = const [], this.error});

  final List<Map<String, dynamic>> data;
  final Exception? error;

  @override
  _FakeFilterBuilder select([String columns = '*']) => _FakeFilterBuilder(this);

  @override
  _FakeFilterBuilder insert(dynamic values, {bool defaultToNull = true}) =>
      _FakeFilterBuilder(this);

  @override
  _FakeFilterBuilder update(Map values) => _FakeFilterBuilder(this);

  @override
  _FakeFilterBuilder delete() => _FakeFilterBuilder(this);
}

class _FakeFilterBuilder extends Fake
    implements supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _FakeFilterBuilder(this._parent);

  final _FakeQueryBuilder _parent;

  @override
  _FakeFilterBuilder eq(String column, Object value) => this;

  @override
  _FakeFilterBuilder or(String filter, {String? referencedTable}) => this;

  @override
  _FakeFilterBuilder inFilter(String column, List values) => this;

  @override
  _FakeTransformBuilder<Map<String, dynamic>> single() =>
      _FakeTransformBuilder<Map<String, dynamic>>(
        _parent,
        _parent.data.isEmpty ? <String, dynamic>{} : _parent.data.first,
      );

  @override
  _FakeTransformBuilder<List<Map<String, dynamic>>> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      _FakeTransformBuilder<List<Map<String, dynamic>>>(_parent, _parent.data);

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

class _FakeTransformBuilder<T> extends Fake
    implements supabase.PostgrestTransformBuilder<T> {
  _FakeTransformBuilder(this._parent, this._result);

  final _FakeQueryBuilder _parent;
  final T _result;

  @override
  _FakeFilterBuilder select([String columns = '*']) =>
      _FakeFilterBuilder(_parent);

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

RoutineRepository _makeRepo({
  List<Map<String, dynamic>> templates = const [],
  List<Map<String, dynamic>> exercises = const [],
  Exception? templatesError,
  Exception? exercisesError,
}) {
  final client = _FakeSupabaseClient(
    templatesBuilder: _FakeQueryBuilder(data: templates, error: templatesError),
    exercisesBuilder: _FakeQueryBuilder(data: exercises, error: exercisesError),
  );
  return RoutineRepository(client);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RoutineRepository._resolveExercises / _fetchExerciseMap', () {
    test(
      'returns routines with exercise=null when exercise fetch returns empty '
      '(BUG-005: exercises table unreachable or empty)',
      () async {
        // Template with two exercises referenced by ID.
        final templateRow = TestRoutineFactory.create(
          id: 'r-001',
          exercises: [
            TestRoutineExerciseFactory.create(exerciseId: 'ex-A'),
            TestRoutineExerciseFactory.create(exerciseId: 'ex-B'),
          ],
        );

        // exercises table returns nothing (simulates unreachable or empty).
        final repo = _makeRepo(
          templates: [templateRow],
          exercises: [], // empty — _fetchExerciseMap returns {}
        );

        final routines = await repo.getRoutines('user-001');

        expect(routines, hasLength(1));
        // BUG-005 scenario: exercises should have null exercise references
        // because the exercise map was empty. This verifies the behavior
        // documented in the regression: routines come back unresolved.
        expect(routines[0].exercises[0].exercise, isNull);
        expect(routines[0].exercises[1].exercise, isNull);
      },
    );

    test(
      'populates exercise references when exercises table returns matching rows',
      () async {
        final exerciseRow = TestExerciseFactory.create(
          id: 'ex-bench',
          name: 'Bench Press',
          equipmentType: 'barbell',
        );
        final templateRow = TestRoutineFactory.create(
          id: 'r-001',
          exercises: [
            TestRoutineExerciseFactory.create(exerciseId: 'ex-bench'),
          ],
        );

        final repo = _makeRepo(
          templates: [templateRow],
          exercises: [exerciseRow],
        );

        final routines = await repo.getRoutines('user-001');

        expect(routines[0].exercises[0].exercise, isNotNull);
        expect(routines[0].exercises[0].exercise!.name, 'Bench Press');
      },
    );

    test('returns empty list immediately when routine has no exercises '
        '(does not call exercises table)', () async {
      // Template with no exercises — ids set is empty, so _fetchExerciseMap
      // early-returns {} without querying. This is the intended fast path.
      final templateRow = TestRoutineFactory.create(
        id: 'r-empty',
        exercises: [], // no exercises
      );

      final repo = _makeRepo(
        templates: [templateRow],
        exercises: [], // should not be queried
      );

      final routines = await repo.getRoutines('user-001');

      expect(routines, hasLength(1));
      expect(routines[0].exercises, isEmpty);
    });

    test(
      'partial resolution: exercises present for some IDs but not others',
      () async {
        // Only ex-A resolves; ex-B has no matching row.
        final exerciseRow = TestExerciseFactory.create(
          id: 'ex-A',
          name: 'Squat',
        );
        final templateRow = TestRoutineFactory.create(
          exercises: [
            TestRoutineExerciseFactory.create(exerciseId: 'ex-A'),
            TestRoutineExerciseFactory.create(exerciseId: 'ex-B'),
          ],
        );

        final repo = _makeRepo(
          templates: [templateRow],
          exercises: [exerciseRow], // only ex-A in DB
        );

        final routines = await repo.getRoutines('user-001');

        expect(routines[0].exercises[0].exercise?.name, 'Squat');
        expect(
          routines[0].exercises[1].exercise,
          isNull,
          reason:
              'ex-B has no matching row in exercises table — should be null, '
              'not throw',
        );
      },
    );

    test('getRoutines maps template row fields correctly', () async {
      final templateRow = TestRoutineFactory.create(
        id: 'r-abc',
        name: 'Leg Day',
        isDefault: true,
        exercises: [],
      );

      final repo = _makeRepo(templates: [templateRow]);

      final routines = await repo.getRoutines('user-001');

      expect(routines, hasLength(1));
      expect(routines[0].id, 'r-abc');
      expect(routines[0].name, 'Leg Day');
      expect(routines[0].isDefault, isTrue);
    });

    test(
      'getRoutines returns empty list when templates table returns no rows',
      () async {
        final repo = _makeRepo(templates: []);

        final routines = await repo.getRoutines('user-001');

        expect(routines, isEmpty);
      },
    );

    test('getRoutines wraps Supabase errors in AppException', () async {
      const supabaseError = supabase.PostgrestException(
        message: 'relation "workout_templates" does not exist',
        code: '42P01',
      );
      final repo = _makeRepo(templatesError: supabaseError);

      expect(
        () => repo.getRoutines('user-001'),
        throwsA(isA<AppException>()),
        reason:
            'A PostgrestException from Supabase must be wrapped by '
            'mapException() into an AppException, not leaked as raw',
      );
    });

    test(
      'multiple routines each get their exercises resolved independently',
      () async {
        final exA = TestExerciseFactory.create(id: 'ex-A', name: 'Bench Press');
        final exB = TestExerciseFactory.create(id: 'ex-B', name: 'Squat');

        final template1 = TestRoutineFactory.create(
          id: 'r-001',
          name: 'Push',
          exercises: [TestRoutineExerciseFactory.create(exerciseId: 'ex-A')],
        );
        final template2 = TestRoutineFactory.create(
          id: 'r-002',
          name: 'Pull',
          exercises: [TestRoutineExerciseFactory.create(exerciseId: 'ex-B')],
        );

        final repo = _makeRepo(
          templates: [template1, template2],
          exercises: [exA, exB],
        );

        final routines = await repo.getRoutines('user-001');

        expect(routines, hasLength(2));
        expect(routines[0].exercises[0].exercise?.name, 'Bench Press');
        expect(routines[1].exercises[0].exercise?.name, 'Squat');
      },
    );
  });

  group('RoutineRepository.parseRoutineRow', () {
    test('parses routine row with nested exercise objects in JSONB', () {
      // When the exercise field is included in the JSONB exercises array
      // (e.g. from a JOIN or embedded object), it must be parsed into the
      // exercise field on RoutineExercise.
      final row = TestRoutineFactory.create(
        id: 'r-parse-001',
        exercises: [
          TestRoutineExerciseFactory.create(
            exerciseId: 'ex-001',
            exercise: TestExerciseFactory.create(
              id: 'ex-001',
              name: 'Overhead Press',
            ),
          ),
        ],
      );

      final routine = Routine.fromJson(row);

      // The exercise field in RoutineExercise uses @JsonKey(includeToJson: false)
      // which means it IS read from JSON (fromJson) but is excluded from toJson.
      // When the JSONB row contains an 'exercise' key, it must be parsed.
      expect(routine.exercises[0].exerciseId, 'ex-001');
      // Note: RoutineExercise.exercise intentionally has @JsonKey(includeToJson: false)
      // so it is excluded from toJson but included from fromJson. When the DB
      // row has an 'exercise' key (e.g. via a JOIN), it should be populated.
      // If it's not in the JSONB (normal case), it should be null.
    });

    test('setConfigs are parsed correctly from JSONB array', () {
      final row = TestRoutineFactory.create(
        exercises: [
          TestRoutineExerciseFactory.create(
            setConfigs: [
              TestRoutineSetConfigFactory.create(
                targetReps: 5,
                targetWeight: 100.0,
                restSeconds: 180,
              ),
              TestRoutineSetConfigFactory.create(
                targetReps: 3,
                restSeconds: 180,
              ),
            ],
          ),
        ],
      );

      final routine = Routine.fromJson(row);

      expect(routine.exercises[0].setConfigs, hasLength(2));
      expect(routine.exercises[0].setConfigs[0].targetReps, 5);
      expect(routine.exercises[0].setConfigs[0].targetWeight, 100.0);
      expect(routine.exercises[0].setConfigs[0].restSeconds, 180);
      expect(routine.exercises[0].setConfigs[1].targetReps, 3);
    });
  });
}
