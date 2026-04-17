import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/pending_action.dart';
import '../../core/offline/pending_sync_provider.dart';
import '../../core/theme/radii.dart';

/// Modal bottom sheet listing all pending offline actions with retry controls.
///
/// Each row shows the action type, timestamp, and a "Retry" button.
/// Successful retries remove the row; failures show the error inline.
class PendingSyncSheet extends ConsumerStatefulWidget {
  const PendingSyncSheet({super.key});

  @override
  ConsumerState<PendingSyncSheet> createState() => _PendingSyncSheetState();
}

class _PendingSyncSheetState extends ConsumerState<PendingSyncSheet> {
  /// Per-item loading states keyed by action ID.
  final _retrying = <String>{};

  /// Per-item error messages keyed by action ID.
  final _errors = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch the count so the sheet rebuilds when items are dequeued.
    final count = ref.watch(pendingSyncProvider);
    final actions = count > 0
        ? ref.read(pendingSyncProvider.notifier).getAll()
        : const <PendingAction>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Pending Sync',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${actions.length} item${actions.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: actions.isEmpty
                ? Center(
                    child: Text(
                      'All synced!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: actions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) => _ActionRow(
                      action: actions[index],
                      isRetrying: _retrying.contains(actions[index].id),
                      error: _errors[actions[index].id],
                      onRetry: () => _retry(actions[index].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(String id) async {
    setState(() {
      _retrying.add(id);
      _errors.remove(id);
    });

    try {
      await ref.read(pendingSyncProvider.notifier).retryItem(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Synced successfully.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[id] = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _retrying.remove(id);
        });
      }
    }
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.isRetrying,
    required this.error,
    required this.onRetry,
  });

  final PendingAction action;
  final bool isRetrying;
  final String? error;
  final VoidCallback onRetry;

  IconData get _icon => switch (action) {
    PendingSaveWorkout() => Icons.fitness_center,
    PendingUpsertRecords() => Icons.emoji_events,
    PendingMarkRoutineComplete() => Icons.check_circle_outline,
  };

  String get _label => switch (action) {
    PendingSaveWorkout() => 'Save workout',
    PendingUpsertRecords() => 'Update records',
    PendingMarkRoutineComplete() => 'Mark routine complete',
  };

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Queued at ${_formatTime(action.queuedAt)}'
                      '${action.retryCount > 0 ? ' \u00b7 ${action.retryCount} retries' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isRetrying)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.tonal(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Retry'),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
