import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';
import 'package:repsaga/features/workouts/providers/workout_providers.dart';
import 'package:repsaga/features/workouts/ui/widgets/resume_workout_banner.dart';
import 'package:repsaga/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake notifier helpers
// ---------------------------------------------------------------------------

/// A minimal [ActiveWorkoutNotifier] that starts with a fixed state.
/// All mutations are no-ops — we only need state observation in these tests.
class _FakeActiveWorkoutNotifier extends ActiveWorkoutNotifier {
  _FakeActiveWorkoutNotifier(this._initial);

  final ActiveWorkoutState? _initial;

  @override
  Future<ActiveWorkoutState?> build() async => _initial;
}

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

Workout _makeWorkout({String name = 'Test Workout'}) => Workout(
  id: 'workout-001',
  userId: 'user-001',
  name: name,
  startedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
  isActive: true,
  createdAt: DateTime.now().toUtc(),
);

ActiveWorkoutState _makeStateNoExercises({String name = 'Test Workout'}) =>
    ActiveWorkoutState(
      workout: _makeWorkout(name: name),
      exercises: const [],
    );

ActiveWorkoutState _makeStateWithExercises({String name = 'Test Workout'}) =>
    ActiveWorkoutState(
      workout: _makeWorkout(name: name),
      exercises: const [
        ActiveWorkoutExercise(
          workoutExercise: WorkoutExercise(
            id: 'we-001',
            workoutId: 'workout-001',
            exerciseId: 'exercise-001',
            order: 0,
          ),
          sets: [],
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget buildBanner(
  ActiveWorkoutState? activeState, {
  Duration elapsed = Duration.zero,
  GoRouter? router,
}) {
  final effectiveRouter =
      router ??
      GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: SingleChildScrollView(
                child: Column(children: [ResumeWorkoutBanner()]),
              ),
            ),
          ),
          GoRoute(
            path: '/workout/active',
            builder: (context, state) =>
                const Scaffold(body: Text('Active Workout')),
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      activeWorkoutProvider.overrideWith(
        () => _FakeActiveWorkoutNotifier(activeState),
      ),
      // Override elapsed timer so it doesn't start real periodic streams.
      elapsedTimerProvider.overrideWith(
        (ref, startedAt) => Stream.value(elapsed),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      routerConfig: effectiveRouter,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ResumeWorkoutBanner', () {
    group('renders nothing when', () {
      testWidgets('activeWorkoutProvider returns null', (tester) async {
        await tester.pumpWidget(buildBanner(null));
        await tester.pump(); // let async provider settle

        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byIcon(Icons.fitness_center), findsNothing);
      });

      testWidgets('active workout has zero exercises', (tester) async {
        await tester.pumpWidget(buildBanner(_makeStateNoExercises()));
        await tester.pump();

        expect(find.byIcon(Icons.fitness_center), findsNothing);
        expect(find.text('Test Workout'), findsNothing);
      });
    });

    group('renders banner when active workout has exercises', () {
      testWidgets('shows workout name', (tester) async {
        await tester.pumpWidget(
          buildBanner(_makeStateWithExercises(name: 'Push Day')),
        );
        await tester.pump();

        expect(find.text('Push Day'), findsOneWidget);
      });

      testWidgets('shows fitness_center icon', (tester) async {
        await tester.pumpWidget(buildBanner(_makeStateWithExercises()));
        await tester.pump();

        expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      });

      testWidgets('shows chevron_right icon', (tester) async {
        await tester.pumpWidget(buildBanner(_makeStateWithExercises()));
        await tester.pump();

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('shows elapsed time formatted as MM:SS', (tester) async {
        await tester.pumpWidget(
          buildBanner(
            _makeStateWithExercises(),
            elapsed: const Duration(minutes: 5, seconds: 30),
          ),
        );
        // Pump twice: first to build, second to resolve the StreamProvider.
        await tester.pump();
        await tester.pump();

        expect(find.text('05:30'), findsOneWidget);
      });

      testWidgets(
        'shows elapsed time formatted as H:MM:SS for durations >= 1 hour',
        (tester) async {
          await tester.pumpWidget(
            buildBanner(
              _makeStateWithExercises(),
              elapsed: const Duration(hours: 1, minutes: 2, seconds: 3),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text('1:02:03'), findsOneWidget);
        },
      );
    });

    group('tap behaviour', () {
      testWidgets('tapping banner navigates to /workout/active', (
        tester,
      ) async {
        await tester.pumpWidget(buildBanner(_makeStateWithExercises()));
        await tester.pump();

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Active Workout'), findsOneWidget);
      });
    });
  });
}
