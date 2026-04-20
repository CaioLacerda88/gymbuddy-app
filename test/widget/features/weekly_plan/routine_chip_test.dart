/// Widget tests for RoutineChip — three visual states.
///
/// Done: green background + checkmark, no name text visible as primary content.
/// Next: solid green Material, tappable, fires onTap callback.
/// Remaining: ghosted appearance, sequence number visible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/weekly_plan/ui/widgets/routine_chip.dart';
import '../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _chip({
  required RoutineChipState state,
  int sequence = 1,
  String name = 'Push Day',
  VoidCallback? onTap,
}) {
  return TestMaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: RoutineChip(
          sequenceNumber: sequence,
          routineName: name,
          chipState: state,
          onTap: onTap,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RoutineChip — done state', () {
    testWidgets('renders a checkmark icon', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.done));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('checkmark icon is green', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.done));

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color, const Color(0xFF00E676));
    });

    testWidgets('Container has a green-tinted background', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.done));

      // Done chip is a Container with a decoration — find it by verifying
      // a BoxDecoration with a green border exists.
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .toList();

      final hasGreenBorder = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          final border = decoration.border;
          if (border is Border) {
            return border.top.color == const Color(0xFF00E676);
          }
        }
        return false;
      });

      expect(hasGreenBorder, isTrue);
    });

    testWidgets('does not render a routine name Text', (tester) async {
      await tester.pumpWidget(
        _chip(state: RoutineChipState.done, name: 'Leg Day'),
      );

      // The done chip only shows a checkmark — the name should not be present.
      expect(find.text('Leg Day'), findsNothing);
    });
  });

  group('RoutineChip — next state', () {
    testWidgets('uses a solid green Material background', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.next));

      final materials = tester.widgetList<Material>(find.byType(Material));
      final hasGreenMaterial = materials.any(
        (m) => m.color == const Color(0xFF00E676),
      );
      expect(hasGreenMaterial, isTrue);
    });

    testWidgets('shows the routine name', (tester) async {
      await tester.pumpWidget(
        _chip(state: RoutineChipState.next, name: 'Pull Day'),
      );

      expect(find.text('Pull Day'), findsOneWidget);
    });

    testWidgets('shows the sequence number', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.next, sequence: 2));

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _chip(state: RoutineChipState.next, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not crash when onTap is null', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.next));

      // Tapping with no onTap should not throw.
      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.pump();
    });

    testWidgets('chip height is 60dp (taller CTA per spec)', (tester) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.next));

      // Verify via rendered size — the chip must be at least 60dp tall.
      final size = tester.getSize(find.byType(RoutineChip));
      expect(size.height, greaterThanOrEqualTo(60));
    });

    testWidgets('shows exercise count as secondary line', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: RoutineChip(
                sequenceNumber: 1,
                routineName: 'Push Day',
                chipState: RoutineChipState.next,
                exerciseCount: 6,
              ),
            ),
          ),
        ),
      );

      expect(find.text('6 exercises'), findsOneWidget);
    });
  });

  group('RoutineChip — remaining state', () {
    testWidgets('shows the sequence number', (tester) async {
      await tester.pumpWidget(
        _chip(state: RoutineChipState.remaining, sequence: 3),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows the routine name at reduced opacity', (tester) async {
      await tester.pumpWidget(
        _chip(state: RoutineChipState.remaining, name: 'Leg Day'),
      );

      // Name is still visible in remaining state, just ghosted.
      expect(find.text('Leg Day'), findsOneWidget);

      // Text color should have reduced alpha (< 1.0 == 255).
      final nameText = tester.widget<Text>(find.text('Leg Day'));
      final alpha = nameText.style?.color?.a ?? 1.0;
      expect(alpha, lessThan(1.0));
    });

    testWidgets('remaining chip is tappable when onTap is provided', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: RoutineChip(
                sequenceNumber: 1,
                routineName: 'Leg Day',
                chipState: RoutineChipState.remaining,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Remaining chips now use InkWell so any uncompleted routine
      // can be started, not just the suggested-next one.
      await tester.tap(find.byType(RoutineChip));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('chip height is 48dp (standard, not CTA height)', (
      tester,
    ) async {
      await tester.pumpWidget(_chip(state: RoutineChipState.remaining));

      final size = tester.getSize(find.byType(RoutineChip));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('RoutineChip — general', () {
    testWidgets('renders without error for each state', (tester) async {
      for (final state in RoutineChipState.values) {
        await tester.pumpWidget(_chip(state: state));
        expect(find.byType(RoutineChip), findsOneWidget);
      }
    });

    testWidgets('long routine names do not overflow', (tester) async {
      const longName = 'This Is A Very Long Routine Name That Could Overflow';

      for (final state in RoutineChipState.values) {
        await tester.pumpWidget(
          TestMaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: RoutineChip(
                  sequenceNumber: 1,
                  routineName: longName,
                  chipState: state,
                ),
              ),
            ),
          ),
        );

        // Should render without overflow exception.
        expect(tester.takeException(), isNull);
      }
    });
  });
}
