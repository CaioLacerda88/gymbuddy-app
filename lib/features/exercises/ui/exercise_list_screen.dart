import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_value_builder.dart';
import '../models/exercise.dart';
import '../providers/exercise_providers.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _clearFilters() {
    ref.read(selectedMuscleGroupProvider.notifier).state = null;
    ref.read(selectedEquipmentTypeProvider.notifier).state = null;
    ref.read(searchQueryProvider.notifier).state = '';
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = ref.watch(filteredExerciseListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Exercises', style: theme.textTheme.headlineLarge),
            ),
            const SizedBox(height: 16),
            _MuscleGroupSelector(
              selected: ref.watch(selectedMuscleGroupProvider),
              onSelected: (group) {
                ref.read(selectedMuscleGroupProvider.notifier).state = group;
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 12),
            _EquipmentFilter(
              selected: ref.watch(selectedEquipmentTypeProvider),
              onSelected: (type) {
                ref.read(selectedEquipmentTypeProvider.notifier).state = type;
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncValueBuilder<List<Exercise>>(
                value: exercises,
                data: (list) {
                  if (list.isEmpty) {
                    final hasFilters =
                        ref.read(selectedMuscleGroupProvider) != null ||
                        ref.read(selectedEquipmentTypeProvider) != null ||
                        ref.read(searchQueryProvider).isNotEmpty;
                    return _EmptyState(
                      hasFilters: hasFilters,
                      onClearFilters: _clearFilters,
                      onCreateExercise: () => context.go('/exercises/create'),
                    );
                  }
                  return _ExerciseList(exercises: list);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _CreateExerciseFab(
        onPressed: () => context.go('/exercises/create'),
      ),
    );
  }
}

class _MuscleGroupSelector extends StatelessWidget {
  const _MuscleGroupSelector({
    required this.selected,
    required this.onSelected,
  });

  final MuscleGroup? selected;
  final ValueChanged<MuscleGroup?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 72,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _MuscleGroupButton(
              label: 'All',
              icon: Icons.grid_view_rounded,
              isSelected: selected == null,
              onTap: () => onSelected(null),
              theme: theme,
            ),
            ...MuscleGroup.values.map(
              (group) => _MuscleGroupButton(
                label: group.displayName,
                icon: group.icon,
                isSelected: selected == group,
                onTap: () => onSelected(group),
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleGroupButton extends StatelessWidget {
  const _MuscleGroupButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        label: '$label muscle group filter',
        selected: isSelected,
        child: Material(
          color: isSelected
              ? primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64, minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? primary : theme.colorScheme.onSurface,
                    size: 24,
                    weight: 600,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? primary : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search exercises',
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Search exercises...',
          prefixIcon: Icon(Icons.search_rounded, weight: 600),
        ),
      ),
    );
  }
}

class _EquipmentFilter extends StatelessWidget {
  const _EquipmentFilter({required this.selected, required this.onSelected});

  final EquipmentType? selected;
  final ValueChanged<EquipmentType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: EquipmentType.values.map((type) {
            final isSelected = selected == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: '${type.displayName} equipment filter',
                selected: isSelected,
                child: FilterChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: (val) => onSelected(val ? type : null),
                  selectedColor: theme.colorScheme.primary.withValues(
                    alpha: 0.15,
                  ),
                  checkmarkColor: theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: exercises.length,
      itemBuilder: (context, index) =>
          _ExerciseCard(exercise: exercises[index]),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      label: 'Exercise: ${exercise.name}',
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.go('/exercises/${exercise.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  top: BorderSide(color: primary.withValues(alpha: 0.15)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _InfoChip(
                              label: exercise.muscleGroup.displayName,
                              icon: exercise.muscleGroup.icon,
                            ),
                            _InfoChip(
                              label: exercise.equipmentType.displayName,
                              icon: exercise.equipmentType.icon,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    weight: 600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurface),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.onClearFilters,
    required this.onCreateExercise,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onCreateExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.fitness_center,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No exercises match your filters'
                  : 'Your exercises will appear here',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (hasFilters)
              TextButton(
                onPressed: onClearFilters,
                child: Text(
                  'Clear Filters',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              )
            else
              TextButton(
                onPressed: onCreateExercise,
                child: Text(
                  'Create Exercise',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateExerciseFab extends StatelessWidget {
  const _CreateExerciseFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Create new exercise',
      button: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.add_rounded, weight: 600),
        ),
      ),
    );
  }
}
