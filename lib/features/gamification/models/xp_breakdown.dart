// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'xp_breakdown.freezed.dart';
part 'xp_breakdown.g.dart';

/// Per-workout XP award decomposition.
///
/// Every field is an independently-computed component of the
/// [XpCalculator.compute] formula. [total] is the final amount the server
/// stores on `xp_events.amount` — the sum of all components.
///
/// Why a flat record instead of a map:
/// - The celebration overlay (17a) shows each component as a discrete line
///   ("BASE +50", "VOLUME +3"…). Keeping the shape flat means the UI can
///   just read fields; no runtime key presence checks.
/// - The migration's `xp_events.breakdown jsonb` column is documented as
///   holding exactly these keys plus an enum-like `source` tag written by
///   the repository. Keep the shape predictable across layers.
@freezed
abstract class XpBreakdown with _$XpBreakdown {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory XpBreakdown({
    required int base,
    required int volume,
    required int intensity,
    required int pr,
    required int quest,
    required int comeback,
    required int total,
  }) = _XpBreakdown;

  factory XpBreakdown.fromJson(Map<String, dynamic> json) =>
      _$XpBreakdownFromJson(json);

  /// All-zero breakdown used for empty defaults / initial state.
  static const XpBreakdown zero = XpBreakdown(
    base: 0,
    volume: 0,
    intensity: 0,
    pr: 0,
    quest: 0,
    comeback: 0,
    total: 0,
  );
}
