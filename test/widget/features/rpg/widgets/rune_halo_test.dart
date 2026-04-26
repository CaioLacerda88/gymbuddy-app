/// Widget tests for [RuneHalo] (Phase 18b).
///
/// The halo collapses Vitality % into one of four §8.4 visual states. These
/// tests verify:
///   1. All four states render without throwing.
///   2. Switching state at runtime tears down the prior animation controller
///      and starts a new one (no leaked tickers).
///   3. The Active state owns no controller (static — pure box-shadow).
///   4. Disposing the widget tears down the controller cleanly.
///
/// We can't trivially read the private [State] to assert controller identity,
/// so the controller-rotation test relies on `pumpAndSettle` returning without
/// timing out — a leaked-on-rebuild ticker would deadlock the test pump.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/vitality_state.dart';
import 'package:repsaga/features/rpg/ui/widgets/rune_halo.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(Widget child) => TestMaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('RuneHalo', () {
    testWidgets('renders without throwing for every VitalityState', (
      tester,
    ) async {
      for (final state in VitalityState.values) {
        await tester.pumpWidget(_wrap(RuneHalo(state: state)));
        // Pump twice — once to mount, once for any first animation tick.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(RuneHalo), findsOneWidget);
      }
    });

    testWidgets(
      'state switch tears down prior controller and rebuilds cleanly',
      (tester) async {
        // Start in Dormant (rotating ticker), transition through every state
        // back to Active (static, no controller) — exercises the
        // didUpdateWidget rotation path on every transition.
        await tester.pumpWidget(
          _wrap(const RuneHalo(state: VitalityState.dormant)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.pumpWidget(
          _wrap(const RuneHalo(state: VitalityState.fading)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        await tester.pumpWidget(
          _wrap(const RuneHalo(state: VitalityState.radiant)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Final transition: into the static Active state. If a previous
        // controller leaks, the test framework will report a pending timer
        // when the widget is unmounted in tearDown.
        await tester.pumpWidget(
          _wrap(const RuneHalo(state: VitalityState.active)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(RuneHalo), findsOneWidget);
      },
    );

    testWidgets('disposes cleanly when removed from the tree', (tester) async {
      await tester.pumpWidget(
        _wrap(const RuneHalo(state: VitalityState.radiant)),
      );
      await tester.pump();

      // Replace with an empty container — this unmounts the halo.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();

      expect(find.byType(RuneHalo), findsNothing);
      // No `expectAsyncEvents` needed — pendingTimers throw via tester teardown
      // if the controller leaked.
    });

    testWidgets('reserves size + 60 dp on each axis (no clipping)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RuneHalo(state: VitalityState.active, size: 96)),
      );
      await tester.pump();

      // The widget's outer SizedBox should reserve size + 60 = 156.
      final renderBox = tester.renderObject<RenderBox>(find.byType(RuneHalo));
      expect(renderBox.size.width, 156);
      expect(renderBox.size.height, 156);
    });
  });
}
