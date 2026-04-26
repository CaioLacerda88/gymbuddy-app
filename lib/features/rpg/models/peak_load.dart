// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'peak_load.freezed.dart';
part 'peak_load.g.dart';

/// Per-`(user_id, exercise_id)` lifetime peak weight.
///
/// Drives the strength multiplier in [XpCalculator]. **Permanent**: never
/// decreases. The `record_set_xp` RPC advances this row only when
/// `weight > peak_weight`; downstream readers can rely on the monotone
/// invariant.
///
/// `peakReps` is the rep count at which the peak was set — not used by the
/// XP formula (which only consumes the weight) but useful for the
/// stats-deep-dive screen (Phase 18d) and PR detection.
@freezed
abstract class PeakLoad with _$PeakLoad {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PeakLoad({
    required String userId,
    required String exerciseId,
    required double peakWeight,
    required int peakReps,
    required DateTime peakDate,
    required DateTime updatedAt,
  }) = _PeakLoad;

  factory PeakLoad.fromJson(Map<String, dynamic> json) =>
      _$PeakLoadFromJson(json);
}
