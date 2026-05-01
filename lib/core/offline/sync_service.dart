import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/analytics/data/models/analytics_event.dart';
import '../../features/analytics/providers/analytics_providers.dart';
import '../../features/personal_records/providers/pr_providers.dart';
import '../connectivity/connectivity_provider.dart';
import '../l10n/locale_provider.dart';
import '../observability/sentry_report.dart';
import 'offline_queue_service.dart';
import 'pending_action.dart';
import 'pending_sync_provider.dart';
import 'sync_error_classifier.dart';

/// Maximum number of retries before a queued action is considered terminal.
const kMaxSyncRetries = 6;

/// Watches connectivity and drains the offline queue FIFO when the device
/// transitions from offline to online.
///
/// The drain is transparent to the user. [PendingSyncNotifier]'s badge count
/// decrements as items are dequeued. Only terminal failures (items that
/// exhausted [kMaxSyncRetries]) are surfaced via [SyncState.terminalFailureCount].
class SyncService extends Notifier<SyncState> {
  /// Tracks the last-known online status to detect offline-to-online
  /// transitions. Defaults to `true` so the initial `true` emission from
  /// [onlineStatusProvider] does NOT trigger a drain.
  bool _lastOnline = true;

  /// Guards against concurrent drain invocations.
  bool _draining = false;

  @override
  SyncState build() {
    // Synchronize _lastOnline with the current connectivity state so that
    // the first listener callback can correctly detect a transition.
    _lastOnline = ref.read(isOnlineProvider);

    ref.listen<bool>(isOnlineProvider, (previous, next) {
      final wasOffline = !_lastOnline;
      _lastOnline = next;
      if (wasOffline && next) {
        _drain();
      }
    });
    return const SyncState();
  }

  /// Drain the offline queue in FIFO order.
  ///
  /// For each action:
  /// 1. Stop if connectivity drops mid-drain.
  /// 2. Skip if already being retried (in-flight guard).
  /// 3. Skip if retryCount >= [kMaxSyncRetries] (terminal).
  /// 4. Skip if any [PendingAction.dependsOn] parent is still in the queue
  ///    AND not terminal — the parent must commit first or the child's FK
  ///    will fail (BUG-002).
  /// 5. Delegate to [PendingSyncNotifier.retryItem].
  /// 6. On success: emit [AnalyticsEvent.workoutSyncSucceeded].
  /// 7. On failure: classify error, maybe backoff, maybe emit failed event.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;

