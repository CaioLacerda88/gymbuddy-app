import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/gradient_button.dart';

void main() {
  Widget buildButton({
    String label = 'SUBMIT',
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: GradientButton(
            label: label,
            onPressed: onPressed,
            isLoading: isLoading,
            icon: icon,
          ),
        ),
      ),
    );
  }

  group('GradientButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(buildButton(onPressed: () {}));

      expect(find.text('SUBMIT'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildButton(onPressed: () => tapped = true));

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('disables button when onPressed is null', (tester) async {
      await tester.pumpWidget(buildButton());

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows loading spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(buildButton(isLoading: true, onPressed: () {}));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The label text should not be rendered as a child widget.
      expect(find.text('SUBMIT'), findsNothing);
    });

    testWidgets('retains semantic label during loading state (BUG-002)', (
      tester,
    ) async {
      await tester.pumpWidget(buildButton(isLoading: true, onPressed: () {}));

      // The Semantics widget should still have the label.
      expect(find.bySemanticsLabel('SUBMIT'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(buildButton(icon: Icons.check, onPressed: () {}));

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('SUBMIT'), findsOneWidget);
    });

    testWidgets('does not render icon when loading', (tester) async {
      await tester.pumpWidget(
        buildButton(icon: Icons.check, isLoading: true, onPressed: () {}),
      );

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has gradient decoration when enabled', (tester) async {
      await tester.pumpWidget(buildButton(onPressed: () {}));

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNotNull);
    });

    testWidgets('has themed disabled background when disabled', (tester) async {
      await tester.pumpWidget(buildButton());

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNull);
      // Disabled background uses theme's onSurface at 12% opacity.
      final expectedColor = AppTheme.dark.colorScheme.onSurface.withValues(
        alpha: 0.12,
      );
      expect(decoration?.color, equals(expectedColor));
    });
  });
}
