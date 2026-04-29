/// Widget tests for [VitalityTrendChart] — Phase 18d.2.
///
/// The chart is six lines on a fixed 0..100 Y-axis. Five render as a single
/// ghost color (`textDim` 30% opacity, 1sp), the **selected** body part
/// renders vivid (its `bodyPartColor`, 2.5sp) with a terminal dot at the
/// right edge.
///
/// **Visual locks under test:**
///   * Six [LineChartBarData] entries — one per [activeBodyParts] body part.
///   * Selected line uses `bodyPartColor[selectedBodyPart]`; the five others
///     share the ghost color.
///   * `LineTouchData(enabled: false)` — touch is structurally off.
///   * No grid lines — `gridData.show == false`.
///   * No chart frame — `borderData.show == false`.
///   * Y-axis fixed 0..100; X-axis labels are hybrid per the spec.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/rpg/domain/vitality_state_mapper.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/stats_deep_dive_state.dart';
import 'package:repsaga/features/rpg/ui/widgets/vitality_trend_chart.dart';

import '../../../../helpers/test_material_app.dart';

/// Build a synthetic 90-day daily trace that linearly grows from 0 → 0.8.
List<TrendPoint> _ramp({
  required DateTime start,
  required int days,
  double end = 0.8,
}) {
  return [
    for (var i = 0; i < days; i++)
      TrendPoint(
        date: start.add(Duration(days: i)),
        pct: end * (i / (days - 1)),
      ),
  ];
}

Map<BodyPart, List<TrendPoint>> _allRamps({
  required DateTime start,
  required int days,
}) {
  return {
    for (final bp in activeBodyParts) bp: _ramp(start: start, days: days),
  };
}

