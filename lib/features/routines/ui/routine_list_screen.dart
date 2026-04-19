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
        title: Semantics(
          container: true,
          identifier: 'routine-heading',
          child: const Text('Routines'),
        ),
        actions: [
          Semantics(
            container: true,
            identifier: 'routine-mgmt-create-btn',
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create routine',
              onPressed: () => context.go('/routines/create'),
            ),
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

          return CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.only(left: 16, right: 16, top: 16),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'MY ROUTINES',
                    semanticsIdentifier: 'routine-my-section',
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (userRoutines.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8,
                    ),
                    child: Text(
                      'No custom routines yet. Tap + to create one.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: userRoutines.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineCard(
                        routine: userRoutines[index],
                        onTap: () => startRoutineWorkout(
                          context,
                          ref,
                          userRoutines[index],
                        ),
                        onLongPress: () => showRoutineActionSheet(
                          context,
                          ref,
                          userRoutines[index],
                        ),
                      ),
                    ),
                  ),
                ),

              if (defaultRoutines.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'STARTER ROUTINES',
                      semanticsIdentifier: 'routine-starter-section',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: defaultRoutines.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineCard(
                        routine: defaultRoutines[index],
                        onTap: () => startRoutineWorkout(
                          context,
                          ref,
                          defaultRoutines[index],
                        ),
                        onLongPress: () => showRoutineActionSheet(
                          context,
                          ref,
                          defaultRoutines[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Bottom padding for safe area / FAB clearance.
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }
}
