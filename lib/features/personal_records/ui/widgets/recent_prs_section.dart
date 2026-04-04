import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/record_type.dart';
import '../../providers/pr_providers.dart';

class RecentPRsSection extends ConsumerWidget {
  const RecentPRsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(recentPRsProvider);

    return prsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (prs) {
        if (prs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Text(
                      'RECENT RECORDS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    );
                  },
                ),
                TextButton(
                  onPressed: () => context.go('/records'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...prs.map(
              (pr) => _PRRow(
                exerciseName: pr.exerciseName,
                recordType: pr.record.recordType,
                value: pr.record.value,
                achievedAt: pr.record.achievedAt,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _PRRow extends StatelessWidget {
  const _PRRow({
    required this.exerciseName,
    required this.recordType,
    required this.value,
    required this.achievedAt,
  });

  final String exerciseName;
  final RecordType recordType;
  final double value;
  final DateTime achievedAt;

  String _formatValue() {
    switch (recordType) {
      case RecordType.maxReps:
        return '${value.toInt()} reps';
      case RecordType.maxWeight:
      case RecordType.maxVolume:
        final isWhole = value == value.truncate();
        final numStr = isWhole ? value.toInt().toString() : value.toString();
        return '$numStr kg';
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    if (diff < 30) return '${(diff / 7).floor()}w ago';
    return '${(diff / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleText =
        '${recordType.displayName} \u00b7 ${_formatRelativeDate(achievedAt)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatValue(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
