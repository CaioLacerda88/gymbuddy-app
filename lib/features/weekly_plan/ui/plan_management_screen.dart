import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/device/platform_info.dart';
import '../../../core/theme/radii.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../analytics/data/models/analytics_event.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../routines/models/routine.dart';
import '../../routines/providers/notifiers/routine_list_notifier.dart';
import '../../workouts/providers/workout_history_providers.dart';
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

  // --- Analytics debounce state -----------------------------------------
  //
  // `week_plan_saved` must fire at most once per edit session, otherwise
  // every reorder/remove/undo pushes a duplicate event and the funnel is
  // meaningless. The persistence call (`upsertPlan`) still runs on every
  // edit — we debounce ONLY the analytics insert. We fire once per session
  // when the user leaves the screen (dispose), capturing whichever options
  // were most recently in effect.
  //
  // Tracked bits:
  // - `_pendingAnalyticsEvent`: true once the user has made at least one
  //   edit that would have fired `week_plan_saved`
  // - `_lastUsedAutofill` / `_lastReplacedExisting`: latest flags from the
  //   most recent edit, used when we finally fire at dispose
  // - `_debouncedAnalyticsRepo` / `_debouncedAnalyticsUserId`: captured on
  //   the FIRST edit. `ref` cannot be used in dispose() — Riverpod treats
  //   the element as already torn down at that point — so we must hold the
  //   repo and user id directly.
  bool _pendingAnalyticsEvent = false;
  bool _lastUsedAutofill = false;
  bool _lastReplacedExisting = false;
  AnalyticsRepository? _debouncedAnalyticsRepo;
  String? _debouncedAnalyticsUserId;
  int? _debouncedTrainingFrequency;

  @override
  void dispose() {
    // Fire a single analytics event for the entire edit session, capturing
    // the most-recent flags (usedAutofill / replacedExisting). This is the
    // funnel-friendly "user saved the plan" signal — intermediate reorders
    // and undos do not fire their own events.
    if (_pendingAnalyticsEvent) {
      _flushAnalyticsEvent();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Listen for the async plan value to resolve (especially on slow
    // connections where the first build fires before data arrives).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(weeklyPlanProvider, (previous, next) {
        // Only seed from provider if user hasn't started editing.
        if (_dirty) return;
        final plan = next.value;
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

    final allRoutines = routinesAsync.value ?? [];
    final routineMap = <String, Routine>{for (final r in allRoutines) r.id: r};
    final trainingFrequency = profile.value?.trainingFrequencyPerWeek ?? 3;

    final atSoftCap = _bucketRoutines.length >= trainingFrequency;

    return Scaffold(
      appBar: AppBar(
        title: const Text("This Week's Plan"),
        actions: [
          Semantics(
            label: 'More options',
            child: PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'clear') _confirmClear(context);
                if (value == 'autofill') {
                  _autoFill(allRoutines, trainingFrequency);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'autofill',
                  child: Text('Auto-fill'),
                ),
                const PopupMenuItem(value: 'clear', child: Text('Clear Week')),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _bucketRoutines.isEmpty
                ? _EmptyState(
                    onAddRoutines: () => _showAddSheet(allRoutines),
                    onAutoFill: () => _autoFill(allRoutines, trainingFrequency),
                  )
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
                          bucketCount: _bucketRoutines.length,
                          trainingFrequency: trainingFrequency,
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
    _savePlan(usedAutofill: false, replacedExisting: false);
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
    _savePlan(usedAutofill: false, replacedExisting: false);

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
                // Clamp to current list length in case reorders or other
                // removals happened between remove and undo.
                final safeIndex = index.clamp(0, _bucketRoutines.length);
                _bucketRoutines.insert(safeIndex, removed);
                _renumber();
              });
              _savePlan(usedAutofill: false, replacedExisting: false);
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
      _savePlan(usedAutofill: false, replacedExisting: false);
    }
  }

  /// Auto-fill the bucket with the user's most-started routines.
  ///
  /// Ranks routines by how often their name appears in workout history.
  /// Fills up to [trainingFrequency] slots. If the bucket already has
  /// routines, shows a confirmation dialog before replacing.
  Future<void> _autoFill(
    List<Routine> allRoutines,
    int trainingFrequency,
  ) async {
    if (allRoutines.isEmpty) return;

    // Don't auto-fill if workout history hasn't loaded yet — frequency
    // ranking would silently fall back to alphabetical order.
    final historyState = ref.read(workoutHistoryProvider);
    if (historyState.isLoading && !historyState.hasValue) return;

    // If bucket already has routines, confirm replacement.
    if (_bucketRoutines.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Replace current plan?'),
          content: const Text(
            'Auto-fill will replace your current plan with your most-used routines.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    // Build frequency map from workout history (name -> count).
    final history = ref.read(workoutHistoryProvider).value ?? [];
    final nameFrequency = <String, int>{};
    for (final workout in history) {
      nameFrequency[workout.name] = (nameFrequency[workout.name] ?? 0) + 1;
    }

    // Sort routines by frequency descending, then by name for stability.
    final ranked = [...allRoutines]
      ..sort((a, b) {
        final freqA = nameFrequency[a.name] ?? 0;
        final freqB = nameFrequency[b.name] ?? 0;
        if (freqB != freqA) return freqB.compareTo(freqA);
        return a.name.compareTo(b.name);
      });

    // Take the top N routines up to training frequency.
    final count = trainingFrequency < ranked.length
        ? trainingFrequency
        : ranked.length;
    final selected = ranked.take(count).toList();

    // Capture BEFORE the mutation so we can record whether autofill
    // replaced an existing plan.
    final wasNotEmpty = _bucketRoutines.isNotEmpty;
    setState(() {
      _dirty = true;
      _bucketRoutines = selected.indexed.map((entry) {
        return BucketRoutine(routineId: entry.$2.id, order: entry.$1 + 1);
      }).toList();
    });
    _savePlan(usedAutofill: true, replacedExisting: wasNotEmpty);
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

  /// Persist the current bucket state to Supabase and record that we owe an
  /// analytics event when the user finally leaves the screen.
  ///
  /// We deliberately do NOT fire `week_plan_saved` here: a single edit
  /// session (reorder + remove + undo + add routine) calls this method four
  /// or more times in a few seconds. Firing per-call floods the funnel with
  /// duplicate events. Instead we mark that an event is pending and store
  /// the most-recent flags; the actual insert happens once, at dispose,
  /// via [_flushAnalyticsEvent]. The persistence call stays per-edit so
  /// UX stays live.
  ///
  /// We ALSO capture a reference to the analytics repository and the user id
  /// on the first edit — `ref` cannot be used inside `dispose()` (the
  /// ConsumerStatefulElement is already torn down by then), so we must hold
  /// the repo object directly.
  void _savePlan({required bool usedAutofill, required bool replacedExisting}) {
    ref.read(weeklyPlanProvider.notifier).upsertPlan(_bucketRoutines);
    _pendingAnalyticsEvent = true;
    // usedAutofill and replacedExisting are "sticky" within a session: if
    // the user first auto-filled then reordered one card, the event that
    // ships at dispose should still say used_autofill=true. So we OR-in
    // any truthy value instead of overwriting.
    _lastUsedAutofill = _lastUsedAutofill || usedAutofill;
    _lastReplacedExisting = _lastReplacedExisting || replacedExisting;
    // Capture repo + user id + training frequency while ref is still alive.
    // Refreshed on every edit so the latest profile value is used at flush.
    _debouncedAnalyticsRepo = ref.read(analyticsRepositoryProvider);
    _debouncedAnalyticsUserId = ref
        .read(authRepositoryProvider)
        .currentUser
        ?.id;
    _debouncedTrainingFrequency =
        ref.read(profileProvider).value?.trainingFrequencyPerWeek ?? 3;
  }

  /// Fire the debounced `week_plan_saved` analytics event exactly once.
  /// Called from [dispose] when the user leaves the plan screen.
  ///
  /// Must not touch `ref` — the widget element is disposed before this
  /// runs. All data needed to build the event has been captured in the
  /// state fields during earlier edits.
  void _flushAnalyticsEvent() {
    final userId = _debouncedAnalyticsUserId;
    final repo = _debouncedAnalyticsRepo;
    final trainingFrequency = _debouncedTrainingFrequency ?? 3;
    if (userId == null || repo == null) return;
    unawaited(
      repo.insertEvent(
        userId: userId,
        event: AnalyticsEvent.weekPlanSaved(
          routineCount: _bucketRoutines.length,
          atSoftCap: _bucketRoutines.length >= trainingFrequency,
          usedAutofill: _lastUsedAutofill,
          replacedExisting: _lastReplacedExisting,
        ),
        platform: currentPlatform(),
        appVersion: currentAppVersion(),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use the theme primary color (M3 green) instead of a hardcoded hex so
    // future brand/theme changes propagate here automatically.
    final primary = theme.colorScheme.primary;

    final content = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDone
            ? primary.withValues(alpha: 0.08)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        children: [
          // Sequence number or checkmark.
          if (isDone)
            Icon(Icons.check_circle, color: primary, size: 24)
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
                    color: isDone ? primary : null,
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
    required this.bucketCount,
    required this.trainingFrequency,
    required this.onTap,
  });

  final bool atSoftCap;
  final int bucketCount;
  final int trainingFrequency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadiusMd),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              atSoftCap
                  ? '$trainingFrequency/$trainingFrequency planned — ready to go'
                  : '$bucketCount/$trainingFrequency planned this week',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddRoutines, required this.onAutoFill});

  final VoidCallback onAddRoutines;
  final VoidCallback onAutoFill;

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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAutoFill,
            icon: const Icon(Icons.repeat),
            label: const Text('Auto-fill'),
          ),
        ],
      ),
    );
  }
}
