/// Unit tests verifying autoDispose on family providers that were missing it.
///
/// - lastWorkoutSetsProvider (workout_providers.dart)
/// - workoutDetailProvider (workout_history_providers.dart)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/workouts/data/workout_repository.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/providers/workout_history_providers.dart';
import 'package:repsaga/features/workouts/providers/workout_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/test_factories.dart';

class _MockWorkoutRepository extends Mock implements WorkoutRepository {}

void main() {
  late _MockWorkoutRepository mockRepo;

  setUp(() {
    mockRepo = _MockWorkoutRepository();
  });

  group('lastWorkoutSetsProvider autoDispose', () {
    test('auto-disposes family entries when listeners are removed', () async {
      when(
        () => mockRepo.getLastWorkoutSets(any()),
      ).thenAnswer((_) async => <String, List<ExerciseSet>>{});

      final container = ProviderContainer(
        overrides: [workoutRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      const joinedIds = 'ex-1,ex-2';
      final provider = lastWorkoutSetsProvider(joinedIds);

      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);

      expect(container.exists(provider), isTrue);

      sub.close();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.exists(provider),
        isFalse,
        reason:
            'lastWorkoutSetsProvider should auto-dispose when '
            'listeners drop',
      );
    });
  });

  group('workoutDetailProvider autoDispose', () {
    test('auto-disposes family entries when listeners are removed', () async {
      final WorkoutDetail detail = (
        workout: Workout.fromJson(TestWorkoutFactory.create(id: 'w-1')),
        exercises: const [],
        setsByExercise: const <String, List<ExerciseSet>>{},
      );

      when(
        () => mockRepo.getWorkoutDetail('w-1'),
      ).thenAnswer((_) async => detail);

      final container = ProviderContainer(
        overrides: [workoutRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      final provider = workoutDetailProvider('w-1');

      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);

      expect(container.exists(provider), isTrue);

      sub.close();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.exists(provider),
        isFalse,
        reason:
            'workoutDetailProvider should auto-dispose when '
            'listeners drop',
      );
    });
  });
}
