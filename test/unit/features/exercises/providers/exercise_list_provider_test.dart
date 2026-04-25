/// Unit tests for [exerciseListProvider] and [filteredExerciseListProvider].
///
/// Verifies:
///  - F1: autoDispose behaviour (family entries cleaned up when listeners drop)
///  - F2: invalidation targets (filteredExerciseListProvider delegates correctly)
///  - Filter composition in filteredExerciseListProvider
///
/// Phase 15f Stage 6: providers now read locale + userId and pass them
/// through to the repository. Tests override `localeProvider` and
/// `currentUserIdProvider` to keep the mock surface flat.
library;

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/l10n/locale_provider.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/exercises/data/exercise_repository.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/exercises/providers/exercise_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../../helpers/stub_locale_notifier.dart';

class _MockExerciseRepository extends Mock implements ExerciseRepository {}

void main() {
  late _MockExerciseRepository mockRepo;

  setUp(() {
    mockRepo = _MockExerciseRepository();
  });

  ProviderContainer createContainer({
    String userId = 'user-001',
    String localeCode = 'en',
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
    String searchQuery = '',
  }) {
    return ProviderContainer(
      overrides: [
        exerciseRepositoryProvider.overrideWithValue(mockRepo),
        currentUserIdProvider.overrideWithValue(userId),
        localeProvider.overrideWith(
          () => StubLocaleNotifier(Locale(localeCode)),
        ),
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
      TestExerciseFactory.create(
        id: 'exercise-002',
        name: 'Squat',
        slug: 'squat',
      ),
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

    test(
      'calls getExercises with locale + userId when searchQuery empty',
      () async {
        when(
          () => mockRepo.getExercises(
            locale: 'en',
            userId: 'user-001',
            muscleGroup: MuscleGroup.chest,
          ),
        ).thenAnswer((_) async => testExercises);

        final container = createContainer();
        addTearDown(container.dispose);

        const filter = ExerciseFilter(muscleGroup: MuscleGroup.chest);
        final result = await container.read(
          exerciseListProvider(filter).future,
        );

        expect(result, testExercises);
        verify(
          () => mockRepo.getExercises(
            locale: 'en',
            userId: 'user-001',
            muscleGroup: MuscleGroup.chest,
          ),
        ).called(1);
        verifyNever(
          () => mockRepo.searchExercises(
            locale: any(named: 'locale'),
            userId: any(named: 'userId'),
            query: any(named: 'query'),
            muscleGroup: any(named: 'muscleGroup'),
            equipmentType: any(named: 'equipmentType'),
          ),
        );
      },
    );

    test('calls searchExercises when searchQuery is non-empty', () async {
      when(
        () => mockRepo.searchExercises(
          locale: 'en',
          userId: 'user-001',
          query: 'bench',
          muscleGroup: MuscleGroup.chest,
        ),
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
        () => mockRepo.searchExercises(
          locale: 'en',
          userId: 'user-001',
          query: 'bench',
          muscleGroup: MuscleGroup.chest,
        ),
      ).called(1);
    });

    test('locale override flows through to repo call', () async {
      when(
        () => mockRepo.getExercises(locale: 'pt', userId: 'user-001'),
      ).thenAnswer((_) async => testExercises);

      final container = createContainer(localeCode: 'pt');
      addTearDown(container.dispose);

      const filter = ExerciseFilter();
      await container.read(exerciseListProvider(filter).future);

      verify(
        () => mockRepo.getExercises(locale: 'pt', userId: 'user-001'),
      ).called(1);
    });

    test(
      'F1: auto-disposes family entries when listeners are removed',
      () async {
        when(
          () => mockRepo.getExercises(
            locale: 'en',
            userId: 'user-001',
            muscleGroup: MuscleGroup.chest,
          ),
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
          locale: 'en',
          userId: 'user-001',
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
        when(
          () => mockRepo.getExercises(locale: 'en', userId: 'user-001'),
        ).thenAnswer((_) async {
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

  // F4: filter state must reset when no UI is listening, mirroring the
  // lifetime of the ExerciseListScreen. Without autoDispose on the three
  // filter StateProviders + filteredExerciseListProvider, the filter values
  // outlive the screen — so navigating away from /exercises and back keeps
  // the previous searchQuery / muscleGroup / equipmentType. The TextField's
  // controller, however, IS local to the screen and resets to empty on
  // remount. Result: the search field appears empty but the list is still
  // filtered, and the user cannot recover (clearing an empty field is a
  // no-op, and tapping chips composes against the stale searchQuery).
  group('F4: filter state lifecycle', () {
    test(
      'searchQueryProvider auto-disposes when no listeners remain',
      () async {
        when(
          () => mockRepo.getExercises(locale: 'en', userId: 'user-001'),
        ).thenAnswer((_) async => testExercises);

        final container = createContainer();
        addTearDown(container.dispose);

        // Simulate the screen subscribing to filteredExerciseListProvider,
        // which transitively keeps the filter providers alive.
        final sub = container.listen(filteredExerciseListProvider, (_, _) {});

        // User types into the search field; provider state updates.
        container.read(searchQueryProvider.notifier).state = 'bench';
        expect(container.read(searchQueryProvider), 'bench');

        // Screen unmounts — listener drops.
        sub.close();
        await Future<void>.delayed(Duration.zero);

        // Filter providers must tear down so a fresh subscriber sees defaults
        // (mirrors what the ExerciseListScreen state expects on remount).
        expect(
          container.exists(searchQueryProvider),
          isFalse,
          reason: 'searchQueryProvider must autoDispose when nothing listens',
        );

        // Re-subscribe (simulates navigating back to the screen).
        container.listen(filteredExerciseListProvider, (_, _) {});
        expect(
          container.read(searchQueryProvider),
          '',
          reason: 'remount must observe a clean default search query',
        );
      },
    );

    test(
      'selectedMuscleGroupProvider auto-disposes when no listeners remain',
      () async {
        when(
          () => mockRepo.getExercises(locale: 'en', userId: 'user-001'),
        ).thenAnswer((_) async => testExercises);

        final container = createContainer();
        addTearDown(container.dispose);

        final sub = container.listen(filteredExerciseListProvider, (_, _) {});

        container.read(selectedMuscleGroupProvider.notifier).state =
            MuscleGroup.chest;
        expect(container.read(selectedMuscleGroupProvider), MuscleGroup.chest);

        sub.close();
        await Future<void>.delayed(Duration.zero);

        expect(
          container.exists(selectedMuscleGroupProvider),
          isFalse,
          reason:
              'selectedMuscleGroupProvider must autoDispose when nothing listens',
        );

        container.listen(filteredExerciseListProvider, (_, _) {});
        expect(
          container.read(selectedMuscleGroupProvider),
          isNull,
          reason: 'remount must observe a clean default muscle group',
        );
      },
    );

    test(
      'selectedEquipmentTypeProvider auto-disposes when no listeners remain',
      () async {
        when(
          () => mockRepo.getExercises(locale: 'en', userId: 'user-001'),
        ).thenAnswer((_) async => testExercises);

        final container = createContainer();
        addTearDown(container.dispose);

        final sub = container.listen(filteredExerciseListProvider, (_, _) {});

        container.read(selectedEquipmentTypeProvider.notifier).state =
            EquipmentType.barbell;
        expect(
          container.read(selectedEquipmentTypeProvider),
          EquipmentType.barbell,
        );

        sub.close();
        await Future<void>.delayed(Duration.zero);

        expect(
          container.exists(selectedEquipmentTypeProvider),
          isFalse,
          reason:
              'selectedEquipmentTypeProvider must autoDispose when nothing listens',
        );

        container.listen(filteredExerciseListProvider, (_, _) {});
        expect(
          container.read(selectedEquipmentTypeProvider),
          isNull,
          reason: 'remount must observe a clean default equipment type',
        );
      },
    );

    test(
      'filteredExerciseListProvider auto-disposes when no listeners remain',
      () async {
        when(
          () => mockRepo.getExercises(locale: 'en', userId: 'user-001'),
        ).thenAnswer((_) async => testExercises);

        final container = createContainer();
        addTearDown(container.dispose);

        final sub = container.listen(filteredExerciseListProvider, (_, _) {});
        expect(container.exists(filteredExerciseListProvider), isTrue);

        sub.close();
        await Future<void>.delayed(Duration.zero);

        expect(
          container.exists(filteredExerciseListProvider),
          isFalse,
          reason:
              'filteredExerciseListProvider must autoDispose so the chain '
              'breaks and the filter StateProviders can also dispose',
        );
      },
    );
  });
}
