import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/offline/offline_queue_service.dart';
import 'package:gymbuddy_app/core/offline/pending_action.dart';
import 'package:gymbuddy_app/core/offline/pending_sync_provider.dart';
import 'package:gymbuddy_app/features/personal_records/data/pr_repository.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/models/workout_exercise.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockWorkoutRepository extends Mock implements WorkoutRepository {}

class _MockPRRepository extends Mock implements PRRepository {}

class _FakeWorkout extends Fake implements Workout {}

class _FakeWorkoutExercise extends Fake implements WorkoutExercise {}

class _FakeExerciseSet extends Fake implements ExerciseSet {}

class _FakePersonalRecord extends Fake implements PersonalRecord {}

/// Returns a minimal workout JSON map that [Workout.fromJson] can parse.
Map<String, dynamic> _workoutJson({
  String id = 'w-001',
  String userId = 'user-1',
  DateTime? queuedAt,
}) {
  final now = queuedAt ?? DateTime.utc(2026, 4, 17, 12, 0, 0);
  return {
    'id': id,
    'user_id': userId,
    'name': 'Push Day',
    'started_at': now.toIso8601String(),
    'finished_at': now.toIso8601String(),
    'duration_seconds': 3600,
    'is_active': false,
    'notes': null,
    'created_at': now.toIso8601String(),
  };
}

/// Builds a minimal [PendingSaveWorkout] for use in tests.
PendingSaveWorkout makeSaveWorkoutAction({
  String id = 'w-001',
  String userId = 'user-1',
  DateTime? queuedAt,
}) {
  final now = queuedAt ?? DateTime.utc(2026, 4, 17, 12, 0, 0);
  return PendingAction.saveWorkout(
        id: id,
        workoutJson: _workoutJson(id: id, userId: userId, queuedAt: queuedAt),
        exercisesJson: const [],
        setsJson: const [],
        userId: userId,
        queuedAt: now,
      )
      as PendingSaveWorkout;
}

/// Builds a minimal [PendingUpsertRecords] for use in tests.
PendingUpsertRecords makeUpsertRecordsAction({
  String id = 'pr-action-1',
  DateTime? queuedAt,
}) {
  final now = queuedAt ?? DateTime.utc(2026, 4, 17, 12, 0, 0);
  return PendingAction.upsertRecords(
        id: id,
        recordsJson: const [],
        queuedAt: now,
      )
      as PendingUpsertRecords;
}

