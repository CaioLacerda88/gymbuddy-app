import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/offline/pending_action.dart';

void main() {
  group('PendingAction serialization', () {
    final now = DateTime.utc(2026, 4, 17, 12, 0, 0);

    group('PendingSaveWorkout', () {
      test('roundtrips through toJson/fromJson', () {
        final action = PendingAction.saveWorkout(
          id: 'w-001',
          workoutJson: {'id': 'w-001', 'user_id': 'u-1', 'name': 'Push Day'},
          exercisesJson: [
            {'id': 'we-1', 'exercise_id': 'e-1', 'order': 0},
          ],
          setsJson: [
            {
              'id': 's-1',
              'workout_exercise_id': 'we-1',
              'set_number': 1,
              'weight': 60.0,
            },
          ],
          userId: 'u-1',
          queuedAt: now,
        );

        final json = action.toJson();
        final restored = PendingAction.fromJson(json);

        expect(restored, isA<PendingSaveWorkout>());
        final typed = restored as PendingSaveWorkout;
        expect(typed.id, 'w-001');
        expect(typed.workoutJson['name'], 'Push Day');
        expect(typed.exercisesJson.length, 1);
        expect(typed.setsJson.length, 1);
        expect(typed.userId, 'u-1');
        expect(typed.queuedAt, now);
        expect(typed.retryCount, 0);
        expect(typed.lastError, isNull);
      });

      test('preserves retryCount and lastError', () {
        final action = PendingAction.saveWorkout(
          id: 'w-002',
          workoutJson: {'id': 'w-002'},
          exercisesJson: const [],
          setsJson: const [],
          userId: 'u-1',
          queuedAt: now,
          retryCount: 3,
          lastError: 'NetworkException: timeout',
        );

        final json = action.toJson();
        final restored = PendingAction.fromJson(json);

        final typed = restored as PendingSaveWorkout;
        expect(typed.retryCount, 3);
        expect(typed.lastError, 'NetworkException: timeout');
      });
    });

    group('PendingUpsertRecords', () {
      test('roundtrips through toJson/fromJson', () {
        final action = PendingAction.upsertRecords(
          id: 'pr-action-1',
          recordsJson: [
            {
              'id': 'pr-1',
              'user_id': 'u-1',
              'exercise_id': 'e-1',
              'record_type': 'max_weight',
              'value': 100.0,
              'achieved_at': now.toIso8601String(),
            },
          ],
          queuedAt: now,
        );

        final json = action.toJson();
        final restored = PendingAction.fromJson(json);

        expect(restored, isA<PendingUpsertRecords>());
        final typed = restored as PendingUpsertRecords;
        expect(typed.id, 'pr-action-1');
        expect(typed.recordsJson.length, 1);
        expect(typed.recordsJson.first['value'], 100.0);
        expect(typed.queuedAt, now);
        expect(typed.retryCount, 0);
      });
    });

    group('PendingMarkRoutineComplete', () {
      test('roundtrips through toJson/fromJson', () {
        final action = PendingAction.markRoutineComplete(
          id: 'rc-action-1',
          planId: 'plan-1',
          routineId: 'routine-1',
          workoutId: 'w-001',
          queuedAt: now,
        );

        final json = action.toJson();
        final restored = PendingAction.fromJson(json);

        expect(restored, isA<PendingMarkRoutineComplete>());
        final typed = restored as PendingMarkRoutineComplete;
        expect(typed.id, 'rc-action-1');
        expect(typed.planId, 'plan-1');
        expect(typed.routineId, 'routine-1');
        expect(typed.workoutId, 'w-001');
        expect(typed.queuedAt, now);
      });
    });

    test('discriminator field is set correctly', () {
      expect(
        PendingAction.saveWorkout(
          id: '1',
          workoutJson: const {},
          exercisesJson: const [],
          setsJson: const [],
          userId: 'u',
          queuedAt: now,
        ).toJson()['type'],
        'saveWorkout',
      );
      expect(
        PendingAction.upsertRecords(
          id: '2',
          recordsJson: const [],
          queuedAt: now,
        ).toJson()['type'],
        'upsertRecords',
      );
      expect(
        PendingAction.markRoutineComplete(
          id: '3',
          planId: 'p',
          routineId: 'r',
          workoutId: 'w',
          queuedAt: now,
        ).toJson()['type'],
        'markRoutineComplete',
      );
    });
  });
}
