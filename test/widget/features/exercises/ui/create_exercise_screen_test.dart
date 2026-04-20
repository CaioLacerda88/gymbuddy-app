import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/exercises/ui/create_exercise_screen.dart';
import '../../../../helpers/test_material_app.dart';

void main() {
  Widget buildTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: TestMaterialApp(
        theme: AppTheme.dark,
        home: const CreateExerciseScreen(),
      ),
    );
  }

  group('CreateExerciseScreen', () {
    testWidgets('renders form fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Exercise Name'), findsOneWidget);
      expect(find.text('Muscle Group'), findsOneWidget);
      expect(find.text('Equipment Type'), findsOneWidget);
      expect(find.text('CREATE EXERCISE'), findsOneWidget);
    });

    testWidgets('renders muscle group selectable cards', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      for (final group in MuscleGroup.values) {
        expect(find.text(group.displayName), findsWidgets);
      }
    });

    testWidgets('renders equipment type selectable cards', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      for (final type in EquipmentType.values) {
        expect(find.text(type.displayName), findsWidgets);
      }
    });

    testWidgets('validates empty name', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());

      // Select muscle group and equipment to bypass that validation
      await tester.tap(find.text('Chest'));
      await tester.pump();
      await tester.tap(find.text('Barbell'));
      await tester.pump();

      // Submit with empty name
      await tester.tap(find.text('CREATE EXERCISE'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('validates short name', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());

      // Select muscle group and equipment
      await tester.tap(find.text('Chest'));
      await tester.pump();
      await tester.tap(find.text('Barbell'));
      await tester.pump();

      // Enter short name
      await tester.enterText(find.byType(TextFormField), 'A');

      await tester.tap(find.text('CREATE EXERCISE'));
      await tester.pump();

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('muscle group cards are selectable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap a muscle group card
      await tester.tap(find.text('Chest'));
      await tester.pump();

      // Verify selection via Semantics selected state
      final chestSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Muscle group: Chest' &&
              w.properties.selected == true,
        ),
      );
      expect(chestSemantics.properties.selected, isTrue);
    });

    testWidgets('equipment type cards are selectable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap an equipment card
      await tester.tap(find.text('Dumbbell'));
      await tester.pump();

      // Verify selection via Semantics selected state
      final dumbbellSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Equipment type: Dumbbell' &&
              w.properties.selected == true,
        ),
      );
      expect(dumbbellSemantics.properties.selected, isTrue);
    });

    testWidgets('clamps exercise name input to 80 characters', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());

      // Enter 90 chars — widget's maxLength=80 must clamp input.
      final overlong = 'x' * 90;
      await tester.enterText(find.byType(TextFormField), overlong);
      await tester.pump();

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text.length, 80);
    });

    testWidgets('shows snackbar when submitting without selections', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());

      // Enter a valid name but don't select muscle group or equipment
      await tester.enterText(find.byType(TextFormField), 'My Exercise');

      await tester.tap(find.text('CREATE EXERCISE'));
      await tester.pump();

      expect(
        find.text('Please select a muscle group and equipment type'),
        findsOneWidget,
      );
    });
  });
}
