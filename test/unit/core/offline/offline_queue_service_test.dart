import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/observability/sentry_report.dart';
import 'package:repsaga/core/offline/offline_queue_service.dart';
import 'package:repsaga/core/offline/pending_action.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('OfflineQueueService', () {
    late Directory tempDir;
    const service = OfflineQueueService();
    final now = DateTime.utc(2026, 4, 17, 12, 0, 0);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_offline_queue_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('offline_queue');
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    PendingAction makeSaveWorkout(String id, {DateTime? queuedAt}) {
      return PendingAction.saveWorkout(
        id: id,
        workoutJson: {'id': id},
        exercisesJson: const [],
        setsJson: const [],
        userId: 'user-1',
        queuedAt: queuedAt ?? now,
      );
    }

    test('enqueue stores action and increments pendingCount', () async {
      expect(service.pendingCount, 0);

      await service.enqueue(makeSaveWorkout('w-1'));

      expect(service.pendingCount, 1);
    });

    test('dequeue removes action and decrements pendingCount', () async {
      await service.enqueue(makeSaveWorkout('w-1'));
      expect(service.pendingCount, 1);

      await service.dequeue('w-1');

      expect(service.pendingCount, 0);
    });

    test('dequeue does not throw for nonexistent key', () async {
      await expectLater(service.dequeue('nonexistent'), completes);
    });

    test('getAll returns actions sorted by queuedAt', () async {
      final later = now.add(const Duration(hours: 1));
      final earlier = now.subtract(const Duration(hours: 1));

      await service.enqueue(makeSaveWorkout('w-now', queuedAt: now));
      await service.enqueue(makeSaveWorkout('w-later', queuedAt: later));
      await service.enqueue(makeSaveWorkout('w-earlier', queuedAt: earlier));

      final all = service.getAll();

      expect(all.length, 3);
      expect(all[0].id, 'w-earlier');
      expect(all[1].id, 'w-now');
      expect(all[2].id, 'w-later');
    });

    test('getAll skips corrupt entries silently', () async {
      // Write valid action
      await service.enqueue(makeSaveWorkout('w-valid'));
      // Write corrupt data directly
      await Hive.box<dynamic>('offline_queue').put('bad', 'not valid json');

      final all = service.getAll();

      expect(all.length, 1);
      expect(all.first.id, 'w-valid');
    });

    test('updateAction overwrites existing entry', () async {
      final original = makeSaveWorkout('w-1');
      await service.enqueue(original);

      final updated = (original as PendingSaveWorkout).copyWith(
        retryCount: 2,
        lastError: 'timeout',
      );
      await service.updateAction(updated);

      final all = service.getAll();
      expect(all.length, 1);
      final restored = all.first as PendingSaveWorkout;
      expect(restored.retryCount, 2);
      expect(restored.lastError, 'timeout');
    });

    test('pendingCount reflects all item types', () async {
      await service.enqueue(makeSaveWorkout('w-1'));
      await service.enqueue(
        PendingAction.upsertRecords(
          id: 'pr-1',
          recordsJson: const [],
          userId: 'user-1',
          queuedAt: now,
        ),
      );
      await service.enqueue(
        PendingAction.markRoutineComplete(
          id: 'rc-1',
          planId: 'p-1',
          routineId: 'r-1',
          workoutId: 'w-1',
          queuedAt: now,
        ),
      );

      expect(service.pendingCount, 3);
    });

    // ----------------------------------------------------------------
    // BUG-007: Hive failures must rethrow + capture to Sentry. Without
    // these guarantees: a silently-swallowed enqueue loses user data, a
    // swallowed dequeue causes duplicate replays, a swallowed
    // updateAction breaks retryCount monotonicity (loops forever past
    // kMaxSyncRetries). `getAll` keeps its skip-corrupt behavior — one
    // bad row must not block the whole queue — but must capture too so
    // we get production rates on corruption.
    // ----------------------------------------------------------------
    group('BUG-007: Hive failures rethrow and capture to Sentry', () {
      late int captureCount;
      late Object? lastCapturedError;

      setUp(() {
        captureCount = 0;
        lastCapturedError = null;
        SentryReport.debugSetCaptureFn((error, {stackTrace}) async {
          captureCount++;
          lastCapturedError = error;
          return const SentryId.empty();
        });
      });

      tearDown(() {
        SentryReport.debugSetCaptureFn(null);
      });

      test(
        'enqueue rethrows when the queue box is closed and captures to Sentry',
        () async {
          // Close the box so the underlying Hive call throws.
          await Hive.box<dynamic>('offline_queue').close();

          await expectLater(
            service.enqueue(makeSaveWorkout('w-fail-enqueue')),
            throwsA(isA<Object>()),
          );

          // Sentry forwarding must have fired exactly once.
          expect(captureCount, 1);
          expect(lastCapturedError, isNotNull);
        },
      );

      test(
        'dequeue rethrows when the queue box is closed and captures to Sentry',
        () async {
          // Pre-populate so dequeue has something to attempt.
          await service.enqueue(makeSaveWorkout('w-stale'));
          await Hive.box<dynamic>('offline_queue').close();

          await expectLater(service.dequeue('w-stale'), throwsA(isA<Object>()));
          expect(captureCount, 1);
        },
      );

      test(
        'updateAction rethrows when the queue box is closed and captures',
        () async {
          final original =
              makeSaveWorkout('w-update-fail') as PendingSaveWorkout;
          await service.enqueue(original);
          await Hive.box<dynamic>('offline_queue').close();

          final updated = original.copyWith(
            retryCount: 1,
            lastError: 'attempt 1',
          );

          await expectLater(
            service.updateAction(updated),
            throwsA(isA<Object>()),
          );
          expect(captureCount, 1);
        },
      );

      test(
        'getAll skips corrupt rows AND captures each skip to Sentry',
        () async {
          // Two corrupt rows + one valid.
          await service.enqueue(makeSaveWorkout('w-valid-2'));
          await Hive.box<dynamic>('offline_queue').put('bad-1', 'not json');
          await Hive.box<dynamic>('offline_queue').put('bad-2', '{not:valid}');

          final all = service.getAll();

          // Skip-corrupt invariant intact — one valid row only.
          expect(all.length, 1);
          expect(all.first.id, 'w-valid-2');

          // BUG-007: each corrupt skip must capture to Sentry so we get
          // production rates on corruption.
          expect(captureCount, 2);
        },
      );
    });

    test('getAll deserializes all four action types', () async {
      await service.enqueue(makeSaveWorkout('w-1'));
      await service.enqueue(
        PendingAction.upsertRecords(
          id: 'pr-1',
          recordsJson: const [],
          userId: 'user-1',
          queuedAt: now.add(const Duration(seconds: 1)),
        ),
      );
      await service.enqueue(
        PendingAction.markRoutineComplete(
          id: 'rc-1',
          planId: 'p-1',
          routineId: 'r-1',
          workoutId: 'w-1',
          queuedAt: now.add(const Duration(seconds: 2)),
        ),
      );
      // BUG-003: PendingCreateExercise was added in this PR; ensure the
      // round-trip serialization works so a schema change is caught here.
      await service.enqueue(
        PendingAction.createExercise(
          id: 'ce-1',
          exerciseId: 'ex-local-1',
          userId: 'user-1',
          locale: 'en',
          name: 'Custom Bench',
          muscleGroup: 'chest',
          equipmentType: 'barbell',
          queuedAt: now.add(const Duration(seconds: 3)),
        ),
      );

      final all = service.getAll();
      expect(all.length, 4);
      expect(all[0], isA<PendingSaveWorkout>());
      expect(all[1], isA<PendingUpsertRecords>());
      expect(all[2], isA<PendingMarkRoutineComplete>());
      expect(all[3], isA<PendingCreateExercise>());

      // Verify field-level round-trip for the new type.
      final ce = all[3] as PendingCreateExercise;
      expect(ce.id, 'ce-1');
      expect(ce.exerciseId, 'ex-local-1');
      expect(ce.name, 'Custom Bench');
      expect(ce.muscleGroup, 'chest');
      expect(ce.equipmentType, 'barbell');
    });
  });
}
