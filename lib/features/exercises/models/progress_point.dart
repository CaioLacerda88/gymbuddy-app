// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress_point.freezed.dart';

/// A single point on the per-exercise progress chart.
///
/// One point per user-local calendar date of `workouts.finished_at`. Multiple
/// sessions on the same day collapse into one point at the max weight.
///
/// [weight] is the heaviest completed working-set weight lifted on [date] for
/// the exercise, in the user's preferred weight unit (kg/lbs — units are not
/// converted server-side; the chart renders whatever the user selected in
/// their profile at the time the session was logged).
///
/// [sessionReps] is the reps at which [weight] was achieved (the first set to
/// reach that weight within the day). Reserved for v1.1 "reps" chart / volume
/// toggle — the v1 UI only plots [weight] vs [date].
@freezed
abstract class ProgressPoint with _$ProgressPoint {
  const factory ProgressPoint({
    required DateTime date,
    required double weight,
    required int sessionReps,
  }) = _ProgressPoint;
}
