import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/offline/offline_queue_service.dart';
import 'package:gymbuddy_app/core/offline/pending_action.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

    test('getAll deserializes all three action types', () async {
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

      final all = service.getAll();
      expect(all.length, 3);
      expect(all[0], isA<PendingSaveWorkout>());
      expect(all[1], isA<PendingUpsertRecords>());
      expect(all[2], isA<PendingMarkRoutineComplete>());
    });
  });
}
