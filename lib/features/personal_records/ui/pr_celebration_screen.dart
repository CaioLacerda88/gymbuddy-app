import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/providers/profile_providers.dart';
import '../domain/pr_detection_service.dart';
import '../models/personal_record.dart';
import '../models/record_type.dart';

/// Full-screen celebration shown after a workout with new personal records.
///
/// First workout: consolidated benchmarks message.
/// Subsequent PRs: bold "NEW PR" banner with spring-animated values.
class PRCelebrationScreen extends ConsumerStatefulWidget {
  const PRCelebrationScreen({
    super.key,
    required this.result,
    required this.exerciseNames,
  });

  final PRDetectionResult result;
  final Map<String, String> exerciseNames;

  @override
  ConsumerState<PRCelebrationScreen> createState() =>
      _PRCelebrationScreenState();
}

class _PRCelebrationScreenState extends ConsumerState<PRCelebrationScreen>
    with SingleTickerProviderStateMixin {
  double _flashOpacity = 0.3;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Start the green flash fade-out after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _flashOpacity = 0.0);
        _scaleController.forward();
        // Second haptic pulse for extra punch.
        Future.delayed(const Duration(milliseconds: 300), () {
          HapticFeedback.mediumImpact();
        });
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  String _formatValue(PersonalRecord record, String weightUnit) {
    return switch (record.recordType) {
      RecordType.maxWeight =>
        record.reps != null
            ? '${_formatWeight(record.value)} $weightUnit \u00d7 ${record.reps}'
            : '${_formatWeight(record.value)} $weightUnit',
      RecordType.maxReps => '${record.value.toInt()} reps',
      RecordType.maxVolume => '${_formatWeight(record.value)} $weightUnit',
    };
  }

  /// Format weight without trailing .0 (e.g. 100.0 -> "100", 72.5 -> "72.5").
  String _formatWeight(double value) {
    return value == value.roundToDouble() && value.truncateToDouble() == value
        ? value.toInt().toString()
        : value.toString();
  }

  IconData _iconForType(RecordType type) {
    return switch (type) {
      RecordType.maxWeight => Icons.fitness_center,
      RecordType.maxReps => Icons.repeat,
      RecordType.maxVolume => Icons.bar_chart,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weightUnit =
        ref.watch(profileProvider).valueOrNull?.weightUnit ?? 'kg';

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  if (widget.result.isFirstWorkout)
                    _buildFirstWorkoutContent(theme, weightUnit)
                  else
                    _buildPRContent(theme, weightUnit),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Green flash overlay
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _flashOpacity,
              duration: const Duration(milliseconds: 400),
              child: Container(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstWorkoutContent(ThemeData theme, String weightUnit) {
    // Group records by exercise.
    final grouped = <String, List<PersonalRecord>>{};
    for (final record in widget.result.newRecords) {
      final name =
          widget.exerciseNames[record.exerciseId] ?? 'Unknown Exercise';
      (grouped[name] ??= []).add(record);
    }

    return Column(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            Icons.emoji_events,
            size: 72,
            color: theme.colorScheme.primary,
            shadows: [
              Shadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                blurRadius: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'First Workout Complete!',
          style: theme.textTheme.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'These are your starting benchmarks',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ...grouped.entries.map(
          (entry) => _ExerciseRecordGroup(
            exerciseName: entry.key,
            records: entry.value,
            formatValue: (r) => _formatValue(r, weightUnit),
            iconForType: _iconForType,
          ),
        ),
      ],
    );
  }

  Widget _buildPRContent(ThemeData theme, String weightUnit) {
    return Column(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Text(
            'NEW PR',
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...widget.result.newRecords.map((record) {
          final name =
              widget.exerciseNames[record.exerciseId] ?? 'Unknown Exercise';
          return _AnimatedRecordCard(
            exerciseName: name,
            record: record,
            formattedValue: _formatValue(record, weightUnit),
            icon: _iconForType(record.recordType),
          );
        }),
      ],
    );
  }
}

class _ExerciseRecordGroup extends StatelessWidget {
  const _ExerciseRecordGroup({
    required this.exerciseName,
    required this.records,
    required this.formatValue,
    required this.iconForType,
  });

  final String exerciseName;
  final List<PersonalRecord> records;
  final String Function(PersonalRecord) formatValue;
  final IconData Function(RecordType) iconForType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exerciseName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ...records.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      iconForType(r.recordType),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.recordType.displayName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      formatValue(r),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedRecordCard extends StatelessWidget {
  const _AnimatedRecordCard({
    required this.exerciseName,
    required this.record,
    required this.formattedValue,
    required this.icon,
  });

  final String exerciseName;
  final PersonalRecord record;
  final String formattedValue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exerciseName, style: theme.textTheme.titleMedium),
                  Text(
                    record.recordType.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Text(
                formattedValue,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