    try {
      final notifier = ref.read(pendingSyncProvider.notifier);
      final queue = ref.read(offlineQueueServiceProvider);
      final actions = queue.getAll(); // FIFO (sorted by queuedAt)

      // Collect unique userIds from successfully drained upsertRecords items
      // so we can batch reconciliation after the loop.
      final reconciledUserIds = <String>{};

      // Snapshot the live (non-terminal) IDs for dependency gating.
      // This shrinks as actions drain successfully (`dequeue` removes them
      // from the queue, and we mirror that here on success). Terminal items
      // are NOT considered live — a perma-stuck parent shouldn't block its
      // children from at least attempting; the child will then fail and
      // surface its own error to the user.
      final liveIds = <String>{
        for (final a in actions)
          if (a.retryCount < kMaxSyncRetries) a.id,
      };

      for (final action in actions) {
        // Stop if connectivity dropped mid-drain.
        if (!ref.read(isOnlineProvider)) {
          log('Connectivity lost mid-drain, stopping', name: 'SyncService');
          break;
        }

        // Skip in-flight items (manual retry in progress).
        if (notifier.isInFlight(action.id)) continue;

        // Skip terminal items.
        if (action.retryCount >= kMaxSyncRetries) continue;

        // Skip when a dependency is still live (BUG-002). Don't increment
        // retryCount — this isn't a failure, just a "not yet". The child
        // becomes drainable in this same pass if the parent appeared
        // earlier in the FIFO slice (liveIds.remove(parentId) on success),
        // or on the next drain trigger if the parent was held this pass.
        if (action.dependsOn.any(liveIds.contains)) {
          SentryReport.addBreadcrumb(
            category: 'sync',
            message: 'Holding action ${action.id} for parent commit',
            data: {
              'action_type': _actionType(action),
              'depends_on': action.dependsOn.join(','),
            },
          );
          continue;
        }

        SentryReport.addBreadcrumb(
          category: 'sync',
          message: 'Draining action ${action.id}',
          data: {
            'action_type': _actionType(action),
            'retry_count': action.retryCount,
          },
        );

        try {
          await notifier.retryItem(action.id);

          // Success — parent committed; remove from the live set so any
          // dependent action later in the FIFO becomes drainable.
          liveIds.remove(action.id);

          // Success — emit analytics event.
          _trackSyncSucceeded(action);

          // Collect userId for batched post-drain PR cache reconciliation.
          if (action is PendingUpsertRecords && action.userId.isNotEmpty) {
            reconciledUserIds.add(action.userId);
          }
        } catch (e) {
          SentryReport.addBreadcrumb(
            category: 'sync',
            message: 'Drain failed for ${action.id}',
            data: {
              'error': e.runtimeType.toString(),
              'retry_count': action.retryCount + 1,
            },
          );

          final isTerminal = SyncErrorClassifier.isTerminal(e);
          final newRetryCount = action.retryCount + 1;

          if (isTerminal || newRetryCount >= kMaxSyncRetries) {
            _trackSyncFailed(action, e);
          } else {
            // Transient error — backoff before next item.
            await Future<void>.delayed(_backoffDuration(newRetryCount));
          }
        }
      }

      // Batch PR cache reconciliation — once per unique userId.
      for (final uid in reconciledUserIds) {
        await _reconcilePrCache(uid);
      }

      // Count terminal items and update state.
      final allAfter = queue.getAll();
      final terminalCount = allAfter
          .where((a) => a.retryCount >= kMaxSyncRetries)
          .length;
      state = SyncState(terminalFailureCount: terminalCount);
    } finally {
      _draining = false;
    }
  }

  /// Reset terminal items' retry counts and trigger a new drain.
  Future<void> retryTerminalItems() async {
    final queue = ref.read(offlineQueueServiceProvider);
    final actions = queue.getAll();
    for (final action in actions) {
      if (action.retryCount >= kMaxSyncRetries) {
        final reset = _resetRetryCount(action);
        await queue.updateAction(reset);
      }
    }
    ref.read(pendingSyncProvider.notifier).refreshCount();
    state = const SyncState();
    await _drain();
  }

  /// Remove terminal items from queue entirely.
  Future<void> dismissTerminalItems() async {
    final queue = ref.read(offlineQueueServiceProvider);
    final actions = queue.getAll();
    for (final action in actions) {
      if (action.retryCount >= kMaxSyncRetries) {
        await queue.dequeue(action.id);
      }
    }
    ref.read(pendingSyncProvider.notifier).refreshCount();
    state = const SyncState();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (capped).
  static Duration _backoffDuration(int retryCount) {
    final seconds = (1 << (retryCount - 1)).clamp(1, 30);
    return Duration(seconds: seconds);
  }

  /// Extract the Freezed union `type` discriminator for analytics.
  static String _actionType(PendingAction action) {
    return switch (action) {
      PendingSaveWorkout() => 'save_workout',
      PendingUpsertRecords() => 'upsert_records',
      PendingMarkRoutineComplete() => 'mark_routine_complete',
    };
  }

  /// Create a copy of [action] with retryCount reset to 0 and lastError
  /// cleared.
  static PendingAction _resetRetryCount(PendingAction action) {
    return switch (action) {
      PendingSaveWorkout() => action.copyWith(retryCount: 0, lastError: null),
      PendingUpsertRecords() => action.copyWith(retryCount: 0, lastError: null),
      PendingMarkRoutineComplete() => action.copyWith(
        retryCount: 0,
        lastError: null,
      ),
    };
  }

  void _trackSyncSucceeded(PendingAction action) {
    try {
      final analytics = ref.read(analyticsRepositoryProvider);
      final elapsed = DateTime.now().difference(action.queuedAt).inSeconds;
      unawaited(
        analytics.insertEvent(
          userId: _userId(action),
          event: AnalyticsEvent.workoutSyncSucceeded(
            actionType: _actionType(action),
            retryCount: action.retryCount,
            elapsedSecondsInQueue: elapsed,
          ),
          platform: null,
          appVersion: null,
        ),
      );
    } catch (_) {
      // Analytics must never break the sync loop.
    }
  }

  void _trackSyncFailed(PendingAction action, Object error) {
    try {
      final analytics = ref.read(analyticsRepositoryProvider);
      final elapsed = DateTime.now().difference(action.queuedAt).inSeconds;
      unawaited(
        analytics.insertEvent(
          userId: _userId(action),
          event: AnalyticsEvent.workoutSyncFailed(
            actionType: _actionType(action),
            retryCount: action.retryCount + 1,
            errorClass: error.runtimeType.toString(),
            elapsedSecondsInQueue: elapsed,
          ),
          platform: null,
          appVersion: null,
        ),
      );
    } catch (_) {
      // Analytics must never break the sync loop.
    }
  }

  /// Best-effort userId extraction for analytics. Falls back to 'unknown'.
  static String _userId(PendingAction action) {
    return switch (action) {
      PendingSaveWorkout(:final userId) => userId,
      PendingUpsertRecords(:final userId) => userId,
      PendingMarkRoutineComplete() => 'unknown',
    };
  }

  /// Refresh the PR cache from the server after a successful `upsertRecords`
  /// drain. The optimistic cache written during `finishWorkout()` uses a
  /// different key than the one read here, and `prRepo.upsertRecords()` clears
  /// the entire box before this runs, so a divergence comparison is meaningless.
  /// We simply refresh the cache from the server and log a breadcrumb.
  Future<void> _reconcilePrCache(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prRepo = ref.read(prRepositoryProvider);
      final locale = ref.read(localeProvider).languageCode;
      final serverRecords = await prRepo.getRecordsForUser(
        userId: userId,
        locale: locale,
      );
      SentryReport.addBreadcrumb(
        category: 'sync.reconcile',
        message: 'PR cache refreshed after upsertRecords drain',
        data: {'server_record_count': serverRecords.length},
      );
    } catch (e) {
      log(
        'PR cache reconciliation failed: $e',
        name: 'SyncService',
        level: 900,
      );
    }
  }
}

/// State emitted by [SyncService].
class SyncState {
  const SyncState({this.terminalFailureCount = 0});

  /// Number of queued items that have exhausted [kMaxSyncRetries].
  final int terminalFailureCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncState &&
          runtimeType == other.runtimeType &&
          terminalFailureCount == other.terminalFailureCount;

  @override
  int get hashCode => terminalFailureCount.hashCode;

  @override
  String toString() => 'SyncState(terminalFailureCount: $terminalFailureCount)';
}

/// Provides the [SyncService] as a Riverpod [Notifier].
final syncServiceProvider = NotifierProvider<SyncService, SyncState>(
  SyncService.new,
);
