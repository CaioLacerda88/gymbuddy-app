import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local_storage/hive_service.dart';
import '../observability/sentry_report.dart';
import 'pending_action.dart';

/// Reads and writes [PendingAction] items to the `offline_queue` Hive box.
///
/// Each action is stored as a JSON string keyed by its `id`. The box is
/// opened during [HiveService.init], so callers must ensure init has
/// completed before accessing this service.
///
/// **BUG-007 contract:** `enqueue`, `dequeue`, and `updateAction` rethrow
/// on Hive failures so callers can surface the issue (without rethrow, a
/// failed enqueue silently loses user data; a failed dequeue causes
/// duplicate replays; a failed updateAction makes retry counters
/// non-monotonic). All catch sites capture to Sentry so production failure
/// rates are visible. `getAll` keeps its skip-corrupt behavior — one bad
/// row must not block the entire queue — but also captures so we see
/// corruption rates.
class OfflineQueueService {
  const OfflineQueueService();

  Box<dynamic> get _box => Hive.box<dynamic>(HiveService.offlineQueue);

  /// Persist a [PendingAction] to the queue.
  ///
  /// Rethrows on Hive failure so callers (typically a notifier in a
  /// `try/catch`) can react. The caller is expected to surface the failure
  /// to the user — losing a queued action silently is the worst outcome.
  Future<void> enqueue(PendingAction action) async {
    try {
      final json = jsonEncode(action.toJson());
      await _box.put(action.id, json);
    } catch (e, st) {
      log(
        'Failed to enqueue action ${action.id}: $e',
        name: 'OfflineQueueService',
        level: 900,
      );
      unawaited(SentryReport.captureException(e, stackTrace: st));
      rethrow;
    }
  }

  /// Remove a queued action by [id].
  ///
  /// Rethrows on Hive failure so callers can avoid double-dequeue or
  /// duplicate replay scenarios.
  Future<void> dequeue(String id) async {
    try {
      await _box.delete(id);
    } catch (e, st) {
      log(
        'Failed to dequeue action $id: $e',
        name: 'OfflineQueueService',
        level: 900,
      );
      unawaited(SentryReport.captureException(e, stackTrace: st));
      rethrow;
    }
  }

  /// Read all queued actions, sorted by [PendingAction.queuedAt] ascending.
  ///
  /// Corrupt entries are silently skipped so one bad row cannot block the
  /// entire queue (a single malformed JSON would otherwise stall every
  /// drain). Each skip captures to Sentry so we get production rates on
  /// corruption — historically this masked BUG-001 because the corrupt
  /// entry would loop forever without anyone noticing.
  List<PendingAction> getAll() {
    final actions = <PendingAction>[];
    for (final key in _box.keys) {
      try {
        final raw = _box.get(key);
        if (raw is! String) continue;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        actions.add(PendingAction.fromJson(decoded));
      } catch (e, st) {
        log(
          'Skipping corrupt queue entry "$key": $e',
          name: 'OfflineQueueService',
          level: 900,
        );
        unawaited(SentryReport.captureException(e, stackTrace: st));
      }
    }
    actions.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return actions;
  }

  /// Overwrite an existing entry (e.g. to update retryCount / lastError).
  ///
  /// Rethrows on Hive failure so a non-monotonic retry counter (caused by
  /// a silently-swallowed update) doesn't make queued items retry forever
  /// past [SyncService.kMaxSyncRetries].
  Future<void> updateAction(PendingAction action) async {
    try {
      final json = jsonEncode(action.toJson());
      await _box.put(action.id, json);
    } catch (e, st) {
      log(
        'Failed to update action ${action.id}: $e',
        name: 'OfflineQueueService',
        level: 900,
      );
      unawaited(SentryReport.captureException(e, stackTrace: st));
      rethrow;
    }
  }

  /// Number of items currently in the queue.
  ///
  /// Assumes the box is used exclusively for [PendingAction] JSON strings.
  int get pendingCount => _box.length;
}

/// Provides an [OfflineQueueService] instance via Riverpod.
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return const OfflineQueueService();
});
