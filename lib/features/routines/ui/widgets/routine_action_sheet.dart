import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/routine.dart';
import '../../providers/notifiers/routine_list_notifier.dart';

/// Result of the routine action sheet.
enum RoutineAction { edit, delete }

/// Shows a bottom sheet with edit/delete options for a [Routine].
///
/// Handles the full action flow: action selection, delete confirmation,
/// and navigation for edit. Returns the chosen [RoutineAction] or null
/// if dismissed.
Future<void> showRoutineActionSheet(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  final action = await showModalBottomSheet<RoutineAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () => Navigator.pop(context, RoutineAction.edit),
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
            onTap: () => Navigator.pop(context, RoutineAction.delete),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted) return;

  if (action == RoutineAction.edit) {
    context.go('/routines/create', extra: routine);
  } else if (action == RoutineAction.delete) {
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
