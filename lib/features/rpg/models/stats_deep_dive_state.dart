import 'body_part.dart';
import 'vitality_state.dart';

/// State shape consumed by the `/saga/stats` deep-dive screen (Phase 18d.2).
///
/// Composed by [statsProvider] from `body_part_progress` (current EWMA +
/// peak), `xp_events` (90-day reconstruction window), `exercise_peak_loads`
/// (peak loads list), and the user-exercise lookup needed to resolve names
/// + muscle groups for the per-body-part peak-loads grouping.
///
/// **Why a top-level state class instead of separate providers per section:**
/// the screen's six sections share the same temporal window — earliest
/// activity gates the chart's X-axis _and_ informs the empty-state for the
/// volume/peak table _and_ informs the peak-loads grouping. Composing once
/// at provider time avoids three round-trips of cross-section coordination
/// in the UI.
class StatsDeepDiveState {
  const StatsDeepDiveState({
    required this.vitalityRows,
    required this.trendByBodyPart,
    required this.volumePeakByBodyPart,
    required this.peakLoadsByBodyPart,
    required this.earliestActivity,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Day-0 / loading-failed fallback. Six dormant rows, empty trend lines,
  /// empty peaks. Identity invariant: rendering this state must produce a
  /// laid-out screen with no overflow / no null-deref.
  factory StatsDeepDiveState.empty() {
    final now = DateTime.now();
    return StatsDeepDiveState(
      vitalityRows: [
        for (var i = 0; i < activeBodyParts.length; i++)
          VitalityTableRow(
            bodyPart: activeBodyParts[i],
            pct: 0,
            state: VitalityState.dormant,
            rank: 1,
          ),
      ],
      trendByBodyPart: {
        for (final bp in activeBodyParts) bp: const <TrendPoint>[],
      },
      volumePeakByBodyPart: {
        for (final bp in activeBodyParts)
          bp: const VolumePeakRow(weeklyVolumeSets: 0, peakEwma: 0),
      },
      peakLoadsByBodyPart: const {},
      earliestActivity: null,
      windowStart: now.subtract(const Duration(days: 90)),
      windowEnd: now,
    );
  }

  /// One row per active body part, in [activeBodyParts] canonical order.
  /// Drives both the live Vitality table and the chart's selection set.
  final List<VitalityTableRow> vitalityRows;

  /// Reconstructed daily trace per body part, oldest → newest. Empty list
  /// for body parts the user has never trained (rendered as a flat-zero
  /// line by the chart). All non-empty lists share the same length and the
  /// same date sequence as [windowStart] → [windowEnd].
  final Map<BodyPart, List<TrendPoint>> trendByBodyPart;

  /// Per-body-part volume-and-peak row for the secondary table.
  final Map<BodyPart, VolumePeakRow> volumePeakByBodyPart;

  /// Per-body-part peak-loads list (grouped + sorted), sourced from
  /// `exercise_peak_loads` joined with `exercises.muscle_group`. Body parts
  /// with no recorded peaks are absent from the map. The ExpansionTile
  /// section shows the empty state when the map is empty.
  final Map<BodyPart, List<PeakLoadRow>> peakLoadsByBodyPart;

  /// Timestamp of the user's earliest `xp_event`. `null` for users who have
  /// never recorded a set. Drives the hybrid X-axis decision.
  final DateTime? earliestActivity;

  /// Inclusive start of the trend chart window (UTC midnight).
  final DateTime windowStart;

  /// Inclusive end of the trend chart window — always "today" UTC midnight.
  final DateTime windowEnd;

  /// True when [windowStart] is the user's earliest activity (history <30
  /// days). Drives the heading copy + X-axis label for the chart.
  ///
  /// Threshold rule: history `< 30` days → narrow window; history `>= 30`
  /// days → 90-day window. Chosen so the boundary day-30 user gets the
  /// "stable" 90-day surface (their first month of trace is still visible
  /// on the left of the chart but is no longer the entire surface).
  bool get useNarrowWindow {
    if (earliestActivity == null) return false;
    final daysSinceFirst = windowEnd.difference(earliestActivity!).inDays;
    return daysSinceFirst < 30;
  }

  /// Total days spanned by the trend chart. 90 in standard mode; smaller
  /// in narrow mode.
  int get windowSpanDays => windowEnd.difference(windowStart).inDays;
}

/// One row in the live Vitality table (six rows total).
class VitalityTableRow {
  const VitalityTableRow({
    required this.bodyPart,
    required this.pct,
    required this.state,
    required this.rank,
  });

  final BodyPart bodyPart;

  /// 0..1 ratio. Renders as `(pct * 100).round()%`.
  final double pct;
  final VitalityState state;
  final int rank;
}

/// One sample on the trend chart — daily granularity.
class TrendPoint {
  const TrendPoint({required this.date, required this.pct});

  final DateTime date;

  /// 0..1 ratio relative to the body part's lifetime peak EWMA.
  final double pct;
}

/// One row in the per-body-part Volume & Peak table.
class VolumePeakRow {
  const VolumePeakRow({required this.weeklyVolumeSets, required this.peakEwma});

  /// Set count attributed to this body part over the last 7 days.
  final int weeklyVolumeSets;

  /// Lifetime peak EWMA — never decreases. Rendered with tabular figures.
  final double peakEwma;
}

/// One row in the per-exercise Peak Loads section.
class PeakLoadRow {
  const PeakLoadRow({
    required this.exerciseName,
    required this.peakWeight,
    required this.peakReps,
    required this.estimated1RM,
  });

  /// Localized display name fetched via `fn_exercises_localized`.
  final String exerciseName;
  final double peakWeight;
  final int peakReps;

  /// Epley-style 1RM estimate. Null when peakReps == 0 (bodyweight /
  /// non-loaded peaks) so the UI can suppress the "1RM est." label.
  final double? estimated1RM;
}

/// Convenience: derive [BodyPart] count of active rows for tests/UI gates.
extension StatsActiveBodyPartCount on StatsDeepDiveState {
  /// Number of body parts with at least one recorded peak.
  int get activeBodyPartCount =>
      vitalityRows.where((r) => r.pct > 0 || r.rank > 1).length;
}
