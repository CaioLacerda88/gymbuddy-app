import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../profile/providers/profile_providers.dart';
import '../../models/progress_point.dart';
import '../../providers/exercise_progress_provider.dart';

/// Per-exercise weight-over-time chart.
///
/// Renders inline inside [ExerciseDetailScreen], between the PR list and the
/// delete button. Read-only glance surface: no tooltips, no zoom, no pan.
///
/// See `tasks/WIP.md` for the design rationale — anti-generic-AI
/// constraints (no gradient fill, no bezier, no card wrapper, one hairline
/// grid, inline min/max labels) are non-negotiable and tested.
class ProgressChartSection extends ConsumerWidget {
  const ProgressChartSection({super.key, required this.exerciseId});

  final String exerciseId;

  static const double _chartHeight = 200;
  static const double _lineWidth = 3;
  static const double _dotRadius = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final window = ref.watch(progressTimeWindowProvider);
    final asyncPoints = ref.watch(
      exerciseProgressProvider(
        ExerciseProgressKey(exerciseId: exerciseId, window: window),
      ),
    );
    final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress ($weightUnit)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _WindowToggle(
          value: window,
          onChanged: (w) =>
              ref.read(progressTimeWindowProvider.notifier).state = w,
        ),
        const SizedBox(height: 12),
        asyncPoints.when(
          loading: () => const SizedBox(
            height: _chartHeight,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) =>
              const _EmptyCopy(text: 'Log this exercise to see your progress'),
          data: (points) => _ChartBody(points: points),
        ),
      ],
    );
  }
}

class _WindowToggle extends StatelessWidget {
  const _WindowToggle({required this.value, required this.onChanged});

  final TimeWindow value;
  final ValueChanged<TimeWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TimeWindow>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: TimeWindow.last90Days, label: Text('90d')),
        ButtonSegment(value: TimeWindow.allTime, label: Text('All time')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyCopy(text: 'Log this exercise to see your progress');
    }

    return Semantics(
      label:
          'Progress chart, ${points.length} '
          '${points.length == 1 ? 'session' : 'sessions'} logged',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: ProgressChartSection._chartHeight,
            child: _LineChart(points: points),
          ),
          if (points.length == 1) ...[
            const SizedBox(height: 8),
            const _EmptyCopy(text: '1 session logged'),
          ],
        ],
      ),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    // y-axis bounds: padded so the line/dots don't clip the top/bottom.
    // For a single data point, pad symmetrically around the value so the
    // dot renders centered vertically.
    final weights = points.map((p) => p.weight).toList();
    final rawMin = weights.reduce((a, b) => a < b ? a : b);
    final rawMax = weights.reduce((a, b) => a > b ? a : b);
    final span = rawMax - rawMin;
    final pad = span == 0 ? (rawMax == 0 ? 1 : rawMax * 0.1) : span * 0.15;
    final yMin = (rawMin - pad).clamp(0, double.infinity).toDouble();
    final yMax = rawMax + pad;

    // x-axis: index-based so we don't have to juggle epoch milliseconds.
    // The index is monotonically increasing with date (buildProgressPoints
    // already sorts ascending), so visually it renders correctly left → right.
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].weight),
    ];
    final xMax = (points.length - 1).toDouble().clamp(0.0, double.infinity);

    // Month labels at left/right x-edges when the series spans >12 weeks.
    final spanWeeks = points.length >= 2
        ? points.last.date.difference(points.first.date).inDays / 7
        : 0;
    final showMonthLabels = spanWeeks > 12;

    return Stack(
      children: [
        LineChart(
          LineChartData(
            minX: 0,
            maxX: xMax == 0 ? 1 : xMax,
            minY: yMin,
            maxY: yMax,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (yMax - yMin) / 2,
              getDrawingHorizontalLine: (value) => FlLine(
                color: onSurface.withValues(alpha: 0.08),
                strokeWidth: 1,
              ),
              // Only draw the single midpoint hairline — skip the bounds.
              checkToShowHorizontalLine: (value) {
                final mid = yMin + (yMax - yMin) / 2;
                return (value - mid).abs() < 0.0001;
              },
            ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: primary,
                barWidth: points.length == 1
                    ? 0
                    : ProgressChartSection._lineWidth,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                    radius: ProgressChartSection._dotRadius,
                    color: primary,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
        Positioned(
          right: 4,
          top: 0,
          child: _AxisLabel(
            text: _formatWeight(rawMax),
            style: theme.textTheme.labelLarge?.copyWith(
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: showMonthLabels ? 20 : 0,
          child: _AxisLabel(
            text: _formatWeight(rawMin),
            style: theme.textTheme.labelLarge?.copyWith(
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        if (showMonthLabels) ...[
          Positioned(
            left: 4,
            bottom: 0,
            child: _AxisLabel(
              text: DateFormat.MMM().format(points.first.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 0,
            child: _AxisLabel(
              text: DateFormat.MMM().format(points.last.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Format a weight number with up to one decimal place, trimming the
  /// trailing `.0` when it's a whole number.
  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}
