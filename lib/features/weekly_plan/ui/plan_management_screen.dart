import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/radii.dart';
import '../../profile/providers/profile_providers.dart';
import '../../routines/models/routine.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../data/models/weekly_plan.dart';
import '../providers/weekly_plan_provider.dart';
import 'add_routines_sheet.dart';

/// Plan management screen at `/plan/week`.
///
/// Allows users to:
/// - View and reorder routines in this week's bucket
/// - Add/remove routines
/// - Clear the week
/// - Auto-fill from most-used routines
class PlanManagementScreen extends ConsumerStatefulWidget {
  const PlanManagementScreen({super.key});

  @override
  ConsumerState<PlanManagementScreen> createState() =>
      _PlanManagementScreenState();
}

class _PlanManagementScreenState extends ConsumerState<PlanManagementScreen> {
  List<BucketRoutine> _bucketRoutines = [];

  /// Tracks whether the user has made local edits (reorder, add, remove).
  /// When true, we no longer sync from the provider to avoid clobbering.
  bool _dirty = false;

  /// Whether we've received the initial provider data at least once.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    // Listen for the async plan value to resolve (especially on slow
    // connections where the first build fires before data arrives).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(weeklyPlanProvider, (previous, next) {
        // Only seed from provider if user hasn't started editing.
        if (_dirty) return;
        final plan = next.valueOrNull;
        if (plan != null && !_seeded) {
          setState(() {
            _bucketRoutines = [...plan.routines];
            _seeded = true;
          });
        } else if (!_seeded && plan == null && !next.isLoading) {
          // Provider resolved to null (no plan) — mark as seeded.
          _seeded = true;
        }
      }, fireImmediately: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch these providers so the widget rebuilds when data changes.
    ref.watch(weeklyPlanProvider);
    final routinesAsync = ref.watch(routineListProvider);
    final profile = ref.watch(profileProvider);

    final allRoutines = routinesAsync.valueOrNull ?? [];
    final routineMap = <String, Routine>{for (final r in allRoutines) r.id: r};
    final trainingFrequency =
        profile.valueOrNull?.trainingFrequencyPerWeek ?? 3;

    final atSoftCap = _bucketRoutines.length >= trainingFrequency;

    return Scaffold(
      appBar: AppBar(
        title: const Text("This Week's Plan"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _confirmClear(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear Week')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _bucketRoutines.isEmpty
                ? _EmptyState(onAddRoutines: () => _showAddSheet(allRoutines))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _bucketRoutines.length + 1,
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      if (index == _bucketRoutines.length) {
                        // Add routine row.
                        return _AddRoutineRow(
                          key: const ValueKey('add-routine'),
                          atSoftCap: atSoftCap,
                          onTap: () => _showAddSheet(allRoutines),
                        );
                      }

                      final bucket = _bucketRoutines[index];
                      final routine = routineMap[bucket.routineId];
                      final isDone = bucket.completedWorkoutId != null;
                      final name = routine?.name ?? 'Unknown Routine';
                      final exerciseCount = routine?.exercises.length ?? 0;

                      return _RoutineRow(
                        key: ValueKey(bucket.routineId),
                        index: index,
                        routineId: bucket.routineId,
                        sequenceNumber: bucket.order,
                        name: name,
                        exerciseCount: exerciseCount,
                        isDone: isDone,
                        onDismissed: isDone
                            ? null
                            : () => _removeRoutine(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    // Don't reorder beyond the actual bucket items (skip the add row).
    if (oldIndex >= _bucketRoutines.length ||
        newIndex > _bucketRoutines.length) {
      return;
    }

    setState(() {
      _dirty = true;
      if (newIndex > oldIndex) newIndex--;
      final item = _bucketRoutines.removeAt(oldIndex);
      _bucketRoutines.insert(newIndex, item);
      _renumber();
    });
    _savePlan();
  }

  void _renumber() {
    _bucketRoutines = _bucketRoutines.indexed
        .map((entry) => entry.$2.copyWith(order: entry.$1 + 1))
        .toList();
  }

  void _removeRoutine(int index) {
    final removed = _bucketRoutines[index];
    setState(() {
      _dirty = true;
      _bucketRoutines.removeAt(index);
      _renumber();
    });
    _savePlan();

    // Undo snackbar.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Routine removed'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              setState(() {
                _bucketRoutines.insert(index, removed);
                _renumber();
              });
              _savePlan();
            },
          ),
        ),
      );
    }
  }

  Future<void> _showAddSheet(List<Routine> allRoutines) async {
    final existingIds = _bucketRoutines.map((b) => b.routineId).toSet();
    final available = allRoutines
        .where((r) => !existingIds.contains(r.id))
        .toList();

    final selected = await showModalBottomSheet<List<Routine>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddRoutinesSheet(
        availableRoutines: available,
        inPlanIds: existingIds,
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _dirty = true;
        for (final routine in selected) {
          _bucketRoutines.add(
            BucketRoutine(
              routineId: routine.id,
              order: _bucketRoutines.length + 1,
            ),
          );
        }
      });
      _savePlan();
    }
  }

  Future<void> _confirmClear(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear Week'),
        content: const Text('Start fresh this week?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _bucketRoutines = []);
    await ref.read(weeklyPlanProvider.notifier).clearPlan();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    context.pop();
  }

  void _savePlan() {
    ref.read(weeklyPlanProvider.notifier).upsertPlan(_bucketRoutines);
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required super.key,
    required this.index,
    required this.routineId,
    required this.sequenceNumber,
    required this.name,
    required this.exerciseCount,
    required this.isDone,
    this.onDismissed,
  });

  final int index;
  final String routineId;
  final int sequenceNumber;
  final String name;
  final int exerciseCount;
  final bool isDone;
  final VoidCallback? onDismissed;

  static const _primaryGreen = Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDone
            ? _primaryGreen.withValues(alpha: 0.08)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        children: [
          // Sequence number or checkmark.
          if (isDone)
            const Icon(Icons.check_circle, color: _primaryGreen, size: 24)
          else
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$sequenceNumber',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 12),
          // Name and exercise count.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDone ? _primaryGreen : null,
                  ),
                ),
                Text(
                  '$exerciseCount exercises',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Drag handle (only for non-completed).
          if (!isDone)
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );

    if (isDone || onDismissed == null) return content;

    return Dismissible(
      key: ValueKey('dismiss-$routineId'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: content,
    );
  }
}

class _AddRoutineRow extends StatelessWidget {
  const _AddRoutineRow({
    required super.key,
    required this.atSoftCap,
    required this.onTap,
  });

  final bool atSoftCap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: atSoftCap
            ? 'Weekly goal reached \u2014 tap to add anyway'
            : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusMd),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: atSoftCap ? 0.1 : 0.2,
                  ),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: atSoftCap ? 0.3 : 0.55,
                    ),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Routine',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: atSoftCap ? 0.3 : 0.55,
                      ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddRoutines});

  final VoidCallback onAddRoutines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No routines planned this week',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddRoutines,
            icon: const Icon(Icons.add),
            label: const Text('Add Routines'),
          ),
        ],
      ),
    );
  }
}
