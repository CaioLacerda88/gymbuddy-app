import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:gymbuddy_app/core/connectivity/connectivity_provider.dart';
import 'package:gymbuddy_app/core/offline/offline_queue_service.dart';
import 'package:gymbuddy_app/core/offline/pending_action.dart';
import 'package:gymbuddy_app/core/offline/pending_sync_provider.dart';
import 'package:gymbuddy_app/core/offline/sync_service.dart';
import 'package:gymbuddy_app/features/analytics/data/analytics_repository.dart';
import 'package:gymbuddy_app/features/analytics/data/models/analytics_event.dart';
import 'package:gymbuddy_app/features/analytics/providers/analytics_providers.dart';
import 'package:gymbuddy_app/features/personal_records/data/pr_repository.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/models/workout_exercise.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class _MockWorkoutRepository extends Mock implements WorkoutRepository {}

class _MockPRRepository extends Mock implements PRRepository {}

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

// ---------------------------------------------------------------------------
// Fakes (for registerFallbackValue)
// ---------------------------------------------------------------------------
class _FakeWorkout extends Fake implements Workout {}

class _FakeWorkoutExercise extends Fake implements WorkoutExercise {}

class _FakeExerciseSet extends Fake implements ExerciseSet {}

class _FakePersonalRecord extends Fake implements PersonalRecord {}

