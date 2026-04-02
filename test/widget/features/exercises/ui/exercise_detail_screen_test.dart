import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/data/exercise_repository.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/exercises/providers/exercise_providers.dart';
import 'package:gymbuddy_app/features/exercises/ui/exercise_detail_screen.dart';
import 'package:gymbuddy_app/shared/widgets/exercise_image.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/test_factories.dart';

class MockExerciseRepository extends Mock implements ExerciseRepository {}

/// Fake HTTP overrides to prevent real network calls from CachedNetworkImage.
class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  late MockExerciseRepository mockRepo;
  late HttpOverrides? originalOverrides;

  setUp(() {
    mockRepo = MockExerciseRepository();
    originalOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = originalOverrides;
  });

  Widget buildTestWidget({required String exerciseId}) {
    return ProviderScope(
      overrides: [
        exerciseRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ExerciseDetailScreen(exerciseId: exerciseId),
      ),
    );
  }

  /// Pumps widget and waits for the FutureBuilder to resolve.
  /// Uses pump() instead of pumpAndSettle() because CachedNetworkImage's
  /// placeholder animation (LinearProgressIndicator) never settles in tests.
  Future<void> pumpAndResolve(WidgetTester tester) async {
    await tester.pump(); // Schedule microtask
    await tester.pump(); // Resolve future
    await tester.pump(); // Build with data
  }

  group('ExerciseDetailScreen image section', () {
    testWidgets(
      'shows image row when both imageStartUrl and imageEndUrl are present',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            imageStartUrl: 'https://example.com/start.jpg',
            imageEndUrl: 'https://example.com/end.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
        expect(find.byType(ExerciseImage), findsNWidgets(2));
      },
    );

    testWidgets(
      'shows only start image when imageEndUrl is null',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            imageStartUrl: 'https://example.com/start.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('End'), findsNothing);
        expect(find.byType(ExerciseImage), findsOneWidget);
      },
    );

    testWidgets(
      'shows only end image when imageStartUrl is null',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            imageEndUrl: 'https://example.com/end.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        expect(find.text('Start'), findsNothing);
        expect(find.text('End'), findsOneWidget);
        expect(find.byType(ExerciseImage), findsOneWidget);
      },
    );

    testWidgets(
      'image section collapses entirely when both URLs are null',
      (tester) async {
        final exercise = Exercise.fromJson(TestExerciseFactory.create());
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await tester.pumpAndSettle();

        expect(find.text('Start'), findsNothing);
        expect(find.text('End'), findsNothing);
        expect(find.byType(ExerciseImage), findsNothing);
      },
    );

    testWidgets(
      'semantics labels are correct for start and end positions',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            name: 'Barbell Curl',
            imageStartUrl: 'https://example.com/start.jpg',
            imageEndUrl: 'https://example.com/end.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        // Verify semantics nodes with image labels exist
        expect(
          find.bySemanticsLabel('Barbell Curl start position'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Barbell Curl end position'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping an image opens full-screen dialog',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            imageStartUrl: 'https://example.com/start.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        // Find the GestureDetector wrapping the ExerciseImage and tap it
        final gestureFinder = find.ancestor(
          of: find.byType(ExerciseImage),
          matching: find.byType(GestureDetector),
        );
        expect(gestureFinder, findsOneWidget);

        await tester.tap(gestureFinder.first);
        await tester.pump(); // Trigger dialog
        await tester.pump(); // Animate dialog

        // A dialog should be open -- there should now be a second Scaffold
        // (the full-screen dialog uses a Scaffold with scrim background)
        expect(find.byType(Scaffold), findsNWidgets(2));
      },
    );

    testWidgets(
      'full-screen dialog dismisses on tap',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            imageStartUrl: 'https://example.com/start.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        // Open dialog
        final gestureFinder = find.ancestor(
          of: find.byType(ExerciseImage),
          matching: find.byType(GestureDetector),
        );
        await tester.tap(gestureFinder.first);
        await tester.pump();
        await tester.pump();

        // Verify dialog is open (2 Scaffolds)
        expect(find.byType(Scaffold), findsNWidgets(2));

        // The dialog's outer GestureDetector should dismiss on tap.
        // Find the GestureDetector that wraps the dialog Scaffold.
        final dialogGesture = find.ancestor(
          of: find.byType(Scaffold).last,
          matching: find.byType(GestureDetector),
        );
        await tester.tap(dialogGesture.last);
        // Use pump instead of pumpAndSettle -- dialog also has CachedNetworkImage
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dialog should be dismissed (back to 1 Scaffold)
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'shows loading indicator while exercise is being fetched',
      (tester) async {
        // Use a Completer that never completes to simulate a pending load
        final completer = Completer<Exercise>();
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the future to avoid pending timer warnings
        completer.complete(Exercise.fromJson(TestExerciseFactory.create()));
        await tester.pump();
      },
    );

    testWidgets(
      'shows error message when exercise fails to load',
      (tester) async {
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => throw Exception('Network error'));

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await tester.pumpAndSettle();

        expect(find.text('Failed to load exercise'), findsOneWidget);
      },
    );

    testWidgets(
      'both CachedNetworkImage widgets receive the correct URLs',
      (tester) async {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            imageStartUrl: 'https://cdn.example.com/chest/bench-start.jpg',
            imageEndUrl: 'https://cdn.example.com/chest/bench-end.jpg',
          ),
        );
        when(() => mockRepo.getExerciseById('exercise-001'))
            .thenAnswer((_) async => exercise);

        await tester.pumpWidget(buildTestWidget(exerciseId: 'exercise-001'));
        await pumpAndResolve(tester);

        final cachedImages =
            tester.widgetList<CachedNetworkImage>(
              find.byType(CachedNetworkImage),
            ).toList();
        expect(cachedImages.length, 2);

        final urls = cachedImages.map((img) => img.imageUrl).toSet();
        expect(urls, contains('https://cdn.example.com/chest/bench-start.jpg'));
        expect(urls, contains('https://cdn.example.com/chest/bench-end.jpg'));
      },
    );
  });
}
