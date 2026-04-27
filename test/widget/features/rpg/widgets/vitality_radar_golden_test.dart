/// Golden tests for [VitalityRadar] (Phase 18b).
///
/// The radar is the highest-risk paint surface in the character sheet — a
/// single CustomPainter, no widget composition, fully driven by the input
/// `BodyPartSheetEntry` list. Goldens pin two reference shapes that catch
/// regressions the assertion-only tests in `vitality_radar_test.dart` miss:
///
///   * **Day-0 hexagon** — all six entries at rank 1, vitalityState Dormant.
///     Should render a near-center collapsed polygon (the floor at 0.02 of
///     outerRadius). This guards against an accidental "empty void" regression
///     where a fresh user sees a flat line because the floor was removed.
///   * **Skewed shape** — three high-rank entries (80+) and three low-rank
///     entries (rank 5). Should render an asymmetric polygon — chest/back/
///     legs vertices push out, shoulders/arms/core stay near center. This
///     guards against a regression where the ranks were averaged or the
///     vertex order was scrambled.
///
/// Implementation note: goldens are baked from a 1.0 device pixel ratio
/// 800x1200 surface — same as the assertion-only tests in
/// `vitality_radar_test.dart`. This keeps the file-size of the golden PNGs
/// consistent across reruns.
///
/// Re-bake the goldens with:
///   flutter test --update-goldens \
///     test/widget/features/rpg/widgets/vitality_radar_golden_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/character_sheet_state.dart';
import 'package:repsaga/features/rpg/models/vitality_state.dart';
import 'package:repsaga/features/rpg/ui/widgets/vitality_radar.dart';

import '../../../../helpers/test_material_app.dart';

BodyPartSheetEntry _entry(BodyPart bp, int rank, VitalityState state) {
  return BodyPartSheetEntry(
    bodyPart: bp,
    rank: rank,
    vitalityEwma: state == VitalityState.dormant ? 0 : 50,
    vitalityPeak: state == VitalityState.dormant ? 0 : 60,
    vitalityState: state,
    xpInRank: 0,
    xpForNextRank: 60,
    totalXp: rank == 1 ? 0 : 200,
  );
}

/// Day-0 — all six entries at rank 1 + vitalityState Dormant.
List<BodyPartSheetEntry> _dayZero() {
  return activeBodyParts
      .map((bp) => _entry(bp, 1, VitalityState.dormant))
      .toList(growable: false);
}

/// Skewed — chest / back / legs at rank 80+ (Radiant), shoulders / arms /
/// core at rank 5 (Active). Asymmetric polygon catches vertex-order or
/// rank-fraction regressions.
List<BodyPartSheetEntry> _skewed() {
  return [
    _entry(BodyPart.chest, 90, VitalityState.radiant),
    _entry(BodyPart.back, 85, VitalityState.radiant),
    _entry(BodyPart.legs, 80, VitalityState.radiant),
    _entry(BodyPart.shoulders, 5, VitalityState.active),
    _entry(BodyPart.arms, 5, VitalityState.active),
    _entry(BodyPart.core, 5, VitalityState.active),
  ];
}

/// Wraps the radar in a fixed-size container so the golden output is
/// deterministic regardless of host MediaQuery defaults.
Widget _wrap(List<BodyPartSheetEntry> entries) {
  return TestMaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 320,
          child: RepaintBoundary(child: VitalityRadar(entries: entries)),
        ),
      ),
    ),
  );
}

void main() {
  group('VitalityRadar golden', () {
    setUp(() {
      // Match the assertion-only test surface so golden geometry is stable.
      // This must be set per-test (not group-level) because the binding
      // resets between tests.
    });

    testWidgets('day-0 — perfect minimum hexagon', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(_dayZero()));
      await tester.pump();

      await expectLater(
        find.byType(VitalityRadar),
        matchesGoldenFile('goldens/vitality_radar_day0.png'),
      );
    });

    testWidgets('skewed — three Radiant + three Active', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(_skewed()));
      await tester.pump();

      await expectLater(
        find.byType(VitalityRadar),
        matchesGoldenFile('goldens/vitality_radar_skewed.png'),
      );
    });
  });
}
