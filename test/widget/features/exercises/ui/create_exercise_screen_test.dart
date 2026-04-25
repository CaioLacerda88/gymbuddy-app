import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:repsaga/core/l10n/locale_provider.dart';
import 'package:repsaga/l10n/app_localizations.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/exercises/data/exercise_repository.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/exercises/providers/exercise_providers.dart';
import 'package:repsaga/features/exercises/ui/create_exercise_screen.dart';
import '../../../../fixtures/test_factories.dart';
import '../../../../helpers/stub_locale_notifier.dart';
import '../../../../helpers/test_material_app.dart';

class _MockExerciseRepository extends Mock implements ExerciseRepository {}

void main() {
  // Register fallback values for mocktail `any()` matchers on enum types.
  setUpAll(() {
    registerFallbackValue(MuscleGroup.chest);
    registerFallbackValue(EquipmentType.barbell);
  });

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

    testWidgets('selectable cards render SvgPicture, not Material Icon', (
      tester,
    ) async {
      // Phase 17.0d migrated _SelectableCard.icon from IconData → String
      // (AppIcons SVG key). If someone reverts to IconData, the card stops
      // calling AppIcons.render and the SvgPicture count drops to zero —
      // this count assertion is the regression fence (both directions).
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final expected = MuscleGroup.values.length + EquipmentType.values.length;
      expect(
        find.byType(SvgPicture),
        findsNWidgets(expected),
        reason:
            'Each muscle group and equipment type card must render via '
            'AppIcons.render() → SvgPicture, not a Material Icon.',
      );
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

  group('CreateExerciseScreen Phase 15f locale plumbing', () {
    late _MockExerciseRepository mockRepo;

    /// Builds a test widget with GoRouter so that context.pop() in _submit
    /// does not throw "No GoRouter found in context".
    Widget buildWithRouter({required List<Override> overrides}) {
      // Mirrors the real app router: /exercises as parent, create as nested
      // child. initialLocation '/exercises/create' causes GoRouter to push both
      // routes into the stack so context.pop() in _submit returns to
      // /exercises without throwing "Nothing to pop".
      final router = GoRouter(
        initialLocation: '/exercises/create',
        routes: [
          GoRoute(
            path: '/exercises',
            builder: (context, state) =>
                const Scaffold(body: Text('Exercise List')),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateExerciseScreen(),
              ),
            ],
          ),
        ],
      );

      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    setUp(() {
      mockRepo = _MockExerciseRepository();
    });

    testWidgets(
      'calls createExercise with locale:pt when localeProvider is overridden to pt',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final createdExercise = Exercise.fromJson(
          TestExerciseFactory.create(
            id: 'exercise-new-pt',
            name: 'Meu Exercício',
            muscleGroup: 'chest',
            equipmentType: 'barbell',
            slug: 'meu_exercicio',
          ),
        );

        when(
          () => mockRepo.createExercise(
            locale: 'pt',
            name: any(named: 'name'),
            muscleGroup: any(named: 'muscleGroup'),
            equipmentType: any(named: 'equipmentType'),
            userId: any(named: 'userId'),
            description: any(named: 'description'),
            formTips: any(named: 'formTips'),
          ),
        ).thenAnswer((_) async => createdExercise);

        // Stub list provider so invalidation after create doesn't crash.
        when(
          () => mockRepo.getExercises(
            locale: any(named: 'locale'),
            userId: any(named: 'userId'),
            muscleGroup: any(named: 'muscleGroup'),
            equipmentType: any(named: 'equipmentType'),
          ),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(
          buildWithRouter(
            overrides: [
              exerciseRepositoryProvider.overrideWithValue(mockRepo),
              currentUserIdProvider.overrideWithValue('user-001'),
              localeProvider.overrideWith(
                () => StubLocaleNotifier(const Locale('pt')),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Select muscle group.
        await tester.tap(find.text('Chest'));
        await tester.pump();

        // Select equipment type.
        await tester.tap(find.text('Barbell'));
        await tester.pump();

        // Enter a valid name.
        await tester.enterText(find.byType(TextFormField), 'Meu Exercício');
        await tester.pump();

        // Submit the form. GoRouter's context.pop() is wired so it won't throw.
        await tester.tap(find.text('CREATE EXERCISE'));
        // Drain pending microtasks + frames so the async submit completes
        // (avoids the magic 100ms sleep — pumpAndSettle waits for actual idle).
        await tester.pumpAndSettle();

        // Verify createExercise was called with locale:'pt'.
        verify(
          () => mockRepo.createExercise(
            locale: 'pt',
            name: 'Meu Exercício',
            muscleGroup: MuscleGroup.chest,
            equipmentType: EquipmentType.barbell,
            userId: 'user-001',
            description: null,
            formTips: null,
          ),
        ).called(1);

        // Must NOT have been called with locale:'en'.
        verifyNever(
          () => mockRepo.createExercise(
            locale: 'en',
            name: any(named: 'name'),
            muscleGroup: any(named: 'muscleGroup'),
            equipmentType: any(named: 'equipmentType'),
            userId: any(named: 'userId'),
            description: any(named: 'description'),
            formTips: any(named: 'formTips'),
          ),
        );
      },
    );

    testWidgets(
      'calls createExercise with locale:en when localeProvider is overridden to en',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final createdExercise = Exercise.fromJson(
          TestExerciseFactory.create(
            id: 'exercise-new-en',
            name: 'My Exercise',
            muscleGroup: 'chest',
            equipmentType: 'barbell',
            slug: 'my_exercise',
          ),
        );

        when(
          () => mockRepo.createExercise(
            locale: 'en',
            name: any(named: 'name'),
            muscleGroup: any(named: 'muscleGroup'),
            equipmentType: any(named: 'equipmentType'),
            userId: any(named: 'userId'),
            description: any(named: 'description'),
            formTips: any(named: 'formTips'),
          ),
        ).thenAnswer((_) async => createdExercise);

        when(
          () => mockRepo.getExercises(
            locale: any(named: 'locale'),
            userId: any(named: 'userId'),
            muscleGroup: any(named: 'muscleGroup'),
            equipmentType: any(named: 'equipmentType'),
          ),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(
          buildWithRouter(
            overrides: [
              exerciseRepositoryProvider.overrideWithValue(mockRepo),
              currentUserIdProvider.overrideWithValue('user-001'),
              localeProvider.overrideWith(
                () => StubLocaleNotifier(const Locale('en')),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chest'));
        await tester.pump();
        await tester.tap(find.text('Barbell'));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField), 'My Exercise');
        await tester.pump();
        await tester.tap(find.text('CREATE EXERCISE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockRepo.createExercise(
            locale: 'en',
            name: 'My Exercise',
            muscleGroup: MuscleGroup.chest,
            equipmentType: EquipmentType.barbell,
            userId: 'user-001',
            description: null,
            formTips: null,
          ),
        ).called(1);
      },
    );
  });
}
