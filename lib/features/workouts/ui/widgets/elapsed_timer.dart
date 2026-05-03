import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workout_providers.dart';

/// HH:MM:SS / MM:SS readout of the time elapsed since the workout started.
///
/// Watches [elapsedTimerProvider] (a `Stream.periodic(1s)` family keyed by
/// the `startedAt` timestamp) and reformats the duration on every tick. The
/// provider itself is the timekeeping side; this widget is presentation only.
class ElapsedTimer extends ConsumerWidget {
  const ElapsedTimer({required this.startedAt, super.key});

  final DateTime startedAt;

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elapsed = ref.watch(elapsedTimerProvider(startedAt));

    return Text(
      elapsed.when(
        data: _format,
        loading: () => '00:00',
        error: (_, _) => '00:00',
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
