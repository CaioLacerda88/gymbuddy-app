import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/routine.dart';
import '../providers/notifiers/routine_list_notifier.dart';
import 'start_routine_action.dart';
import 'widgets/routine_card.dart';

class RoutineListScreen extends ConsumerWidget {
  const RoutineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routinesAsync = ref.watch(routineListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/routines/create'),
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load routines',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(routineListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (routines) {
          final userRoutines = routines.where((r) => r.userId != null).toList();
          final defaultRoutines = routines.where((r) => r.isDefault).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My Routines
                const _SectionHeader(title: 'MY ROUTINES'),
                const SizedBox(height: 8),
                if (userRoutines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No custom routines yet. Tap + to create one.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                else
                  ...userRoutines.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineCard(
                        routine: r,
                        onTap: () => startRoutineWorkout(context, ref, r),
                        onLongPress: () => _showRoutineActions(context, ref, r),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Starter Routines
                if (defaultRoutines.isNotEmpty) ...[
                  const _SectionHeader(title: 'STARTER ROUTINES'),
                  const SizedBox(height: 8),
                  ...defaultRoutines.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineCard(
                        routine: r,
                        onTap: () => startRoutineWorkout(context, ref, r),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRoutineActions(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final action = await showModalBottomSheet<_RoutineAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, _RoutineAction.edit),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, _RoutineAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == _RoutineAction.edit) {
      context.go('/routines/create', extra: routine);
    } else if (action == _RoutineAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Routine'),
          content: Text('Delete "${routine.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(routineListProvider.notifier).deleteRoutine(routine.id);
      }
    }
  }
}

enum _RoutineAction { edit, delete }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