Widget _wrap({
  required Map<BodyPart, List<TrendPoint>> trendByBodyPart,
  required BodyPart selected,
  required DateTime windowStart,
  required DateTime windowEnd,
  required bool useNarrowWindow,
}) {
  return TestMaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: SizedBox(
          // The chart needs a finite width for its LayoutBuilder; 360 is the
          // mid-point of common phone viewports.
          width: 360,
          child: VitalityTrendChart(
            trendByBodyPart: trendByBodyPart,
            selectedBodyPart: selected,
            windowStart: windowStart,
            windowEnd: windowEnd,
            useNarrowWindow: useNarrowWindow,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VitalityTrendChart', () {
    final today = DateTime.utc(2026, 4, 30);
    final windowStart = today.subtract(const Duration(days: 90));

    testWidgets('renders six LineChartBarData — one per active body part', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          trendByBodyPart: _allRamps(start: windowStart, days: 91),
          selected: BodyPart.chest,
          windowStart: windowStart,
          windowEnd: today,
          useNarrowWindow: false,
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.length, activeBodyParts.length);
    });

    testWidgets(
      'selected body part renders in its bodyPartColor + 2.5sp; others share ghost color + 1sp',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            trendByBodyPart: _allRamps(start: windowStart, days: 91),
            selected: BodyPart.legs,
            windowStart: windowStart,
            windowEnd: today,
            useNarrowWindow: false,
          ),
        );
        await tester.pump();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final selectedColor = VitalityStateMapper.bodyPartColor[BodyPart.legs];
        final selectedBars = chart.data.lineBarsData
            .where((b) => b.color == selectedColor)
            .toList();
        expect(selectedBars.length, 1);
        expect(selectedBars.single.barWidth, 2.5);

        // Ghost lines: every non-selected bar shares the same ghost color
        // and 1sp stroke. We don't lock the alpha-channel exact value so a
        // future palette tweak doesn't break this test, but we do lock that
        // the color is _derived from_ AppColors.textDim with reduced alpha.
        final ghostBars = chart.data.lineBarsData
            .where((b) => b.color != selectedColor)
            .toList();
        expect(ghostBars.length, activeBodyParts.length - 1);
        for (final b in ghostBars) {
          expect(b.barWidth, 1.0);
          // The ghost color is textDim with reduced alpha — we assert the
          // RGB channels match textDim and the alpha is below full.
          expect(b.color, isNotNull);
          expect(
            (b.color!.r * 255).round(),
            (AppColors.textDim.r * 255).round(),
          );
          expect(
            (b.color!.g * 255).round(),
            (AppColors.textDim.g * 255).round(),
          );
          expect(
            (b.color!.b * 255).round(),
            (AppColors.textDim.b * 255).round(),
          );
          expect(b.color!.a, lessThan(1.0));
        }
      },
    );

    testWidgets('grid + border + touch are all disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          trendByBodyPart: _allRamps(start: windowStart, days: 91),
          selected: BodyPart.chest,
          windowStart: windowStart,
          windowEnd: today,
          useNarrowWindow: false,
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.gridData.show, isFalse);
      expect(chart.data.borderData.show, isFalse);
      expect(chart.data.lineTouchData.enabled, isFalse);
    });

    testWidgets('Y-axis is locked 0..100', (tester) async {
      await tester.pumpWidget(
        _wrap(
          trendByBodyPart: _allRamps(start: windowStart, days: 91),
          selected: BodyPart.chest,
          windowStart: windowStart,
          windowEnd: today,
          useNarrowWindow: false,
        ),
      );
      await tester.pump();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.minY, 0);
      expect(chart.data.maxY, 100);
    });

    testWidgets('X-axis labels show "90 days ago" + "Today" in 90-day mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          trendByBodyPart: _allRamps(start: windowStart, days: 91),
          selected: BodyPart.chest,
          windowStart: windowStart,
          windowEnd: today,
          useNarrowWindow: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('90 days ago'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('X-axis labels show "<n> days ago" + "Today" in narrow mode', (
      tester,
    ) async {
      // 12 days of activity → narrow window from 12 days ago → today.
      final narrowStart = today.subtract(const Duration(days: 12));
      await tester.pumpWidget(
        _wrap(
          trendByBodyPart: _allRamps(start: narrowStart, days: 13),
          selected: BodyPart.chest,
          windowStart: narrowStart,
          windowEnd: today,
          useNarrowWindow: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12 days ago'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets(
      'X-axis singular "1 day ago" pluralizes correctly (boundary case)',
      (tester) async {
        final yesterday = today.subtract(const Duration(days: 1));
        await tester.pumpWidget(
          _wrap(
            trendByBodyPart: {BodyPart.chest: _ramp(start: yesterday, days: 2)},
            selected: BodyPart.chest,
            windowStart: yesterday,
            windowEnd: today,
            useNarrowWindow: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 day ago'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
      },
    );

    testWidgets(
      'changing selectedBodyPart re-paints with the new vivid color',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            trendByBodyPart: _allRamps(start: windowStart, days: 91),
            selected: BodyPart.chest,
            windowStart: windowStart,
            windowEnd: today,
            useNarrowWindow: false,
          ),
        );
        await tester.pump();

        final firstChart = tester.widget<LineChart>(find.byType(LineChart));
        final chestVivid = firstChart.data.lineBarsData
            .where(
              (b) =>
                  b.color == VitalityStateMapper.bodyPartColor[BodyPart.chest],
            )
            .length;
        expect(chestVivid, 1);

        // Re-pump with a different selection — the chart should now have one
        // bar in legs' bodyPartColor (and zero in chest's).
        await tester.pumpWidget(
          _wrap(
            trendByBodyPart: _allRamps(start: windowStart, days: 91),
            selected: BodyPart.legs,
            windowStart: windowStart,
            windowEnd: today,
            useNarrowWindow: false,
          ),
        );
        await tester.pumpAndSettle();

        final secondChart = tester.widget<LineChart>(find.byType(LineChart));
        final legsVivid = secondChart.data.lineBarsData
            .where(
              (b) =>
                  b.color == VitalityStateMapper.bodyPartColor[BodyPart.legs],
            )
            .length;
        expect(legsVivid, 1);
        final chestStillVivid = secondChart.data.lineBarsData
            .where(
              (b) =>
                  b.color == VitalityStateMapper.bodyPartColor[BodyPart.chest],
            )
            .length;
        expect(chestStillVivid, 0);
      },
    );

    testWidgets(
      'body part with empty trace renders a flat zero line (no crash)',
      (tester) async {
        // Chest selected but empty (user has never trained chest in window).
        await tester.pumpWidget(
          _wrap(
            trendByBodyPart: const {BodyPart.chest: <TrendPoint>[]},
            selected: BodyPart.chest,
            windowStart: windowStart,
            windowEnd: today,
            useNarrowWindow: false,
          ),
        );
        await tester.pump();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        // Six bars regardless — every active body part has a flat-zero
        // baseline when its data is missing or empty.
        expect(chart.data.lineBarsData.length, activeBodyParts.length);
        // No exception thrown.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('exposes vitality-trend-chart Semantics identifier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          trendByBodyPart: _allRamps(start: windowStart, days: 91),
          selected: BodyPart.chest,
          windowStart: windowStart,
          windowEnd: today,
          useNarrowWindow: false,
        ),
      );
      await tester.pump();

      // E2E selectors locate this widget via its Semantics identifier; we
      // assert the widget tree carries one Semantics node with the
      // contracted identifier so the E2E layer (Playwright) can latch onto
      // it via flt-semantics-identifier.
      final semantics = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(VitalityTrendChart),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => s.properties.identifier == 'vitality-trend-chart')
          .toList();
      expect(semantics.length, 1);
    });
  });
}
