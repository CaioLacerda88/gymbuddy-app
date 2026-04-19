import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/workout_history_providers.dart';

/// Editorial one-liner showing the user's most recent completed session.
///
/// Replaces the old two-cell stat grid. No card chrome — a single tappable
/// line that navigates to the full workout history.
///
/// Format: `"Last: {routineName}, {relativeDate}"` (e.g. `"Last: Push Day,
/// Yesterday"`).
///
/// Hidden (renders `SizedBox.shrink()`) when the user has no history yet.
class LastSessionLine extends ConsumerWidget {
  const LastSessionLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final last = ref.watch(lastSessionProvider);
    if (last == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      identifier: 'home-last-session',
      button: true,
      label: 'Last session: ${last.name}, ${last.relativeDate}',
      child: InkWell(
        onTap: () => context.push('/home/history'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Last: ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                TextSpan(
                  text: last.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ', ${last.relativeDate}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