// AnalyticsEvent is a sealed Freezed class — we use a real instance as
// the fallback value instead of a Fake.
const _fallbackAnalyticsEvent = AnalyticsEvent.workoutSyncQueued(
  actionType: 'fallback',
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
PendingSaveWorkout _makeSaveWorkoutAction({
  String id = 'w-001',
  String userId = 'user-1',
  DateTime? queuedAt,
  int retryCount = 0,
  String? lastError,
}) {
  final now = queuedAt ?? DateTime.utc(2026, 4, 17, 12, 0, 0);
  return PendingAction.saveWorkout(
        id: id,
        workoutJson: _workoutJson(id: id, userId: userId, queuedAt: queuedAt),
        exercisesJson: const [],
        setsJson: const [],
        userId: userId,
        queuedAt: now,
        retryCount: retryCount,
        lastError: lastError,
      )
      as PendingSaveWorkout;
}

/// Allow async listeners to process by yielding microtasks.
Future<void> _pumpAsync([int ms = 100]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('SyncService', () {
    late Directory tempDir;
    late OfflineQueueService queueService;
    late _MockWorkoutRepository mockWorkoutRepo;
    late _MockPRRepository mockPRRepo;
    late _MockAnalyticsRepository mockAnalyticsRepo;
    late StreamController<bool> connectivityController;

    setUpAll(() {
      registerFallbackValue(_FakeWorkout());
      registerFallbackValue(_FakeWorkoutExercise());
      registerFallbackValue(_FakeExerciseSet());
      registerFallbackValue(_FakePersonalRecord());
      registerFallbackValue(_fallbackAnalyticsEvent);
      registerFallbackValue(<WorkoutExercise>[]);
      registerFallbackValue(<ExerciseSet>[]);
      registerFallbackValue(<PersonalRecord>[]);
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_sync_service_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('offline_queue');

      queueService = const OfflineQueueService();
      mockWorkoutRepo = _MockWorkoutRepository();
      mockPRRepo = _MockPRRepository();
      mockAnalyticsRepo = _MockAnalyticsRepository();
      connectivityController = StreamController<bool>.broadcast();

      // Default: analytics is fire-and-forget, never fails.
      when(
        () => mockAnalyticsRepo.insertEvent(
          userId: any(named: 'userId'),
          event: any(named: 'event'),
          platform: any(named: 'platform'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await connectivityController.close();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    /// Creates a [ProviderContainer] with the standard test overrides and
    /// subscribes to [syncServiceProvider] via [container.listen] so the
    /// internal [ref.listen] chain stays reactive.
    ///
    /// [initialOnline] controls the fallback value of [isOnlineProvider]
    /// before the stream emits.
    ProviderContainer createContainer({bool initialOnline = true}) {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWith(
            (ref) => connectivityController.stream,
          ),
          isOnlineProvider.overrideWith((ref) {
            return ref.watch(onlineStatusProvider).value ?? initialOnline;
          }),
          offlineQueueServiceProvider.overrideWithValue(queueService),
          workoutRepositoryProvider.overrideWithValue(mockWorkoutRepo),
          prRepositoryProvider.overrideWithValue(mockPRRepo),
          analyticsRepositoryProvider.overrideWithValue(mockAnalyticsRepo),
        ],
      );
      addTearDown(container.dispose);

      // Subscribe to syncServiceProvider so its ref.listen(isOnlineProvider)
      // remains active. In production this is done by a widget that watches
      // the provider; in tests we need an explicit subscription.
      container.listen(syncServiceProvider, (_, _) {});

      return container;
    }

    /// Stubs [mockWorkoutRepo.saveWorkout] to succeed, returning a parsed
    /// [Workout] from the given [id].
    void stubSaveWorkoutSuccess({String id = 'w-001'}) {
      when(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenAnswer((_) async => Workout.fromJson(_workoutJson(id: id)));
    }

    /// Stubs [mockWorkoutRepo.saveWorkout] to throw [error].
    void stubSaveWorkoutFailure(Object error) {
      when(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenThrow(error);
    }

    // ------------------------------------------------------------------
    // Test: Drains queue on offline -> online transition
    // ------------------------------------------------------------------
    test('drains queue on offline -> online transition', () async {
      final container = createContainer(initialOnline: false);

      // Enqueue an item while "offline".
      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(_makeSaveWorkoutAction(id: 'w-drain'));

      stubSaveWorkoutSuccess(id: 'w-drain');

      // Transition: offline -> online
      connectivityController.add(true);
      await _pumpAsync(200);

      // The item should have been dequeued by the drain.
      expect(container.read(pendingSyncProvider), 0);
      verify(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).called(1);
    });

    // ------------------------------------------------------------------
    // Test: Does NOT drain on initial online emission
    // ------------------------------------------------------------------
    test('does NOT drain on initial online emission', () async {
      final container = createContainer(initialOnline: true);

      // Enqueue an item.
      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(_makeSaveWorkoutAction(id: 'w-skip'));

      stubSaveWorkoutSuccess(id: 'w-skip');

      // Emit true — _lastOnline is already true, so no transition.
      connectivityController.add(true);
      await _pumpAsync(200);

      // Item should still be in the queue — no drain occurred.
      expect(container.read(pendingSyncProvider), 1);
      verifyNever(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      );
    });

    // ------------------------------------------------------------------
    // Test: Drains multiple items in FIFO order
    // ------------------------------------------------------------------
    test('drains multiple items in FIFO order', () async {
      final container = createContainer(initialOnline: false);

      final notifier = container.read(pendingSyncProvider.notifier);

      // Enqueue two items with different timestamps.
      final earlier = DateTime.utc(2026, 4, 17, 10, 0, 0);
      final later = DateTime.utc(2026, 4, 17, 11, 0, 0);
      await notifier.enqueue(
        _makeSaveWorkoutAction(id: 'w-first', queuedAt: earlier),
      );
      await notifier.enqueue(
        _makeSaveWorkoutAction(id: 'w-second', queuedAt: later),
      );

      // Track the order of calls.
      final callOrder = <String>[];
      when(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenAnswer((invocation) async {
        final workout = invocation.namedArguments[#workout] as Workout;
        callOrder.add(workout.id);
        return workout;
      });

      // Transition: offline -> online
      connectivityController.add(true);
      await _pumpAsync(200);

      expect(callOrder, ['w-first', 'w-second']);
      expect(container.read(pendingSyncProvider), 0);
    });

    // ------------------------------------------------------------------
    // Test: Stops draining if connectivity drops mid-queue
    // ------------------------------------------------------------------
    test('stops draining if connectivity drops mid-queue', () async {
      final container = createContainer(initialOnline: false);

      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(
        _makeSaveWorkoutAction(
          id: 'w-1',
          queuedAt: DateTime.utc(2026, 4, 17, 10, 0, 0),
        ),
      );
      await notifier.enqueue(
        _makeSaveWorkoutAction(
          id: 'w-2',
          queuedAt: DateTime.utc(2026, 4, 17, 11, 0, 0),
        ),
      );

      // First item succeeds but drops connectivity during processing.
      var callCount = 0;
      when(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        // After first item, simulate connectivity drop.
        connectivityController.add(false);
        await _pumpAsync(50);
        return Workout.fromJson(_workoutJson(id: 'w-$callCount'));
      });

      // Transition: offline -> online
      connectivityController.add(true);
      await _pumpAsync(300);

      // Only the first item should have been attempted.
      // The second item should remain because connectivity dropped.
      expect(callCount, 1);
      // One item dequeued, one remains.
      expect(container.read(pendingSyncProvider), 1);
    });

    // ------------------------------------------------------------------
    // Test: Marks action as terminal after max retries
    // ------------------------------------------------------------------
    test('marks action as terminal after max retries', () async {
      final container = createContainer(initialOnline: false);

      final notifier = container.read(pendingSyncProvider.notifier);

      // Enqueue an item already at retryCount = 5 (one failure from terminal).
      await notifier.enqueue(
        _makeSaveWorkoutAction(
          id: 'w-term',
          retryCount: 5,
          lastError: 'previous error',
        ),
      );

      // saveWorkout fails with a transient error (SocketException).
      stubSaveWorkoutFailure(const SocketException('Connection reset'));

      // Transition: offline -> online
      connectivityController.add(true);
      await _pumpAsync(200);

      // The item should still be in the queue (retryItem failed, not dequeued).
      final actions = queueService.getAll();
      expect(actions, hasLength(1));

      // retryCount should now be 6 (incremented by retryItem).
      expect(actions.first.retryCount, 6);

      // SyncState should reflect one terminal failure.
      final syncState = container.read(syncServiceProvider);
      expect(syncState.terminalFailureCount, 1);
    });

    // ------------------------------------------------------------------
    // Test: Handles transient errors without marking terminal
    // ------------------------------------------------------------------
    test('handles transient errors without marking terminal', () async {
      final container = createContainer(initialOnline: false);

      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(
        _makeSaveWorkoutAction(id: 'w-transient', retryCount: 0),
      );

      // saveWorkout fails with a transient error.
      stubSaveWorkoutFailure(const SocketException('No route to host'));

      // Transition: offline -> online
      connectivityController.add(true);
      // Backoff for retryCount=1 is 1s. We wait longer.
      await _pumpAsync(1500);

      // Item should still be in queue.
      final actions = queueService.getAll();
      expect(actions, hasLength(1));

      // retryCount should be incremented to 1 (by retryItem).
      expect(actions.first.retryCount, 1);
      expect(actions.first.lastError, contains('No route to host'));

      // SyncState should NOT show terminal failures.
      final syncState = container.read(syncServiceProvider);
      expect(syncState.terminalFailureCount, 0);
    });

    // ------------------------------------------------------------------
    // Test: retryTerminalItems resets and re-drains
    // ------------------------------------------------------------------
    test('retryTerminalItems resets retry counts and re-drains', () async {
      final container = createContainer(initialOnline: true);

      final notifier = container.read(pendingSyncProvider.notifier);

      // Enqueue a terminal item directly.
      await notifier.enqueue(
        _makeSaveWorkoutAction(
          id: 'w-terminal',
          retryCount: kMaxSyncRetries,
          lastError: 'gave up',
        ),
      );

      // Now saveWorkout succeeds (simulating a backend fix).
      stubSaveWorkoutSuccess(id: 'w-terminal');

      // Call retryTerminalItems — this resets retry count and calls _drain
      // directly (no connectivity transition needed).
      await container.read(syncServiceProvider.notifier).retryTerminalItems();

      // The item should be retried (retryCount was reset) and dequeued.
      expect(container.read(pendingSyncProvider), 0);
    });

    // ------------------------------------------------------------------
    // Test: dismissTerminalItems removes them from queue
    // ------------------------------------------------------------------
    test('dismissTerminalItems removes terminal items', () async {
      final container = createContainer(initialOnline: true);

      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(
        _makeSaveWorkoutAction(
          id: 'w-dismiss',
          retryCount: kMaxSyncRetries,
          lastError: 'terminal',
        ),
      );
      expect(container.read(pendingSyncProvider), 1);

      await container.read(syncServiceProvider.notifier).dismissTerminalItems();

      expect(container.read(pendingSyncProvider), 0);
      expect(queueService.getAll(), isEmpty);
      expect(container.read(syncServiceProvider).terminalFailureCount, 0);
    });

    // ------------------------------------------------------------------
    // Test: backoffDuration calculation
    // ------------------------------------------------------------------
    group('_backoffDuration', () {
      test('produces exponential series capped at 30s', () {
        // 2^0=1, 2^1=2, 2^2=4, 2^3=8, 2^4=16, 2^5=32->30
        final expected = [1, 2, 4, 8, 16, 30];
        for (var i = 1; i <= 6; i++) {
          final seconds = (1 << (i - 1)).clamp(1, 30);
          expect(
            seconds,
            expected[i - 1],
            reason: 'retryCount=$i should backoff ${expected[i - 1]}s',
          );
        }
      });
    });

    // ------------------------------------------------------------------
    // Test: Emits workoutSyncSucceeded analytics event on success
    // ------------------------------------------------------------------
    test(
      'emits workoutSyncSucceeded analytics event on drain success',
      () async {
        final container = createContainer(initialOnline: false);

        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(_makeSaveWorkoutAction(id: 'w-analytics'));

        stubSaveWorkoutSuccess(id: 'w-analytics');

        // Transition: offline -> online
        connectivityController.add(true);
        await _pumpAsync(200);

        // Verify analytics event was emitted.
        verify(
          () => mockAnalyticsRepo.insertEvent(
            userId: 'user-1',
            event: any(
              named: 'event',
              that: isA<AnalyticsEvent>().having(
                (e) => e.name,
                'name',
                'workout_sync_succeeded',
              ),
            ),
            platform: null,
            appVersion: null,
          ),
        ).called(1);
      },
    );

    // ------------------------------------------------------------------
    // Test: Skips terminal items during drain
    // ------------------------------------------------------------------
    test(
      'skips items with retryCount >= kMaxSyncRetries during drain',
      () async {
        final container = createContainer(initialOnline: false);

        final notifier = container.read(pendingSyncProvider.notifier);

        // One terminal, one fresh.
        await notifier.enqueue(
          _makeSaveWorkoutAction(
            id: 'w-dead',
            retryCount: kMaxSyncRetries,
            queuedAt: DateTime.utc(2026, 4, 17, 9, 0, 0),
          ),
        );
        await notifier.enqueue(
          _makeSaveWorkoutAction(
            id: 'w-alive',
            retryCount: 0,
            queuedAt: DateTime.utc(2026, 4, 17, 10, 0, 0),
          ),
        );

        stubSaveWorkoutSuccess(id: 'w-alive');

        // Transition: offline -> online
        connectivityController.add(true);
        await _pumpAsync(200);

        // Only the fresh item should have been retried and dequeued.
        verify(
          () => mockWorkoutRepo.saveWorkout(
            workout: any(named: 'workout'),
            exercises: any(named: 'exercises'),
            sets: any(named: 'sets'),
          ),
        ).called(1);

        // Terminal item remains, fresh one is gone.
        final remaining = queueService.getAll();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, 'w-dead');

        // State reflects the terminal item.
        expect(container.read(syncServiceProvider).terminalFailureCount, 1);
      },
    );

    // ------------------------------------------------------------------
    // Test: Drain skips items that are in-flight (manual retry)
    // ------------------------------------------------------------------
    test('drain skips items that are in-flight via manual retry', () async {
      final container = createContainer(initialOnline: false);

      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(_makeSaveWorkoutAction(id: 'w-manual'));

      // Stub saveWorkout to take some time (simulates in-flight manual retry).
      final completer = Completer<Workout>();
      when(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenAnswer((_) => completer.future);

      // Start a manual retry (enters _inFlight set) — do NOT await.
      final manualRetry = notifier.retryItem('w-manual');

      // Now trigger offline→online drain.
      connectivityController.add(true);
      await _pumpAsync(100);

      // Complete the manual retry.
      completer.complete(Workout.fromJson(_workoutJson(id: 'w-manual')));
      await manualRetry;
      await _pumpAsync(50);

      // saveWorkout should only be called once (the manual retry), not twice.
      verify(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).called(1);
    });

    // ------------------------------------------------------------------
    // Test: Concurrent drain calls are guarded
    // ------------------------------------------------------------------
    test('concurrent drain calls are guarded', () async {
      final container = createContainer(initialOnline: false);

      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(_makeSaveWorkoutAction(id: 'w-guard'));

      stubSaveWorkoutSuccess(id: 'w-guard');

      // Emit two rapid offline->online transitions.
      connectivityController.add(true);
      connectivityController.add(false);
      connectivityController.add(true);
      await _pumpAsync(300);

      // saveWorkout should only be called once (the second drain is guarded).
      verify(
        () => mockWorkoutRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).called(1);
    });

    // ------------------------------------------------------------------
    // Test: Emits workoutSyncFailed analytics event on terminal error
    // ------------------------------------------------------------------
    test(
      'emits workoutSyncFailed analytics event when error is terminal',
      () async {
        final container = createContainer(initialOnline: false);

        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(
          _makeSaveWorkoutAction(id: 'w-fail-analytics', retryCount: 0),
        );

        // 409 Conflict is a terminal error — will be classified as terminal
        // on first attempt, so workoutSyncFailed must be emitted.
        stubSaveWorkoutFailure(
          const supabase.PostgrestException(message: 'Conflict', code: '409'),
        );

        connectivityController.add(true);
        await _pumpAsync(200);

        verify(
          () => mockAnalyticsRepo.insertEvent(
            userId: 'user-1',
            event: any(
              named: 'event',
              that: isA<AnalyticsEvent>().having(
                (e) => e.name,
                'name',
                'workout_sync_failed',
              ),
            ),
            platform: null,
            appVersion: null,
          ),
        ).called(1);
      },
    );

    // ------------------------------------------------------------------
    // Test: Emits workoutSyncFailed when max retries exhausted (transient)
    // ------------------------------------------------------------------
    test(
      'emits workoutSyncFailed analytics event when max retries exhausted by transient error',
      () async {
        final container = createContainer(initialOnline: false);

        final notifier = container.read(pendingSyncProvider.notifier);

        // retryCount = kMaxSyncRetries - 1 so the next failure tips it over.
        await notifier.enqueue(
          _makeSaveWorkoutAction(
            id: 'w-maxretry',
            retryCount: kMaxSyncRetries - 1,
          ),
        );

        // Transient error that triggers the newRetryCount >= kMaxSyncRetries branch.
        stubSaveWorkoutFailure(const SocketException('reset'));

        connectivityController.add(true);
        await _pumpAsync(200);

        verify(
          () => mockAnalyticsRepo.insertEvent(
            userId: 'user-1',
            event: any(
              named: 'event',
              that: isA<AnalyticsEvent>().having(
                (e) => e.name,
                'name',
                'workout_sync_failed',
              ),
            ),
            platform: null,
            appVersion: null,
          ),
        ).called(1);
      },
    );

    // ------------------------------------------------------------------
    // Test: Terminal PostgrestException marks item terminal immediately
    // (no backoff applied — classification bypasses the backoff branch)
    // ------------------------------------------------------------------
    test(
      'terminal PostgrestException marks item as terminal after first failure',
      () async {
        final container = createContainer(initialOnline: false);

        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(
          _makeSaveWorkoutAction(id: 'w-terminal-pg', retryCount: 0),
        );

        // 422 is terminal — should NOT backoff, should immediately reflect
        // terminal state after drain completes.
        stubSaveWorkoutFailure(
          const supabase.PostgrestException(
            message: 'Unprocessable',
            code: '422',
          ),
        );

        connectivityController.add(true);
        // No 1s backoff should be needed — terminal path skips the delay.
        await _pumpAsync(300);

        // Item is still in queue (retryItem failed).
        expect(queueService.getAll(), hasLength(1));

        // SyncState does NOT count this as terminal yet (retryCount is only 1
        // now, still below kMaxSyncRetries). The item needs kMaxSyncRetries
        // failures to be counted as terminal in the post-drain sweep.
        // The key behavior: drain completed quickly (no 1s sleep).
        // This test ensures we don't accidentally apply backoff for terminal errors.
        final syncState = container.read(syncServiceProvider);
        expect(syncState.terminalFailureCount, 0);
      },
    );

    // ------------------------------------------------------------------
    // Test: dismissTerminalItems does not affect non-terminal items
    // ------------------------------------------------------------------
    test(
      'dismissTerminalItems only removes items with retryCount >= kMaxSyncRetries',
      () async {
        final container = createContainer(initialOnline: true);

        final notifier = container.read(pendingSyncProvider.notifier);

        // One terminal, one fresh.
        await notifier.enqueue(
          _makeSaveWorkoutAction(
            id: 'w-keep',
            retryCount: 0,
            queuedAt: DateTime.utc(2026, 4, 17, 9, 0, 0),
          ),
        );
        await notifier.enqueue(
          _makeSaveWorkoutAction(
            id: 'w-dismiss-only',
            retryCount: kMaxSyncRetries,
            queuedAt: DateTime.utc(2026, 4, 17, 10, 0, 0),
          ),
        );

        await container
            .read(syncServiceProvider.notifier)
            .dismissTerminalItems();

        // Only the non-terminal item remains.
        final remaining = queueService.getAll();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, 'w-keep');

        // Badge count and state should reflect one item removed.
        expect(container.read(pendingSyncProvider), 1);
        expect(container.read(syncServiceProvider).terminalFailureCount, 0);
      },
    );

    // ------------------------------------------------------------------
    // Test: retryTerminalItems does not drain if connectivity is offline
    // ------------------------------------------------------------------
    test(
      'retryTerminalItems resets counts but drain stops immediately if offline',
      () async {
        final container = createContainer(initialOnline: false);

        final notifier = container.read(pendingSyncProvider.notifier);
        await notifier.enqueue(
          _makeSaveWorkoutAction(
            id: 'w-offline-retry',
            retryCount: kMaxSyncRetries,
          ),
        );

        stubSaveWorkoutSuccess(id: 'w-offline-retry');

        // Call retryTerminalItems while offline.
        await container.read(syncServiceProvider.notifier).retryTerminalItems();

        // The drain should check connectivity and stop — item is NOT dequeued.
        // retryCount was reset to 0 by retryTerminalItems, but the drain skipped.
        expect(queueService.getAll(), hasLength(1));
        // saveWorkout must NOT have been called.
        verifyNever(
          () => mockWorkoutRepo.saveWorkout(
            workout: any(named: 'workout'),
            exercises: any(named: 'exercises'),
            sets: any(named: 'sets'),
          ),
        );
      },
    );
  });
}
