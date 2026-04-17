import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/cache_service.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/features/personal_records/data/pr_repository.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';
import 'package:hive/hive.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../_helpers/fake_supabase.dart';

void main() {
  late Directory tempDir;
  late CacheService cache;
  late Box<dynamic> prBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pr_cache_test_');
    Hive.init(tempDir.path);
    prBox = await Hive.openBox<dynamic>(HiveService.prCache);
    cache = const CacheService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('PRRepository cache - getRecordsForUser', () {
    test('caches and returns cached on failure', () async {
      // Pre-populate cache.
      final prJson = [
        TestPersonalRecordFactory.create(
          id: 'pr-1',
          userId: 'user-001',
          value: 120.0,
        ),
        TestPersonalRecordFactory.create(
          id: 'pr-2',
          userId: 'user-001',
          recordType: 'max_reps',
          value: 15.0,
        ),
      ];
      await prBox.put('user-001', jsonEncode(prJson));

      // Create repo with a failing client.
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = PRRepository(client, cache);

      final result = await repo.getRecordsForUser('user-001');

      expect(result, hasLength(2));
      expect(result[0].id, 'pr-1');
      expect(result[0].value, 120.0);
      expect(result[1].recordType, RecordType.maxReps);
    });

    test('rethrows when no cache and network fails', () async {
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = PRRepository(client, cache);

      await expectLater(
        repo.getRecordsForUser('user-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('PRRepository cache - getRecordsForExercises', () {
    test('caches by sorted exercise IDs', () async {
      // Pre-populate cache with a sorted key.
      final prData = {
        'ex-1': [
          TestPersonalRecordFactory.create(
            id: 'pr-1',
            exerciseId: 'ex-1',
            value: 100.0,
          ),
        ],
        'ex-2': [
          TestPersonalRecordFactory.create(
            id: 'pr-2',
            exerciseId: 'ex-2',
            value: 200.0,
          ),
        ],
      };
      // The key is "exercises:" + sorted IDs joined by commas.
      const key = 'exercises:ex-1,ex-2';
      await prBox.put(key, jsonEncode(prData));

      // Create repo with a failing client.
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = PRRepository(client, cache);

      // Pass IDs in reverse order — the repo sorts them to build the key.
      final result = await repo.getRecordsForExercises(['ex-2', 'ex-1']);

      expect(result.keys, containsAll(['ex-1', 'ex-2']));
      expect(result['ex-1'], hasLength(1));
      expect(result['ex-1']![0].value, 100.0);
      expect(result['ex-2']![0].value, 200.0);
    });

    test(
      'returns empty map for empty exercise IDs (no cache interaction)',
      () async {
        final client = FakeSupabaseClient(FakeQueryBuilder());
        final repo = PRRepository(client, cache);

        final result = await repo.getRecordsForExercises([]);

        expect(result, isEmpty);
        // Nothing written to cache either.
        expect(prBox.isEmpty, isTrue);
      },
    );

    test('rethrows when no cache and network fails', () async {
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = PRRepository(client, cache);

      await expectLater(
        repo.getRecordsForExercises(['ex-missing']),
        throwsA(isA<Exception>()),
      );
    });

    test('single exercise ID produces correct cache key', () async {
      final prData = {
        'ex-only': [
          TestPersonalRecordFactory.create(
            id: 'pr-1',
            exerciseId: 'ex-only',
            value: 75.0,
          ),
        ],
      };
      // Single ID: key is "exercises:ex-only" (no comma).
      await prBox.put('exercises:ex-only', jsonEncode(prData));

      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = PRRepository(client, cache);

      final result = await repo.getRecordsForExercises(['ex-only']);

      expect(result['ex-only'], hasLength(1));
      expect(result['ex-only']![0].value, 75.0);
    });
  });

  group('PRRepository cache - getRecordsForUser write path', () {
    test(
      'fresh data is written and readable on subsequent offline call',
      () async {
        final prRow = TestPersonalRecordFactory.create(
          id: 'pr-written',
          userId: 'user-001',
          value: 150.0,
        );
        // First call: network succeeds and writes to cache.
        final onlineClient = FakeSupabaseClient(
          FakeQueryBuilder(data: [prRow]),
        );
        await PRRepository(onlineClient, cache).getRecordsForUser('user-001');

        // Second call: network fails — must return data from cache written above.
        final offlineClient = FakeSupabaseClient(
          FakeQueryBuilder(error: Exception('offline')),
        );
        final result = await PRRepository(
          offlineClient,
          cache,
        ).getRecordsForUser('user-001');

        expect(result, hasLength(1));
        expect(result[0].id, 'pr-written');
        expect(result[0].value, 150.0);
      },
    );
  });
}
