import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../exercises/models/exercise.dart';
import '../../../exercises/providers/exercise_providers.dart';

/// Shows the exercise picker as a modal bottom sheet.
///
/// Returns the selected [Exercise], or `null` if dismissed.
class ExercisePickerSheet {
  ExercisePickerSheet._();

  static Future<Exercise?> show(BuildContext context) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) =>
            _SheetBody(scrollController: scrollController),
      ),
    );
  }
}

class _SheetBody extends ConsumerStatefulWidget {
  const _SheetBody({this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends ConsumerState<_SheetBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  MuscleGroup? _selectedMuscle;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  ExerciseFilter get _filter =>
      ExerciseFilter(searchQuery: _query, muscleGroup: _selectedMuscle);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = ref.watch(exerciseListProvider(_filter));

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Add Exercise', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              label: 'Search exercises to add',
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Muscle group filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChipItem(
                  label: 'All',
                  isSelected: _selectedMuscle == null,
                  onSelected: () => setState(() => _selectedMuscle = null),
                ),
                ...MuscleGroup.values.map(
                  (group) => _FilterChipItem(
                    label: group.displayName,
                    isSelected: _selectedMuscle == group,
                    onSelected: () => setState(() => _selectedMuscle = group),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Exercise list
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => SingleChildScrollView(
                controller: widget.scrollController,
                child: Center(
                  child: Text(
                    'Failed to load exercises',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SingleChildScrollView(
                    controller: widget.scrollController,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No exercises found',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.push('/exercises/create');
                              },
                              icon: const Icon(Icons.add),
                              label: Text(
                                _query.isNotEmpty
                                    ? 'Create "$_query"'
                                    : 'Create Exercise',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _ExercisePickerTile(
                    exercise: list[index],
                    onTap: () => Navigator.of(context).pop(list[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        checkmarkColor: theme.colorScheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ExercisePickerTile extends StatelessWidget {
  const _ExercisePickerTile({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Add ${exercise.name}',
      button: true,
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        title: Text(exercise.name, style: theme.textTheme.titleMedium),
        subtitle: Row(
          children: [
            _Badge(label: exercise.muscleGroup.displayName),
            const SizedBox(width: 8),
            _Badge(label: exercise.equipmentType.displayName),
          ],
        ),
        trailing: Icon(
          Icons.add_circle_outline,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
      ),
    );
  }
}
