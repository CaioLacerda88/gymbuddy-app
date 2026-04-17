import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local_storage/hive_service.dart';
import 'pending_action.dart';

/// Reads and writes [PendingAction] items to the `offline_queue` Hive box.
///
/// Each action is stored as a JSON string keyed by its `id`. The box is
/// opened during [HiveService.init], so callers must ensure init has
/// completed before accessing this service.
class OfflineQueueService {
  const OfflineQueueService();

  Box<dynamic> get _box => Hive.box<dynamic>(HiveService.offlineQueue);

  /// Persist a [PendingAction] to the queue.
  Future<void> enqueue(PendingAction action) async {
    try {
      final json = jsonEncode(action.toJson());
      await _box.put(action.id, json);
    } catch (e) {
      log(
        'Failed to enqueue action ${action.id}: $e',
        name: 'OfflineQueueService',
        level: 900,
      );
    }
  }

  /// Remove a queued action by [id].
  Future<void> dequeue(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      log(
        'Failed to dequeue action $id: $e',
        name: 'OfflineQueueService',
        level: 900,
      );
    }
  }

  /// Read all queued actions, sorted by [PendingAction.queuedAt] ascending.
  ///
  /// Corrupt entries are silently skipped so one bad row cannot block the
  /// entire queue.
  List<PendingAction> getAll() {
    final actions = <PendingAction>[];
    for (final key in _box.keys) {
      try {
        final raw = _box.get(key);
        if (raw is! String) continue;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        actions.add(PendingAction.fromJson(decoded));
      } catch (e) {
        log(
          'Skipping corrupt queue entry "$key": $e',
          name: 'OfflineQueueService',
          level: 900,
        );
      }
    }
    actions.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return actions;
  }

  /// Overwrite an existing entry (e.g. to update retryCount / lastError).
  Future<void> updateAction(PendingAction action) async {
    try {
      final json = jsonEncode(action.toJson());
      await _box.put(action.id, json);
    } catch (e) {
      log(
        'Failed to update action ${action.id}: $e',
        name: 'OfflineQueueService',
        level: 900,
      );
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
