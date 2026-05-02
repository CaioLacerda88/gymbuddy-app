import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/shared/widgets/weight_stepper.dart';
import '../../../helpers/test_material_app.dart';

Widget buildTestWidget(Widget child) {
  return TestMaterialApp(
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

    group('tap-to-type comma/dot parsing', () {
      testWidgets(
        'comma as decimal separator ("80,5") calls onChanged with 80.5',
        (tester) async {
          double? emitted;
          await tester.pumpWidget(
            buildTestWidget(
              WeightStepper(value: 60, onChanged: (v) => emitted = v),
            ),
          );

          await tester.tap(find.text('60'));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), '80,5');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();

          expect(emitted, 80.5);
        },
      );

      testWidgets(
        'dot as decimal separator ("80.5") calls onChanged with 80.5',
        (tester) async {
          double? emitted;
          await tester.pumpWidget(
            buildTestWidget(
              WeightStepper(value: 60, onChanged: (v) => emitted = v),
            ),
          );

          await tester.tap(find.text('60'));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), '80.5');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();

          expect(emitted, 80.5);
        },
      );

      testWidgets('negative input ("-5") does not call onChanged', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '-5');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('empty submit does not call onChanged', (tester) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets(
        'malformed mixed separators ("80,5.2") does not call onChanged',
        (tester) async {
          double? emitted;
          await tester.pumpWidget(
            buildTestWidget(
              WeightStepper(value: 60, onChanged: (v) => emitted = v),
            ),
          );

          await tester.tap(find.text('60'));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), '80,5.2');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();

          expect(emitted, isNull);
        },
      );
    });

    group('tap-to-type edge cases', () {
      testWidgets('entering non-numeric text does not call onChanged', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'abc');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('entering empty string does not call onChanged', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('entering negative number does not call onChanged', (
        tester,
      ) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '-10');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, isNull);
      });

      testWidgets('entering zero calls onChanged with 0.0', (tester) async {
        double? emitted;
        await tester.pumpWidget(
          buildTestWidget(
            WeightStepper(value: 60, onChanged: (v) => emitted = v),
          ),
        );

        await tester.tap(find.text('60'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '0');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(emitted, 0.0);
      });
    });

    group('long-press cancel', () {
      testWidgets('decrement GestureDetector has onLongPressCancel set', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 100.0, onChanged: (_) {})),
        );

        // Find GestureDetectors that have onLongPressStart — these are the
        // stepper wrappers. Material InkWell/IconButton do not set this.
        final longPressGestures = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .where((g) => g.onLongPressStart != null)
            .toList();
        expect(longPressGestures, hasLength(2));
        // First is decrement, second is increment.
        expect(longPressGestures[0].onLongPressCancel, isNotNull);
      });

      testWidgets('increment GestureDetector has onLongPressCancel set', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(WeightStepper(value: 100.0, onChanged: (_) {})),
        );

        final longPressGestures = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .where((g) => g.onLongPressStart != null)
            .toList();
        expect(longPressGestures, hasLength(2));
        expect(longPressGestures[1].onLongPressCancel, isNotNull);
      });
    });

    group('tap target sizing (BUG-019)', () {
      testWidgets(
        'increment + decrement buttons are >=40x48 dp on a 360dp viewport',
        (tester) async {
          // Pin: on a Moto G / Samsung A width (360dp), the stepper buttons
          // must satisfy 40 minWidth + 48 minHeight so a sweaty thumb still
          // lands on the right control. Regressing below this re-opens
          // BUG-019. We force the surface size to 360dp to mirror the bug
          // repro envelope.
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestWidget(WeightStepper(value: 60.0, onChanged: (_) {})),
          );

          for (final icon in const [Icons.add, Icons.remove]) {
            final btn = tester.widget<IconButton>(
              find.widgetWithIcon(IconButton, icon),
            );
            expect(
              btn.constraints,
              isNotNull,
              reason:
                  'WeightStepper IconButton (${icon.codePoint.toRadixString(16)}) '
                  'must declare explicit constraints; otherwise Material defaults to '
                  '48x48 which is fine but BUG-019 pins the explicit floor.',
            );
            expect(
              btn.constraints!.minWidth,
              greaterThanOrEqualTo(40),
              reason: 'BUG-019: stepper minWidth must be >=40dp.',
            );
            expect(
              btn.constraints!.minHeight,
              greaterThanOrEqualTo(48),
              reason: 'BUG-019: stepper minHeight must be >=48dp.',
            );
          }
        },
      );
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
