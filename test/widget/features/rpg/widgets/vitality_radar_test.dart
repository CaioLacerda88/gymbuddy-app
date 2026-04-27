/// Widget tests for [VitalityRadar] (Phase 18b).
///
/// The radar is a single CustomPainter; the tests pin behaviour we care about
/// at the widget boundary:
///   * Mounts without throwing for both day-0 (all dormant) and high-rank
///     mixed inputs.
///   * Fails an assertion when given the wrong number of entries (the painter
///     assumes a hexagon).
///   * Reserves the requested square size.
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

List<BodyPartSheetEntry> _allDormant() {
  return activeBodyParts
      .map((bp) => _entry(bp, 1, VitalityState.dormant))
      .toList(growable: false);
}

List<BodyPartSheetEntry> _mixed() {
  return [
    _entry(BodyPart.chest, 12, VitalityState.radiant),
    _entry(BodyPart.back, 8, VitalityState.active),
    _entry(BodyPart.legs, 4, VitalityState.fading),
    _entry(BodyPart.shoulders, 1, VitalityState.dormant),
    _entry(BodyPart.arms, 6, VitalityState.active),
    _entry(BodyPart.core, 3, VitalityState.fading),
  ];
}

Widget _wrap(List<BodyPartSheetEntry> entries, {double size = 320}) {
  return TestMaterialApp(
    home: Scaffold(
      body: Center(
        child: VitalityRadar(entries: entries, size: size),
      ),
    ),
  );
}

void main() {
  group('VitalityRadar', () {
    testWidgets('mounts without throwing for day-0 (all dormant) input', (
      tester,
    ) async {
      // Constrain the surface so the 320-dp radar fits.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(_allDormant()));
      await tester.pump();

      expect(find.byType(VitalityRadar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts without throwing for high-rank mixed input', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(_mixed()));
      await tester.pump();

      expect(find.byType(VitalityRadar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reserves the requested square size', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(_mixed(), size: 240));
      await tester.pump();

      final size = tester.getSize(find.byType(VitalityRadar));
      expect(size.width, 240);
      expect(size.height, 240);
    });

    testWidgets('asserts when entry count is not 6', (tester) async {
      // Disable assertion error to flow it through to the test framework.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(<BodyPartSheetEntry>[]));
      // The build assertion fires synchronously — captured via takeException.
      expect(tester.takeException(), isAssertionError);
    });
  });
}
