import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('CacheService', () {
    late Directory tempDir;
    const testBox = 'test_cache_box';
    const service = CacheService();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_cache_test_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(testBox);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    group('read', () {
      test('returns deserialized value from Hive box', () async {
        final data = {'name': 'Bench Press', 'reps': 10};
        await Hive.box<dynamic>(testBox).put('exercise', jsonEncode(data));

        final result = service.read<Map<String, dynamic>>(
          testBox,
          'exercise',
          (json) => json as Map<String, dynamic>,
        );

        expect(result, isNotNull);
        expect(result!['name'], 'Bench Press');
        expect(result['reps'], 10);
      });

      test('returns null when key does not exist', () {
        final result = service.read<Map<String, dynamic>>(
          testBox,
          'nonexistent',
          (json) => json as Map<String, dynamic>,
        );

        expect(result, isNull);
      });

      test('returns null when JSON is corrupt', () async {
        await Hive.box<dynamic>(testBox).put('corrupt', 'not valid json {{{');

        final result = service.read<Map<String, dynamic>>(
          testBox,
          'corrupt',
          (json) => json as Map<String, dynamic>,
        );

        expect(result, isNull);
      });

      test('returns null when box is not open', () {
        final result = service.read<Map<String, dynamic>>(
          'nonexistent_box',
          'key',
          (json) => json as Map<String, dynamic>,
        );

        expect(result, isNull);
      });

      test('returns null when fromJson callback throws', () async {
        await Hive.box<dynamic>(testBox).put('bad_type', jsonEncode(42));

        // fromJson tries to cast an int to Map — this will throw at runtime.
        final result = service.read<Map<String, dynamic>>(
          testBox,
          'bad_type',
          (json) => (json as Map<String, dynamic>), // cast will fail on int
        );

        expect(result, isNull);
      });
    });

    group('write', () {
      test('stores JSON string to Hive box', () async {
        final data = {'exercise': 'Squat', 'weight': 100};

        await service.write(testBox, 'my_key', data);

        final raw = Hive.box<dynamic>(testBox).get('my_key') as String;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded['exercise'], 'Squat');
        expect(decoded['weight'], 100);
      });

      test('overwrites existing key with new value', () async {
        await service.write(testBox, 'overwrite_key', {'v': 1});
        await service.write(testBox, 'overwrite_key', {'v': 2});

        final raw = Hive.box<dynamic>(testBox).get('overwrite_key') as String;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded['v'], 2);
      });

      test('does not throw when value is not JSON-encodable', () async {
        // A value that jsonEncode cannot handle (e.g., a Dart object with
        // no toJson) should be caught and swallowed, not crash the app.
        await expectLater(
          service.write(testBox, 'bad_value', Object()),
          completes,
        );
        // Key must not have been written since encoding failed.
        expect(Hive.box<dynamic>(testBox).get('bad_value'), isNull);
      });

      test('does not throw on error', () async {
        // Writing to a box that is not open should not throw.
        await expectLater(
          service.write('nonexistent_box', 'key', {'data': true}),
          completes,
        );
      });
    });

    group('delete', () {
      test('removes key from box', () async {
        await Hive.box<dynamic>(testBox).put('to_delete', 'value');
        expect(Hive.box<dynamic>(testBox).get('to_delete'), isNotNull);

        await service.delete(testBox, 'to_delete');

        expect(Hive.box<dynamic>(testBox).get('to_delete'), isNull);
      });

      test('does not throw when key does not exist', () async {
        await expectLater(service.delete(testBox, 'nonexistent'), completes);
      });

      test('does not throw when box is not open', () async {
        await expectLater(service.delete('nonexistent_box', 'key'), completes);
      });
    });

    group('clearBox', () {
      test('clears all entries in box', () async {
        final box = Hive.box<dynamic>(testBox);
        await box.put('key1', 'value1');
        await box.put('key2', 'value2');
        expect(box.length, 2);

        await service.clearBox(testBox);

        expect(box.length, 0);
      });

      test('does not throw when box is not open', () async {
        await expectLater(service.clearBox('nonexistent_box'), completes);
      });
    });
  });
}
