/// Unit tests for [exerciseListProvider] and [filteredExerciseListProvider].
///
/// Verifies:
///  - F1: autoDispose behaviour (family entries cleaned up when listeners drop)
///  - F2: invalidation targets (filteredExerciseListProvider delegates correctly)
///  - Filter composition in filteredExerciseListProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/data/exercise_repository.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/exercises/providers/exercise_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/test_factories.dart';

class _MockExerciseRepository extends Mock implements ExerciseRepository {}

void main() {
  late _MockExerciseRepository mockRepo;

  setUp(() {
    mockRepo = _MockExerciseRepository();
  });

  ProviderContainer createContainer({
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
    String searchQuery = '',
  }) {
    return ProviderContainer(
      overrides: [
        exerciseRepositoryProvider.overrideWithValue(mockRepo),
        if (muscleGroup != null)
          selectedMuscleGroupProvider.overrideWith((ref) => muscleGroup),
        if (equipmentType != null)
          selectedEquipmentTypeProvider.overrideWith((ref) => equipmentType),
        if (searchQuery.isNotEmpty)
          searchQueryProvider.overrideWith((ref) => searchQuery),
      ],
    );
  }

  final testExercises = [
    Exercise.fromJson(TestExerciseFactory.create()),
    Exercise.fromJson(
      TestExerciseFactory.create(id: 'exercise-002', name: 'Squat'),
    ),
  ];

  group('exerciseListProvider', () {
    test('is a family provider parameterized by ExerciseFilter', () {
      const filter1 = ExerciseFilter(muscleGroup: MuscleGroup.chest);
      const filter2 = ExerciseFilter(muscleGroup: MuscleGroup.back);
      const same = ExerciseFilter(muscleGroup: MuscleGroup.chest);

      final p1 = exerciseListProvider(filter1);
      final p2 = exerciseListProvider(filter2);
      final p3 = exerciseListProvider(same);

      expect(p1, isNot(equals(p2)));
      expect(p1, equals(p3));
    });

    test('calls getExercises when searchQuery is empty', () async {
      when(
        () => mockRepo.getExercises(muscleGroup: MuscleGroup.chest),
      ).thenAnswer((_) async => testExercises);

      final container = createContainer();
      addTearDown(container.dispose);

      const filter = ExerciseFilter(muscleGroup: MuscleGroup.chest);
      final result = await container.read(exerciseListProvider(filter).future);

      expect(result, testExercises);
      verify(
        () => mockRepo.getExercises(muscleGroup: MuscleGroup.chest),
      ).called(1);
      verifyNever(
        () => mockRepo.searchExercises(
          any(),
          muscleGroup: any(named: 'muscleGroup'),
          equipmentType: any(named: 'equipmentType'),
        ),
      );
    });

    test('calls searchExercises when searchQuery is non-empty', () async {
      when(
        () => mockRepo.searchExercises('bench', muscleGroup: MuscleGroup.chest),
      ).thenAnswer((_) async => [testExercises.first]);

      final container = createContainer();
      addTearDown(container.dispose);

      const filter = ExerciseFilter(
        muscleGroup: MuscleGroup.chest,
        searchQuery: 'bench',
      );
      final result = await container.read(exerciseListProvider(filter).future);

      expect(result, [testExercises.first]);
      verify(
        () => mockRepo.searchExercises('bench', muscleGroup: MuscleGroup.chest),
      ).called(1);
    });

    test(
      'F1: auto-disposes family entries when listeners are removed',
      () async {
        when(
          () => mockRepo.getExercises(muscleGroup: MuscleGroup.chest),
        ).thenAnswer((_) async => testExercises);

        final container = createContainer();
        addTearDown(container.dispose);

        const filter = ExerciseFilter(muscleGroup: MuscleGroup.chest);
        final provider = exerciseListProvider(filter);

        // Create a listener
        final sub = container.listen(provider, (_, _) {});
        await container.read(provider.future);

        // Provider should exist while listened to
        expect(container.exists(provider), isTrue);

        // Close the listener — autoDispose should clean up
        sub.close();

        // After a microtask, the provider should be disposed
        await Future<void>.delayed(Duration.zero);

        expect(
          container.exists(provider),
          isFalse,
          reason:
              'F1: exerciseListProvider should auto-dispose when listeners drop',
        );
      },
    );
  });

  group('filteredExerciseListProvider', () {
    test('composes filter from state providers and delegates to '
        'exerciseListProvider', () async {
      when(
        () => mockRepo.getExercises(
          muscleGroup: MuscleGroup.chest,
          equipmentType: EquipmentType.barbell,
        ),
      ).thenAnswer((_) async => testExercises);

      final container = createContainer(
        muscleGroup: MuscleGroup.chest,
        equipmentType: EquipmentType.barbell,
      );
      addTearDown(container.dispose);

      // Listen so the provider is actively maintained
      container.listen(filteredExerciseListProvider, (_, _) {});

      // Wait for the async data to resolve
      await container.read(
        exerciseListProvider(
          const ExerciseFilter(
            muscleGroup: MuscleGroup.chest,
            equipmentType: EquipmentType.barbell,
          ),
        ).future,
      );

      final result = container.read(filteredExerciseListProvider);
      expect(result, isA<AsyncData<List<Exercise>>>());
      expect(result.value, testExercises);
    });

    test(
      'F2: invalidating exerciseListProvider clears underlying data',
      () async {
        var callCount = 0;
        when(() => mockRepo.getExercises()).thenAnswer((_) async {
          callCount++;
          return testExercises;
        });

        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(filteredExerciseListProvider, (_, _) {});

        const filter = ExerciseFilter();
        await container.read(exerciseListProvider(filter).future);
        expect(callCount, 1);

        // Invalidating exerciseListProvider should force re-fetch
        container.invalidate(exerciseListProvider);
        await container.read(exerciseListProvider(filter).future);
        expect(
          callCount,
          2,
          reason:
              'F2: invalidating exerciseListProvider forces fresh Supabase query',
        );
      },
    );
  });

  group('ExerciseFilter', () {
    test('value equality', () {
      const a = ExerciseFilter(muscleGroup: MuscleGroup.chest);
      const b = ExerciseFilter(muscleGroup: MuscleGroup.chest);
      const c = ExerciseFilter(muscleGroup: MuscleGroup.back);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('default values', () {
      const filter = ExerciseFilter();
      expect(filter.muscleGroup, isNull);
      expect(filter.equipmentType, isNull);
      expect(filter.searchQuery, isEmpty);
    });
  });
}
