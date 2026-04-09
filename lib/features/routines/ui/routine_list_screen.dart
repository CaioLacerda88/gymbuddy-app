import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import 'widgets/routine_action_sheet.dart';
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
            tooltip: 'Create routine',
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
                const SectionHeader(title: 'MY ROUTINES'),
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
                        onLongPress: () =>
                            showRoutineActionSheet(context, ref, r),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Starter Routines
                if (defaultRoutines.isNotEmpty) ...[
                  const SectionHeader(title: 'STARTER ROUTINES'),
                  const SizedBox(height: 8),
                  ...defaultRoutines.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineCard(
                        routine: r,
                        onTap: () => startRoutineWorkout(context, ref, r),
                        onLongPress: () =>
                            showRoutineActionSheet(context, ref, r),
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
}
