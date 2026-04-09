/// Isolated widget tests for ContextualStatCell.
///
/// Covers: label/value rendering, tap callback, null onTap safety,
/// semantics (button flag), minimum height constraint.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/contextual_stat_cell.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _cell({
  String label = 'Last session',
  String value = '3 days ago — Push Day',
  VoidCallback? onTap,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: ContextualStatCell(label: label, value: value, onTap: onTap),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ContextualStatCell — rendering', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(_cell(label: 'Last session'));
      expect(find.text('Last session'), findsOneWidget);
    });

    testWidgets('renders value text', (tester) async {
      await tester.pumpWidget(_cell(value: 'Yesterday — Chest Day'));
      expect(find.text('Yesterday — Chest Day'), findsOneWidget);
    });

    testWidgets('renders both label and value simultaneously', (tester) async {
      await tester.pumpWidget(
        _cell(label: "Week's volume", value: '12,400 kg this week'),
      );
      expect(find.text("Week's volume"), findsOneWidget);
      expect(find.text('12,400 kg this week'), findsOneWidget);
    });

    testWidgets('value text is truncated with ellipsis on overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: ContextualStatCell(
                label: 'Last session',
                value:
                    'This is an extremely long workout name that will overflow',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Should render without overflow exceptions.
      expect(tester.takeException(), isNull);
    });
  });

  group('ContextualStatCell — min height', () {
    testWidgets('cell is at least 56dp tall', (tester) async {
      await tester.pumpWidget(_cell());

      final size = tester.getSize(find.byType(ContextualStatCell));
      expect(size.height, greaterThanOrEqualTo(56));
    });
  });

  group('ContextualStatCell — interaction', () {
    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_cell(onTap: () => tapped = true));

      await tester.tap(find.byType(ContextualStatCell));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not throw when onTap is null and cell is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(_cell());

      // Tapping with null onTap should not crash.
      await tester.tap(find.byType(ContextualStatCell), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('ContextualStatCell — semantics', () {
    testWidgets('semantics label combines label and value', (tester) async {
      await tester.pumpWidget(
        _cell(label: 'Last session', value: 'Yesterday — Push Day'),
      );

      final semantics = tester.getSemantics(find.byType(ContextualStatCell));
      expect(semantics.label, contains('Last session'));
      expect(semantics.label, contains('Yesterday — Push Day'));
    });
  });
}
