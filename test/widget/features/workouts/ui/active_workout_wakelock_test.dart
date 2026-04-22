/// Widget tests for ActiveWorkoutScreen wakelock integration.
///
/// Verifies that [WakelockPlus.enable] is invoked when the active workout
/// screen mounts and [WakelockPlus.disable] when it unmounts. Uses the
/// `wakelockPlusPlatformInstance` override exposed by wakelock_plus (marked
/// @visibleForTesting) to swap in a fake platform interface that records
/// every toggle call.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/providers/pr_providers.dart';
import 'package:repsaga/features/profile/models/profile.dart';
import 'package:repsaga/features/profile/providers/profile_providers.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';
import 'package:repsaga/features/workouts/providers/workout_providers.dart';
import 'package:repsaga/features/workouts/ui/active_workout_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';
import '../../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Fake platform interface
// ---------------------------------------------------------------------------

/// Records every [toggle] call so tests can assert enable/disable invocations.
///
/// Implements [WakelockPlusPlatformInterface] via `implements` (normally
/// forbidden by the PlatformInterface token check) and sets [isMock] to true
/// to bypass the verification — this is the documented test backdoor.
class _FakeWakelockPlus implements WakelockPlusPlatformInterface {
  final List<bool> toggleCalls = [];
  bool _enabled = false;

  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {
    toggleCalls.add(enable);
    _enabled = enable;
  }

  @override
  Future<bool> get enabled async => _enabled;
}

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

final _testExercise = Exercise(
  id: 'exercise-001',
  name: 'Bench Press',
  muscleGroup: MuscleGroup.chest,
  equipmentType: EquipmentType.barbell,
  isDefault: true,
  createdAt: DateTime(2026),
);

final _testWorkout = Workout(
  id: 'workout-001',
  userId: 'user-001',
  name: 'Push Day',
  startedAt: DateTime.now().toUtc(),
  isActive: true,
  createdAt: DateTime.now().toUtc(),
);

ActiveWorkoutState _makeState() {
  return ActiveWorkoutState(
    workout: _testWorkout,
    exercises: [
      ActiveWorkoutExercise(
        workoutExercise: WorkoutExercise(
          id: 'we-001',
          workoutId: 'workout-001',
          exerciseId: 'exercise-001',
          order: 1,
          exercise: _testExercise,
        ),
        sets: [
          ExerciseSet(
            id: 'set-1',
            workoutExerciseId: 'we-001',
            setNumber: 1,
            reps: 10,
            weight: 60.0,
            isCompleted: false,
            setType: SetType.working,
            createdAt: DateTime.now().toUtc(),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Stubs (shared with other active_workout tests)
// ---------------------------------------------------------------------------

class _FixedActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  _FixedActiveWorkoutNotifier(this._state);
  final ActiveWorkoutState? _state;

  @override
  Future<ActiveWorkoutState?> build() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullRestTimerNotifier extends Notifier<RestTimerState?>
    implements RestTimerNotifier {
  @override
  RestTimerState? build() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KgProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async => const Profile(id: 'u1', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildWithState(ActiveWorkoutState state) {
  return ProviderScope(
    overrides: [
      activeWorkoutProvider.overrideWith(
        () => _FixedActiveWorkoutNotifier(state),
      ),
      restTimerProvider.overrideWith(() => _NullRestTimerNotifier()),
      profileProvider.overrideWith(() => _KgProfileNotifier()),
      exercisePRsProvider.overrideWith((ref, _) => Future.value([])),
      lastWorkoutSetsProvider.overrideWith((ref, _) => Future.value({})),
      elapsedTimerProvider.overrideWith(
        (ref, startedAt) => Stream.value(const Duration(minutes: 5)),
      ),
    ],
    child: TestMaterialApp(
      theme: AppTheme.dark,
      home: const ActiveWorkoutScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ActiveWorkoutScreen — wakelock lifecycle', () {
    late WakelockPlusPlatformInterface originalPlatform;
    late _FakeWakelockPlus fake;

    setUp(() {
      originalPlatform = wakelockPlusPlatformInstance;
      fake = _FakeWakelockPlus();
      wakelockPlusPlatformInstance = fake;
    });

    tearDown(() {
      wakelockPlusPlatformInstance = originalPlatform;
    });

    testWidgets('enables wakelock when active workout body mounts', (
      tester,
    ) async {
      await tester.pumpWidget(_buildWithState(_makeState()));
      // First pump resolves the AsyncNotifier future; second builds the body.
      await tester.pump();
      await tester.pump();

      // Confirm the body rendered (sanity — without it the hook never runs).
      expect(find.text('Push Day'), findsOneWidget);

      // initState should have called WakelockPlus.enable() exactly once.
      expect(fake.toggleCalls, contains(true));
      expect(
        fake.toggleCalls.where((e) => e == true).length,
        1,
        reason: 'WakelockPlus.enable should be invoked once on mount',
      );
    });

    testWidgets('disables wakelock when active workout body unmounts', (
      tester,
    ) async {
      await tester.pumpWidget(_buildWithState(_makeState()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Push Day'), findsOneWidget);
      expect(fake.toggleCalls, [true]);

      // Replace the whole tree with a blank scaffold to force dispose().
      await tester.pumpWidget(
        const TestMaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();

      // dispose() should have queued a WakelockPlus.disable() call.
      expect(
        fake.toggleCalls,
        [true, false],
        reason:
            'WakelockPlus.disable should follow enable when the screen unmounts',
      );
    });

    testWidgets(
      'swallows platform errors so unsupported platforms do not crash',
      (tester) async {
        // Install a fake that always throws. The screen must still mount
        // without surfacing the exception.
        wakelockPlusPlatformInstance = _ThrowingWakelockPlus();

        await tester.pumpWidget(_buildWithState(_makeState()));
        await tester.pump();
        await tester.pump();

        expect(find.text('Push Day'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Unmount should also stay quiet.
        await tester.pumpWidget(
          const TestMaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// Platform fake that throws on every toggle — simulates an unsupported
/// platform (e.g. a web browser without the WakeLock API) so we can verify
/// the production code swallows errors and does not crash the logging UI.
class _ThrowingWakelockPlus implements WakelockPlusPlatformInterface {
  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {
    throw UnsupportedError('wakelock not supported on this platform');
  }

  @override
  Future<bool> get enabled async => false;
}
