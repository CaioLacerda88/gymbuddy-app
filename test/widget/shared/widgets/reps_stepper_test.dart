import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/shared/widgets/reps_stepper.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('RepsStepper', () {
    group('value display', () {
      testWidgets('displays rep count as integer', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 10, onChanged: (_) {})),
        );

        expect(find.text('10'), findsOneWidget);
      });

      testWidgets('displays zero', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 0, onChanged: (_) {})),
        );

        expect(find.text('0'), findsOneWidget);
      });
    });

    group('increment button', () {
      testWidgets('calls onChanged with value + 1 on tap', (tester) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 8, onChanged: (v) => emitted = v)),
        );

        await tester.tap(find.byIcon(Icons.add));

        expect(emitted, 9);
      });

      testWidgets('increment button is always enabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 0, onChanged: (_) {})),
        );

        final addButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.add),
        );
        expect(addButton.onPressed, isNotNull);
      });
    });

    group('decrement button', () {
      testWidgets('calls onChanged with value - 1 on tap', (tester) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 8, onChanged: (v) => emitted = v)),
        );

        await tester.tap(find.byIcon(Icons.remove));

        expect(emitted, 7);
      });

      testWidgets('minus button is disabled when value is 0', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 0, onChanged: (_) {})),
        );

        final removeButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove),
        );
        expect(removeButton.onPressed, isNull);
      });

      testWidgets('minus button is disabled when value equals increment', (
        tester,
      ) async {
        // default increment is 1; value 1 >= 1 so button should be enabled.
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 1, onChanged: (_) {})),
        );

        final removeButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove),
        );
        expect(removeButton.onPressed, isNotNull);
      });

      testWidgets('decrement does not fire when value is below increment', (
        tester,
      ) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 0, onChanged: (v) => emitted = v)),
        );

        await tester.tap(find.byIcon(Icons.remove));

        expect(emitted, isNull);
      });
    });

    group('tap-to-type', () {
      testWidgets('tapping center number opens input dialog', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 10, onChanged: (_) {})),
        );

        // Tap the center number text.
        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        expect(find.text('Enter reps'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('submitting valid value calls onChanged', (tester) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '15');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, 15);
      });

      testWidgets('cancelling dialog does not call onChanged', (tester) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });
    });

    group('tap-to-type edge cases', () {
      testWidgets('entering non-numeric text does not call onChanged', (
        tester,
      ) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'abc');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('entering empty string does not call onChanged', (
        tester,
      ) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('entering negative number does not call onChanged', (
        tester,
      ) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '-5');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('entering zero calls onChanged with 0', (tester) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '0');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, 0);
      });
    });

    group('custom increment', () {
      testWidgets('uses default increment of 1 when not specified', (
        tester,
      ) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(RepsStepper(value: 5, onChanged: (v) => emitted = v)),
        );

        await tester.tap(find.byIcon(Icons.add));

        expect(emitted, 6);
      });

      testWidgets('respects custom increment value', (tester) async {
        int? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            RepsStepper(value: 10, increment: 5, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.byIcon(Icons.add));

        expect(emitted, 15);
      });
    });
  });
}
