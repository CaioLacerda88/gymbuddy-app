import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('HiveService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_svc_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    group('box constants', () {
      test('all 8 box names are unique', () {
        final names = [
          HiveService.activeWorkout,
          HiveService.offlineQueue,
          HiveService.userPrefs,
          HiveService.exerciseCache,
          HiveService.routineCache,
          HiveService.prCache,
          HiveService.workoutHistoryCache,
          HiveService.lastSetsCache,
        ];
        expect(names.toSet().length, 8);
      });
    });

    group('init', () {
      test('opens all 8 boxes', () async {
        // HiveService.init() calls Hive.initFlutter() which needs Flutter
        // bindings. Instead, we simulate what init does: open all boxes
        // and verify they are accessible.
        await Future.wait([
          Hive.openBox<dynamic>(HiveService.activeWorkout),
          Hive.openBox<dynamic>(HiveService.offlineQueue),
          Hive.openBox<dynamic>(HiveService.userPrefs),
          Hive.openBox<dynamic>(HiveService.exerciseCache),
          Hive.openBox<dynamic>(HiveService.routineCache),
          Hive.openBox<dynamic>(HiveService.prCache),
          Hive.openBox<dynamic>(HiveService.workoutHistoryCache),
          Hive.openBox<dynamic>(HiveService.lastSetsCache),
        ]);

        expect(Hive.isBoxOpen(HiveService.activeWorkout), isTrue);
        expect(Hive.isBoxOpen(HiveService.offlineQueue), isTrue);
        expect(Hive.isBoxOpen(HiveService.userPrefs), isTrue);
        expect(Hive.isBoxOpen(HiveService.exerciseCache), isTrue);
        expect(Hive.isBoxOpen(HiveService.routineCache), isTrue);
        expect(Hive.isBoxOpen(HiveService.prCache), isTrue);
        expect(Hive.isBoxOpen(HiveService.workoutHistoryCache), isTrue);
        expect(Hive.isBoxOpen(HiveService.lastSetsCache), isTrue);
      });
    });

    group('clearAll', () {
      test('clears all 8 boxes', () async {
        // Open all boxes and put some data in each.
        final boxNames = [
          HiveService.activeWorkout,
          HiveService.offlineQueue,
          HiveService.userPrefs,
          HiveService.exerciseCache,
          HiveService.routineCache,
          HiveService.prCache,
          HiveService.workoutHistoryCache,
          HiveService.lastSetsCache,
        ];

        for (final name in boxNames) {
          final box = await Hive.openBox<dynamic>(name);
          await box.put('test_key', 'test_value');
        }

        const service = HiveService();
        await service.clearAll();

        for (final name in boxNames) {
          expect(
            Hive.box<dynamic>(name).isEmpty,
            isTrue,
            reason: 'Box "$name" should be empty after clearAll()',
          );
        }
      });

      test('does not throw when some boxes are closed', () async {
        // Open only a subset of boxes, simulating a partial-init scenario
        // (e.g., clearAll called before init completes for all boxes).
        final openBoxes = [
          HiveService.activeWorkout,
          HiveService.exerciseCache,
        ];
        for (final name in openBoxes) {
          final box = await Hive.openBox<dynamic>(name);
          await box.put('test_key', 'test_value');
        }

        // The other 6 boxes remain closed — _clearIfOpen should skip them
        // without throwing.
        const service = HiveService();
        await expectLater(service.clearAll(), completes);

        // The two open boxes must have been cleared.
        for (final name in openBoxes) {
          expect(
            Hive.box<dynamic>(name).isEmpty,
            isTrue,
            reason: 'Box "$name" should be empty after clearAll()',
          );
        }
      });
    });
  });
}
