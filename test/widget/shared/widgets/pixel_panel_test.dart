import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/shared/widgets/pixel_panel.dart';

/// Finds the two nested `DecoratedBox`es that render the panel's double
/// border, from outermost to innermost.
List<BoxDecoration> _nestedDecorations(WidgetTester tester) {
  final boxes = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      // The `Material` widget injected by `MaterialApp` introduces a
      // `DecoratedBox` of its own; we only care about decorations that carry
      // a `Border` (that's what makes our panel a panel).
      .map((b) => b.decoration)
      .whereType<BoxDecoration>()
      .where((d) => d.border != null)
      .toList();
  return boxes;
}

void main() {
  group('PixelPanel', () {
    testWidgets(
      'renders a 1-px black outer border wrapping a 1-px arcanePurple inner border',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: PixelPanel(
                child: Text('x', textDirection: TextDirection.ltr),
              ),
            ),
          ),
        );

        final decorations = _nestedDecorations(tester);
        expect(
          decorations.length,
          greaterThanOrEqualTo(2),
          reason: 'PixelPanel must render two border layers.',
        );

        final outer = decorations[0];
        final inner = decorations[1];

        final outerSide = outer.border!.top;
        final innerSide = inner.border!.top;

        // Outer = 1-px pure black.
        expect(outerSide.width, 1);
        expect(outerSide.color, Colors.black);

        // Inner = 1-px arcanePurple.
        expect(innerSide.width, 1);
        expect(innerSide.color, AppColors.arcanePurple);
      },
    );

    testWidgets('defaults to duskPurple fill', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PixelPanel(
              child: Text('x', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      final decorations = _nestedDecorations(tester);
      // Fill lives on the inner decoration.
      expect(decorations[1].color, AppColors.duskPurple);
    });

    testWidgets('renders deepVoid fill when requested', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PixelPanel(
              fill: PixelPanelFill.deepVoid,
              child: Text('x', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      final decorations = _nestedDecorations(tester);
      expect(decorations[1].color, AppColors.deepVoid);
    });

    testWidgets('renders child content inside the panel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PixelPanel(
              child: Text('hello', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('applies default 16-pt padding around child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PixelPanel(
              child: Text('padded', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      // The Padding widget wrapping the child carries the padding value.
      final padding = tester.widget<Padding>(find.byType(Padding).last);
      expect(padding.padding, const EdgeInsets.all(16));
    });

    testWidgets('forwards custom padding to the child Padding widget', (
      tester,
    ) async {
      const customPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PixelPanel(
              padding: customPadding,
              child: Text('custom', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).last);
      expect(padding.padding, customPadding);
    });
  });
}
