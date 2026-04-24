import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/enum_l10n.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final exercises = ref.watch(filteredExerciseListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Semantics(
                container: true,
                identifier: 'exercise-list-heading',
                child: Text(
                  l10n.exercises,
                  style: theme.textTheme.headlineLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _MuscleGroupSelector(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 12),
            const _EquipmentFilter(),
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
                  return _ExerciseList(
                    exercises: list,
                    onRefresh: () async {
                      // Invalidate the underlying family, not just the thin
                      // wrapper, so all cached filter combinations are cleared
                      // and a fresh Supabase query is issued (F2 fix).
                      ref.invalidate(exerciseListProvider);
                    },
                  );
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

/// Self-contained filter selector that watches its own state provider (F3 fix).
///
/// Previously the parent build() passed `ref.watch(selectedMuscleGroupProvider)`
/// as a constructor arg, causing the entire ExerciseListScreen to rebuild on
/// every muscle-group tap. Now only this widget rebuilds.
class _MuscleGroupSelector extends ConsumerWidget {
  const _MuscleGroupSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMuscleGroupProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 72,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _MuscleGroupButton(
              label: l10n.all,
              // "All" is a UI meta-filter with no matching pixel asset; a
              // Material icon is the correct affordance here.
              icon: const Icon(Icons.grid_view_rounded, size: 24, weight: 600),
              isSelected: selected == null,
              onTap: () {
                ref.read(selectedMuscleGroupProvider.notifier).state = null;
              },
              theme: theme,
            ),
            ...MuscleGroup.values.map(
              (group) => _MuscleGroupButton(
                label: group.localizedName(l10n),
                icon: Icon(group.icon, size: 24),
                isSelected: selected == group,
                onTap: () {
                  ref.read(selectedMuscleGroupProvider.notifier).state = group;
                },
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

  /// Pre-sized 24dp icon widget. Always a Material [Icon] — the "All"
  /// meta-filter uses `Icons.grid_view_rounded`; real muscle groups use
  /// their `MuscleGroup.icon`.
  final Widget icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        container: true,
        identifier:
            'exercise-filter-${label.toLowerCase().replaceAll(' ', '-')}',
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
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconTheme(
                      data: IconThemeData(
                        color: isSelected
                            ? primary
                            : theme.colorScheme.onSurface,
                        size: 24,
                      ),
                      child: icon,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // Inter-Medium (w500) isn't bundled; google_fonts would
                      // nearest-match to w400/w600 with runtime fetching off.
                      // Use w600 (bundled SemiBold) to render deterministically.
                      fontWeight: FontWeight.w600,
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
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      identifier: 'exercise-list-search',
      label: l10n.searchExercisesSemantics,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n.searchExercises,
          prefixIcon: const Icon(Icons.search_rounded, weight: 600),
        ),
      ),
    );
  }
}

/// Self-contained equipment filter that watches its own state provider (F3 fix).
///
/// Same rationale as [_MuscleGroupSelector] — isolates rebuilds so the parent
/// ExerciseListScreen does not rebuild when equipment type changes.
class _EquipmentFilter extends ConsumerWidget {
  const _EquipmentFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEquipmentTypeProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: EquipmentType.values.map((type) {
            final isSelected = selected == type;
            final l10n = AppLocalizations.of(context);
            final typeName = type.localizedName(l10n);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                container: true,
                identifier: 'exercise-equip-${type.name}',
                label: '$typeName equipment filter',
                selected: isSelected,
                child: FilterChip(
                  avatar: Icon(type.icon, size: 18),
                  label: Text(typeName),
                  selected: isSelected,
                  onSelected: (val) {
                    ref.read(selectedEquipmentTypeProvider.notifier).state = val
                        ? type
                        : null;
                  },
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
  const _ExerciseList({required this.exercises, required this.onRefresh});

  final List<Exercise> exercises;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: exercises.length,
        itemBuilder: (context, index) =>
            _ExerciseCard(exercise: exercises[index]),
      ),
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

    // P9: a 3dp left-border accent in primary flags user-created exercises
    // in the browse list so they are instantly distinguishable from the 150
    // default rows. Default cards keep the existing hairline top-border only.
    final isCustom = !exercise.isDefault;

    return Semantics(
      label: AppLocalizations.of(context).exerciseItemSemantics(exercise.name),
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/exercises/${exercise.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // P9: no borderRadius here — Flutter requires uniform Border
                // colors when borderRadius is set, but we need the top hairline
                // and the primary left accent to differ. The outer Material's
                // borderRadius + clipBehavior round the visible corners.
                border: Border(
                  top: BorderSide(color: primary.withValues(alpha: 0.15)),
                  left: isCustom
                      ? BorderSide(color: primary, width: 3)
                      : BorderSide.none,
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
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Wrap(
                              spacing: 8,
                              children: [
                                _InfoChip(
                                  label: exercise.muscleGroup.localizedName(
                                    l10n,
                                  ),
                                  icon: exercise.muscleGroup.icon,
                                ),
                                _InfoChip(
                                  label: exercise.equipmentType.localizedName(
                                    l10n,
                                  ),
                                  icon: exercise.equipmentType.icon,
                                ),
                              ],
                            );
                          },
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
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.fitness_center_rounded,
              size: 64,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 16),
            Semantics(
              container: true,
              identifier: hasFilters
                  ? 'exercise-list-empty-filtered'
                  : 'exercise-list-empty-no-filter',
              child: Text(
                hasFilters
                    ? l10n.noExercisesMatchFilters
                    : l10n.yourExercisesWillAppear,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (hasFilters)
              Semantics(
                container: true,
                identifier: 'exercise-list-clear-filters',
                child: TextButton(
                  onPressed: onClearFilters,
                  child: Text(
                    l10n.clearFilters,
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: onCreateExercise,
                child: Text(
                  l10n.createExercise,
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
      container: true,
      identifier: 'exercise-list-create-fab',
      label: AppLocalizations.of(context).createNewExerciseSemantics,
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
