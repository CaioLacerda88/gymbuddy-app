import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/number_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../models/body_part.dart';
import '../../models/stats_deep_dive_state.dart';
import '../utils/vitality_state_styles.dart';
import 'body_part_localization.dart';

/// Per-body-part peak-loads list rendered as a column of [ExpansionTile]s on
/// the `/saga/stats` deep-dive screen.
///
/// **One ExpansionTile per body part with peaks.** The body part with the
/// highest peak weight (across all its exercises) opens by default —
/// everything else is collapsed so the user lands on a digestible surface
/// instead of a wall of rows. Tapping a header expands/collapses; only one
/// is open at a time? No — Material's stock [ExpansionTile] permits
/// multiple-open and we don't fight that. The user can survey their peaks
/// across body parts side-by-side if they choose.
///
/// **Empty state.** When [peakLoadsByBodyPart] is empty, render a single
/// muted line of copy: `peakLoadsEmpty`. The table is the user's "you've set
/// no peaks yet" gate; we don't show empty headers per body part because
/// that would suggest there's something hidden inside.
///
/// **Per-row layout.** Each row inside an open ExpansionTile is a raw `Row`
/// with: localized exercise name on the left (Expanded, ellipsised),
/// `PEAK weight × reps` in tabular figures, and an "1RM est." secondary line
/// when the Epley formula applies (`peakReps > 0`, present in the model as
/// non-null `estimated1RM`).
class PeakLoadsTable extends ConsumerWidget {
  const PeakLoadsTable({super.key, required this.peakLoadsByBodyPart});

  /// Per-body-part peak-load lists (sorted desc by peak weight inside the
  /// list). Body parts with no peaks are absent from the map; the keys we
  /// render are exactly the keys that are present.
  final Map<BodyPart, List<PeakLoadRow>> peakLoadsByBodyPart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (peakLoadsByBodyPart.isEmpty) {
      return Semantics(
        container: true,
        identifier: 'peak-loads-table',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            l10n.peakLoadsEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textDim,
            ),
          ),
        ),
      );
    }

    // Resolve the body part to default-expand: the one with the heaviest
    // single peak weight across its rows. Stable tiebreaker: [activeBodyParts]
    // canonical order. We compute this once at build time — the user's tap
    // on another header doesn't move the default-expanded marker.
    final defaultExpanded = _defaultExpandedBodyPart(peakLoadsByBodyPart);
    final weightUnit = ref.watch(profileProvider).value?.weightUnit ?? 'kg';
    final locale = Localizations.localeOf(context).languageCode;

    // Render in [activeBodyParts] canonical order (chest, back, legs, etc.).
    final orderedBodyParts = activeBodyParts
        .where((bp) => peakLoadsByBodyPart.containsKey(bp))
        .toList();

    return Semantics(
      container: true,
      identifier: 'peak-loads-table',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final bp in orderedBodyParts)
            _PeakLoadsExpansion(
              bodyPart: bp,
              rows: peakLoadsByBodyPart[bp]!,
              initiallyExpanded: bp == defaultExpanded,
              weightUnit: weightUnit,
              locale: locale,
            ),
        ],
      ),
    );
  }

  /// Pick the default-expanded body part: highest single peak weight across
  /// the data set. Tie-broken by canonical [activeBodyParts] order so the
  /// pick is deterministic across rebuilds.
  static BodyPart _defaultExpandedBodyPart(
    Map<BodyPart, List<PeakLoadRow>> data,
  ) {
    BodyPart? best;
    double bestWeight = -1;
    for (final bp in activeBodyParts) {
      final rows = data[bp];
      if (rows == null || rows.isEmpty) continue;
      // Rows are pre-sorted desc; rows.first is the body part's own peak.
      final headWeight = rows.first.peakWeight;
      if (headWeight > bestWeight) {
        bestWeight = headWeight;
        best = bp;
      }
    }
    // Fallback to the first body part with data if literally nothing has a
    // positive weight — shouldn't happen because the provider drops empty
    // body parts, but a defensive default keeps the layout stable.
    return best ?? data.keys.first;
  }
}

class _PeakLoadsExpansion extends StatelessWidget {
  const _PeakLoadsExpansion({
    required this.bodyPart,
    required this.rows,
    required this.initiallyExpanded,
    required this.weightUnit,
    required this.locale,
  });

  final BodyPart bodyPart;
  final List<PeakLoadRow> rows;
  final bool initiallyExpanded;
  final String weightUnit;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bodyPartTint =
        VitalityStateStyles.bodyPartColor[bodyPart] ?? AppColors.hotViolet;
    final localizedName = localizedBodyPartName(bodyPart, l10n);

    return Theme(
      // Strip ExpansionTile's stock divider lines — the parent table already
      // has its own layout rhythm; injecting Material's default top/bottom
      // dividers leaks the stock-Material register the screen avoids.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('peak-loads-${bodyPart.dbValue}'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: AppColors.textDim,
        collapsedIconColor: AppColors.textDim,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: bodyPartTint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(localizedName, style: theme.textTheme.titleSmall),
            ),
            // Header trailing: count of peaks under this body part. Communicates
            // "you have 7 lifts logged here" without forcing the user to
            // expand the section.
            Text(
              '${rows.length}',
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDim,
                height: 1,
              ),
            ),
          ],
        ),
        children: [
          for (final row in rows)
            _PeakLoadRowView(row: row, weightUnit: weightUnit, locale: locale),
        ],
      ),
    );
  }
}

class _PeakLoadRowView extends StatelessWidget {
  const _PeakLoadRowView({
    required this.row,
    required this.weightUnit,
    required this.locale,
  });

  final PeakLoadRow row;
  final String weightUnit;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final weightStr = AppNumberFormat.weightWithUnit(
      row.peakWeight,
      locale: locale,
      unit: weightUnit,
    );
    // Format: "120 kg × 5". The middle "×" uses a literal mathematical times
    // symbol U+00D7 — not the ASCII letter x — for typographic correctness.
    final repsStr = row.peakReps > 0 ? ' × ${row.peakReps}' : '';

    final estimated1Rm = row.estimated1RM;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.exerciseName,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (estimated1Rm != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.oneRmEstimateLabel} ${AppNumberFormat.weightWithUnit(estimated1Rm, locale: locale, unit: weightUnit)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right-aligned peak readout in tabular figures.
          Text(
            '$weightStr$repsStr',
            style: GoogleFonts.rajdhani(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textCream,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
