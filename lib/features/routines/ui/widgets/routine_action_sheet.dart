import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../models/routine.dart';
import '../../providers/notifiers/routine_list_notifier.dart';
import '../start_routine_action.dart';

/// Result of the routine action sheet.
enum RoutineAction { start, duplicate, edit, delete }

/// Shows a bottom sheet with context-appropriate actions for a [Routine].
///
/// Default (preset) routines show: Start, Duplicate and Edit.
/// User-created routines show: Edit, Delete.
Future<void> showRoutineActionSheet(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  final isDefault = routine.isDefault;

  final action = await showModalBottomSheet<RoutineAction>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDefault) ...[
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(l10n.start),
                onTap: () => Navigator.pop(context, RoutineAction.start),
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.duplicateAndEdit),
                onTap: () => Navigator.pop(context, RoutineAction.duplicate),
              ),
            ] else ...[
              Semantics(
                container: true,
                identifier: 'routine-edit-option',
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.edit),
                  onTap: () => Navigator.pop(context, RoutineAction.edit),
                ),
              ),
              Semantics(
                container: true,
                identifier: 'routine-delete-option',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.delete,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, RoutineAction.delete),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  if (!context.mounted || action == null) return;

  switch (action) {
    case RoutineAction.start:
      await startRoutineWorkout(context, ref, routine);

    case RoutineAction.duplicate:
      final copy = await ref
          .read(routineListProvider.notifier)
          .duplicateRoutine(routine);
      if (!context.mounted || copy == null) return;
      context.go('/routines/create', extra: copy);

    case RoutineAction.edit:
      context.go('/routines/create', extra: routine);

    case RoutineAction.delete:
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Semantics(
              container: true,
              identifier: 'routine-delete-dialog-title',
              child: Text(l10n.deleteRoutine),
            ),
            content: Text(l10n.deleteRoutineConfirm(routine.name)),
            actions: [
              Semantics(
                container: true,
                identifier: 'routine-cancel-btn',
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
              ),
              Semantics(
                container: true,
                identifier: 'routine-delete-confirm',
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.delete),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed == true) {
        await ref.read(routineListProvider.notifier).deleteRoutine(routine.id);
      }
  }
}
