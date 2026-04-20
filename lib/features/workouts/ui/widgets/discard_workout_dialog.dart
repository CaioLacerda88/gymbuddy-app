import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Confirmation dialog shown when the user wants to discard an active workout.
///
/// Returns `true` if the user confirmed the discard, `false` or `null` otherwise.
class DiscardWorkoutDialog extends StatelessWidget {
  const DiscardWorkoutDialog({required this.elapsedDuration, super.key});

  final Duration elapsedDuration;

  static Future<bool?> show(
    BuildContext context, {
    required Duration elapsedDuration,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DiscardWorkoutDialog(elapsedDuration: elapsedDuration),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.discardWorkoutTitle),
      content: Text(
        l10n.discardWorkoutContent(_formatDuration(elapsedDuration)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        Semantics(
          container: true,
          identifier: 'workout-discard-confirm',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.discard),
          ),
        ),
      ],
    );
  }
}
