/// Widget tests for [BodyPartRankRow] (Phase 18b).
///
/// The row is asymmetric per the §13.4 onboarding gate:
///   * Untrained body parts (rank 1, totalXp 0, vitalityPeak 0) render as a
///     32 dp _CompressedRow — sigil ghosted, no rank stamp, no hairline.
///   * Trained body parts render as a 60 dp _ExpandedRow — full sigil + name +
///     hairline + [RankStamp].
///
/// These tests pin the height contract and verify the [RankStamp] only appears
/// on the expanded variant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/character_sheet_state.dart';
import 'package:repsaga/features/rpg/models/vitality_state.dart';
import 'package:repsaga/features/rpg/ui/widgets/body_part_rank_row.dart';
import 'package:repsaga/features/rpg/ui/widgets/rank_stamp.dart';

import '../../../../helpers/test_material_app.dart';

BodyPartSheetEntry _entry({
  BodyPart bodyPart = BodyPart.chest,
  int rank = 1,
  double totalXp = 0,
  double vitalityEwma = 0,
  double vitalityPeak = 0,
  VitalityState? vitalityState,
  double xpInRank = 0,
  double xpForNextRank = 60,
}) {
  return BodyPartSheetEntry(
    bodyPart: bodyPart,
    rank: rank,
    vitalityEwma: vitalityEwma,
    vitalityPeak: vitalityPeak,
    vitalityState:
        vitalityState ??
        VitalityStateX.fromVitality(
          vitalityEwma: vitalityEwma,
          vitalityPeak: vitalityPeak,
        ),
    xpInRank: xpInRank,
    xpForNextRank: xpForNextRank,
    totalXp: totalXp,
  );
}

Widget _wrap(BodyPartSheetEntry entry) {
  return TestMaterialApp(
    home: Scaffold(
      body: SafeArea(child: BodyPartRankRow(entry: entry)),
    ),
  );
}

void main() {
  group('BodyPartRankRow', () {
    testWidgets('untrained entry renders compressed row, no RankStamp', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_entry()));
      await tester.pump();

      // The row should be 32 dp tall (compressed) per the kickoff lock.
      final size = tester.getSize(find.byType(BodyPartRankRow));
      expect(size.height, 32);

      // No RankStamp on untrained rows — the kickoff explicitly removed it.
      expect(find.byType(RankStamp), findsNothing);
    });

    testWidgets('trained entry renders expanded row with RankStamp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _entry(
            rank: 5,
            totalXp: 300,
            vitalityEwma: 50,
            vitalityPeak: 60,
            xpInRank: 21.54,
            xpForNextRank: 87.85,
          ),
        ),
      );
      await tester.pump();

      // Expanded row is 60 dp.
      final size = tester.getSize(find.byType(BodyPartRankRow));
      expect(size.height, 60);

      // RankStamp present and shows the rank numeral.
      expect(find.byType(RankStamp), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('any of (rank>1, peak>0, totalXp>0) flips to expanded', (
      tester,
    ) async {
      // Rank > 1 alone.
      await tester.pumpWidget(
        _wrap(_entry(rank: 2, totalXp: 60, vitalityEwma: 10, vitalityPeak: 10)),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(BodyPartRankRow)).height, 60);

      // Peak > 0 alone (e.g., user did one set, no XP yet — defensive case).
      await tester.pumpWidget(_wrap(_entry(vitalityPeak: 5)));
      await tester.pump();
      expect(tester.getSize(find.byType(BodyPartRankRow)).height, 60);

      // totalXp > 0 alone.
      await tester.pumpWidget(_wrap(_entry(totalXp: 1)));
      await tester.pump();
      expect(tester.getSize(find.byType(BodyPartRankRow)).height, 60);
    });

    testWidgets('renders the localized muscle group label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _entry(
            bodyPart: BodyPart.legs,
            rank: 3,
            totalXp: 100,
            vitalityEwma: 40,
            vitalityPeak: 50,
          ),
        ),
      );
      await tester.pump();

      // English locale — 'Legs' is the canonical label.
      expect(find.text('Legs'), findsOneWidget);
    });
  });
}