void main() {
  group('PendingSyncNotifier', () {
    late Directory tempDir;
    late OfflineQueueService queueService;
    late _MockWorkoutRepository mockWorkoutRepo;
    late _MockPRRepository mockPRRepo;
    late ProviderContainer container;
    final now = DateTime.utc(2026, 4, 17, 12, 0, 0);

    setUpAll(() {
      registerFallbackValue(_FakeWorkout());
      registerFallbackValue(_FakeWorkoutExercise());
      registerFallbackValue(_FakeExerciseSet());
      registerFallbackValue(_FakePersonalRecord());
      registerFallbackValue(<WorkoutExercise>[]);
      registerFallbackValue(<ExerciseSet>[]);
      registerFallbackValue(<PersonalRecord>[]);
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_sync_notifier_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('offline_queue');

      queueService = const OfflineQueueService();
      mockWorkoutRepo = _MockWorkoutRepository();
      mockPRRepo = _MockPRRepository();

      container = ProviderContainer(
        overrides: [
          offlineQueueServiceProvider.overrideWithValue(queueService),
          workoutRepositoryProvider.overrideWithValue(mockWorkoutRepo),
          prRepositoryProvider.overrideWithValue(mockPRRepo),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    // ------------------------------------------------------------------ build
    group('build', () {
      test('initial state reflects current queue length (empty)', () {
        final count = container.read(pendingSyncProvider);
        expect(count, 0);
      });

      test('initial state reflects current queue length (non-empty)', () async {
        await queueService.enqueue(makeSaveWorkoutAction(id: 'w-1'));
        await queueService.enqueue(makeSaveWorkoutAction(id: 'w-2'));

        // Rebuild a fresh container so build() reads the pre-seeded box.
        final freshContainer = ProviderContainer(
          overrides: [
            offlineQueueServiceProvider.overrideWithValue(queueService),
            workoutRepositoryProvider.overrideWithValue(mockWorkoutRepo),
            prRepositoryProvider.overrideWithValue(mockPRRepo),
          ],
        );
        addTearDown(freshContainer.dispose);

        expect(freshContainer.read(pendingSyncProvider), 2);
      });
    });

    // ---------------------------------------------------------------- enqueue
    group('enqueue', () {
      test('enqueue increments state count', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        expect(container.read(pendingSyncProvider), 0);

        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-1'));

        expect(container.read(pendingSyncProvider), 1);
      });

      test('getAll returns the enqueued item', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        final action = makeSaveWorkoutAction(id: 'w-unique');

        await notifier.enqueue(action);

        final all = notifier.getAll();
        expect(all, hasLength(1));
        expect(all.first.id, 'w-unique');
      });

      test(
        'same ID enqueued twice results in only one item (last-write-wins)',
        () async {
          final notifier = container.read(pendingSyncProvider.notifier);
          final first = makeSaveWorkoutAction(id: 'w-dup', queuedAt: now);
          final second = first.copyWith(
            workoutJson: {...first.workoutJson, 'name': 'Updated'},
          );

          await notifier.enqueue(first);
          await notifier.enqueue(second);

          final all = notifier.getAll();
          // Hive uses the ID as key → second write overwrites first.
          expect(all, hasLength(1));
          expect(all.first.id, 'w-dup');
          final saved = all.first as PendingSaveWorkout;
          expect(saved.workoutJson['name'], 'Updated');
        },
      );
    });

    // --------------------------------------------------------------- retryItem
    group('retryItem — PendingSaveWorkout', () {
      test('success: dequeues item and decrements count', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        final action = makeSaveWorkoutAction(id: 'w-retry');
        await notifier.enqueue(action);
        expect(container.read(pendingSyncProvider), 1);

        // saveWorkout succeeds.
        when(
          () => mockWorkoutRepo.saveWorkout(
            workout: any(named: 'workout'),
            exercises: any(named: 'exercises'),
            sets: any(named: 'sets'),
          ),
        ).thenAnswer((_) async {
          // Return a minimal Workout — the value is discarded by retryItem.
          return Workout.fromJson(_workoutJson(id: 'w-retry'));
        });

        await notifier.retryItem('w-retry');

        expect(container.read(pendingSyncProvider), 0);
        expect(notifier.getAll(), isEmpty);
      });

      test('success: does not throw', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        final action = makeSaveWorkoutAction(id: 'w-ok');
        await notifier.enqueue(action);

        when(
          () => mockWorkoutRepo.saveWorkout(
            workout: any(named: 'workout'),
            exercises: any(named: 'exercises'),
            sets: any(named: 'sets'),
          ),
        ).thenAnswer((_) async => Workout.fromJson(_workoutJson(id: 'w-ok')));

        await expectLater(notifier.retryItem('w-ok'), completes);
      });

      test(
        'failure: item stays in queue, retryCount incremented, rethrows',
        () async {
          final notifier = container.read(pendingSyncProvider.notifier);
          final action = makeSaveWorkoutAction(id: 'w-fail');
          await notifier.enqueue(action);

          when(
            () => mockWorkoutRepo.saveWorkout(
              workout: any(named: 'workout'),
              exercises: any(named: 'exercises'),
              sets: any(named: 'sets'),
            ),
          ).thenThrow(Exception('Network timeout'));

          await expectLater(
            notifier.retryItem('w-fail'),
            throwsA(isA<Exception>()),
          );

          // Item must still be in queue.
          final all = notifier.getAll();
          expect(all, hasLength(1));
          expect(all.first.id, 'w-fail');

          // retryCount must have been incremented.
          final updated = all.first as PendingSaveWorkout;
          expect(updated.retryCount, 1);
        },
      );

      test('failure: lastError is stored on the action', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        final action = makeSaveWorkoutAction(id: 'w-err');
        await notifier.enqueue(action);

        when(
          () => mockWorkoutRepo.saveWorkout(
            workout: any(named: 'workout'),
            exercises: any(named: 'exercises'),
            sets: any(named: 'sets'),
          ),
        ).thenThrow(Exception('Connection refused'));

        await expectLater(
          notifier.retryItem('w-err'),
          throwsA(isA<Exception>()),
        );

        final updated = notifier.getAll().first as PendingSaveWorkout;
        expect(updated.lastError, contains('Connection refused'));
      });

      test(
        'failure: retryCount accumulates across multiple failed retries',
        () async {
          final notifier = container.read(pendingSyncProvider.notifier);
          final action = makeSaveWorkoutAction(id: 'w-multi');
          await notifier.enqueue(action);

          when(
            () => mockWorkoutRepo.saveWorkout(
              workout: any(named: 'workout'),
              exercises: any(named: 'exercises'),
              sets: any(named: 'sets'),
            ),
          ).thenThrow(Exception('Always fails'));

          // Retry 3 times.
          for (var i = 0; i < 3; i++) {
            try {
              await notifier.retryItem('w-multi');
            } catch (_) {}
          }

          final updated = notifier.getAll().first as PendingSaveWorkout;
          expect(updated.retryCount, 3);
        },
      );

      test('count stays consistent after failed retry', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-count'));
        expect(container.read(pendingSyncProvider), 1);

        when(
          () => mockWorkoutRepo.saveWorkout(
            workout: any(named: 'workout'),
            exercises: any(named: 'exercises'),
            sets: any(named: 'sets'),
          ),
        ).thenThrow(Exception('Offline'));

        try {
          await notifier.retryItem('w-count');
        } catch (_) {}

        // Count should remain 1 — item was not removed.
        expect(container.read(pendingSyncProvider), 1);
      });
    });

    group('retryItem — edge cases', () {
      test('retryItem for nonexistent ID is a silent no-op', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-exists'));

        // Should not throw and should not dequeue the wrong item.
        await expectLater(notifier.retryItem('w-nonexistent'), completes);

        expect(notifier.getAll(), hasLength(1));
      });

      test('retryItem on empty queue is a silent no-op', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        expect(notifier.getAll(), isEmpty);

        await expectLater(notifier.retryItem('w-anything'), completes);
      });
    });

    // ---------------------------------------------------- getAll
    group('getAll', () {
      test('returns actions sorted by queuedAt ascending', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        final t1 = now;
        final t2 = now.add(const Duration(hours: 1));
        final t3 = now.subtract(const Duration(hours: 1));

        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-t1', queuedAt: t1));
        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-t2', queuedAt: t2));
        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-t3', queuedAt: t3));

        final all = notifier.getAll();
        expect(all[0].id, 'w-t3'); // earliest
        expect(all[1].id, 'w-t1');
        expect(all[2].id, 'w-t2'); // latest
      });

      test('skips corrupt entries gracefully', () async {
        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(makeSaveWorkoutAction(id: 'w-good'));

        // Inject a corrupt entry directly.
        await Hive.box<dynamic>(
          'offline_queue',
        ).put('bad-key', 'not valid json');

        final all = notifier.getAll();
        expect(all, hasLength(1));
        expect(all.first.id, 'w-good');
      });
    });
  });
}
