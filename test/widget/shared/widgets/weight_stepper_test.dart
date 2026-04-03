import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/shared/widgets/weight_stepper.dart';

Widget buildTestWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('WeightStepper', () {
    group('value display', () {
      testWidgets('displays integer weight without decimal point', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 100, onChanged: (_) {})),
        );

        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('displays fractional weight with one decimal place', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 102.5, onChanged: (_) {})),
        );

        expect(find.text('102.5'), findsOneWidget);
      });

      testWidgets('displays zero as integer "0"', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 0, onChanged: (_) {})),
        );

        expect(find.text('0'), findsOneWidget);
      });
    });

    group('increment button', () {
      testWidgets('calls onChanged with value + increment on tap', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(
              value: 60.0,
              increment: 2.5,
              onChanged: (v) => emitted = v,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.add));

        expect(emitted, 62.5);
      });

      testWidgets('increment button is always enabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 0, onChanged: (_) {})),
        );

        final addButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.add),
        );
        expect(addButton.onPressed, isNotNull);
      });
    });

    group('decrement button', () {
      testWidgets('calls onChanged with value - increment on tap', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(
              value: 60.0,
              increment: 2.5,
              onChanged: (v) => emitted = v,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.remove));

        expect(emitted, 57.5);
      });

      testWidgets('minus button is disabled when value equals increment', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 2.5, increment: 2.5, onChanged: (_) {}),
          ),
        );

        // value >= increment so button should still be enabled (2.5 >= 2.5).
        final removeButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove),
        );
        expect(removeButton.onPressed, isNotNull);
      });

      testWidgets(
        'minus button is disabled when value is less than increment',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              WeightStepper(value: 0, increment: 2.5, onChanged: (_) {}),
            ),
          );

          final removeButton = tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove),
          );
          expect(removeButton.onPressed, isNull);
        },
      );

      testWidgets('decrement does not allow value to go below 0', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(
              value: 0,
              increment: 2.5,
              onChanged: (v) => emitted = v,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.remove));

        // onChanged must not fire when the button is disabled.
        expect(emitted, isNull);
      });
    });

    group('tap-to-type', () {
      testWidgets('tapping center number opens input dialog', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 60, onChanged: (_) {})),
        );

        // Tap the center number text.
        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        expect(find.text('Enter weight'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('submitting valid value calls onChanged', (tester) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        // Clear and type new value.
        await tester.enterText(find.byType(TextField), '85.5');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, 85.5);
      });

      testWidgets('cancelling dialog does not call onChanged', (tester) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });
    });

    group('custom increment', () {
      testWidgets('uses default increment of 2.5 when not specified', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 10.0, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.byIcon(Icons.add));

        expect(emitted, 12.5);
      });

      testWidgets('respects custom increment value', (tester) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(
              value: 20.0,
              increment: 5.0,
              onChanged: (v) => emitted = v,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.add));

        expect(emitted, 25.0);
      });
    });
  });
}
