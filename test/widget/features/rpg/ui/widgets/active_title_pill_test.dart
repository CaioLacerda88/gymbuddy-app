/// BUG-024: long pt-BR titles ("Forjado em Ferro", "Acima do Cinturão",
/// custom titles in a future phase) used to push the pill past the safe
/// area or clip horizontally. The widget now caps width at 220dp and
/// ellipsizes overflow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/ui/widgets/active_title_pill.dart';

import '../../../../../helpers/test_material_app.dart';

void main() {
  group('ActiveTitlePill', () {
    testWidgets('renders SizedBox.shrink when title is null', (tester) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(body: ActiveTitlePill(title: null)),
        ),
      );

      // No text → no Container with the violet border. The pill should
      // collapse to nothing and contribute no visible glyphs.
      expect(find.byType(Container), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders SizedBox.shrink when title is empty string', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(body: ActiveTitlePill(title: '')),
        ),
      );

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders the title text when non-empty', (tester) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(body: ActiveTitlePill(title: 'Iron-Bound')),
        ),
      );

      expect(find.text('Iron-Bound'), findsOneWidget);
    });

    testWidgets('caps width at 220dp via ConstrainedBox (BUG-024)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(body: ActiveTitlePill(title: 'Iron-Bound')),
        ),
      );

      final constrained = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.text('Iron-Bound'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(constrained.constraints.maxWidth, 220);
    });

    testWidgets('long pt-BR titles are ellipsized to one line (BUG-024)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          // Pathological string longer than the 220dp budget at the pill's
          // labelMedium type size. The widget must clamp it via
          // overflow=ellipsis + maxLines=1 — never word-wrap into multiple
          // lines, which would push surrounding chrome around.
          home: Scaffold(
            body: ActiveTitlePill(
              title: 'Forjado em Ferro do Reino Subterrâneo Eterno',
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.textContaining('Forjado'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      'rendered pill width never exceeds the 220dp ceiling (BUG-024)',
      (tester) async {
        // Use [Align] so the parent passes loose constraints — without
        // that, a [SizedBox(width: 600)] passes a tight width down which
        // would force any ConstrainedBox inside the pill to size to 600
        // regardless of its own `maxWidth` (tightness wins). Align gives
        // the pill a 600dp ceiling with the freedom to size down.
        await tester.pumpWidget(
          const TestMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ActiveTitlePill(
                    title: 'Forjado em Ferro do Reino Subterrâneo Eterno',
                  ),
                ),
              ),
            ),
          ),
        );

        // Target the ConstrainedBox that sits directly under
        // [ActiveTitlePill] — the Scaffold renders other ConstrainedBoxes
        // upstream that have wider constraints. Using
        // `find.descendant(of: widget)` keeps the assertion scoped to the
        // pill's own subtree.
        final constrainedFinder = find.descendant(
          of: find.byType(ActiveTitlePill),
          matching: find.byType(ConstrainedBox),
        );
        final size = tester.getSize(constrainedFinder.first);
        expect(size.width, lessThanOrEqualTo(220));
      },
    );
  });
}
