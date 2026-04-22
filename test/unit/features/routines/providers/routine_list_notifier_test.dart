/// Unit tests for [RoutineListNotifier.duplicateRoutine].
///
/// Covers:
/// - The copy is named "<source name> (Copy)"
/// - The copy has isDefault: false
/// - duplicateRoutine returns the new Routine from createRoutine
/// - When userId is null, duplicateRoutine returns null and does not call the repo
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/auth/data/auth_repository.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/routines/data/routine_repository.dart';
import 'package:repsaga/features/routines/models/routine.dart';
import 'package:repsaga/features/routines/providers/routine_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockRoutineRepository extends Mock implements RoutineRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

User _fakeUser({String id = 'user-001'}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  isAnonymous: false,
);

Routine _makeRoutine({
  String id = 'routine-src',
  String name = 'Push Day',
  bool isDefault = true,
}) {
  return Routine.fromJson(
    TestRoutineFactory.create(id: id, name: name, isDefault: isDefault),
  );
}

/// Builds a [ProviderContainer] with the given mock repo and auth repository.
ProviderContainer _makeContainer({
  required MockRoutineRepository repo,
  required MockAuthRepository auth,
}) {
  return ProviderContainer(
    overrides: [
      routineRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(auth),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockRoutineRepository mockRepo;
  late MockAuthRepository mockAuth;

  setUpAll(() {
    registerFallbackValue(const <RoutineExercise>[]);
  });

  setUp(() {
    mockRepo = MockRoutineRepository();
    mockAuth = MockAuthRepository();
  });

  group('RoutineListNotifier.duplicateRoutine', () {
    test(
      'creates a copy named "<source name> (Copy)" with isDefault: false',
      () async {
        final source = _makeRoutine(name: 'Push Day', isDefault: true);
        final expectedCopy = source.copyWith(
          id: 'routine-copy',
          userId: 'user-001',
          isDefault: false,
          name: 'Push Day (Copy)',
        );

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createRoutine(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
            exercises: any(named: 'exercises'),
          ),
        ).thenAnswer((_) async => expectedCopy);
        when(() => mockRepo.getRoutines(any())).thenAnswer((_) async => []);

        final container = _makeContainer(repo: mockRepo, auth: mockAuth);
        addTearDown(container.dispose);

        final notifier = container.read(routineListProvider.notifier);

        final result = await notifier.duplicateRoutine(source);

        // Verify the name passed to createRoutine is "<source> (Copy)".
        final captured = verify(
          () => mockRepo.createRoutine(
            userId: captureAny(named: 'userId'),
            name: captureAny(named: 'name'),
            exercises: captureAny(named: 'exercises'),
          ),
        ).captured;

        // captured is [userId, name, exercises] in declaration order.
        expect(captured[1], equals('Push Day (Copy)'));

        // The returned Routine must have isDefault: false.
        expect(result, isNotNull);
        expect(result!.isDefault, isFalse);
        expect(result.name, equals('Push Day (Copy)'));
      },
    );

    test(
      'returns the Routine produced by createRoutine (passes through the repo value)',
      () async {
        final source = _makeRoutine(name: 'Leg Day');
        final copy = source.copyWith(
          id: 'routine-copy-leg',
          userId: 'user-001',
          isDefault: false,
          name: 'Leg Day (Copy)',
        );

        when(() => mockAuth.currentUser).thenReturn(_fakeUser());
        when(
          () => mockRepo.createRoutine(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
            exercises: any(named: 'exercises'),
          ),
        ).thenAnswer((_) async => copy);
        when(() => mockRepo.getRoutines(any())).thenAnswer((_) async => []);

        final container = _makeContainer(repo: mockRepo, auth: mockAuth);
        addTearDown(container.dispose);

        final notifier = container.read(routineListProvider.notifier);
        final result = await notifier.duplicateRoutine(source);

        expect(result, equals(copy));
      },
    );

    test('passes the source exercises unchanged to createRoutine', () async {
      final sourceWithExercises = Routine.fromJson(
        TestRoutineFactory.create(
          id: 'src-with-ex',
          name: 'Upper Body',
          exercises: [
            TestRoutineExerciseFactory.create(exerciseId: 'ex-1'),
            TestRoutineExerciseFactory.create(exerciseId: 'ex-2'),
          ],
        ),
      );
      final copiedRoutine = sourceWithExercises.copyWith(
        id: 'copy-upper',
        userId: 'user-001',
        isDefault: false,
        name: 'Upper Body (Copy)',
      );

      when(() => mockAuth.currentUser).thenReturn(_fakeUser());
      when(
        () => mockRepo.createRoutine(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
          exercises: any(named: 'exercises'),
        ),
      ).thenAnswer((_) async => copiedRoutine);
      when(() => mockRepo.getRoutines(any())).thenAnswer((_) async => []);

      final container = _makeContainer(repo: mockRepo, auth: mockAuth);
      addTearDown(container.dispose);

      final notifier = container.read(routineListProvider.notifier);
      await notifier.duplicateRoutine(sourceWithExercises);

      final captured = verify(
        () => mockRepo.createRoutine(
          userId: captureAny(named: 'userId'),
          name: captureAny(named: 'name'),
          exercises: captureAny(named: 'exercises'),
        ),
      ).captured;

      // captured: [userId, name, exercises]
      final exercises = captured[2] as List<RoutineExercise>;
      expect(exercises.length, equals(2));
      expect(exercises[0].exerciseId, equals('ex-1'));
      expect(exercises[1].exerciseId, equals('ex-2'));
    });

    test(
      'returns null and does not call createRoutine when userId is null',
      () async {
        final source = _makeRoutine();

        when(() => mockAuth.currentUser).thenReturn(null);
        when(() => mockRepo.getRoutines(any())).thenAnswer((_) async => []);

        final container = _makeContainer(repo: mockRepo, auth: mockAuth);
        addTearDown(container.dispose);

        final notifier = container.read(routineListProvider.notifier);
        final result = await notifier.duplicateRoutine(source);

        expect(result, isNull);
        verifyNever(
          () => mockRepo.createRoutine(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
            exercises: any(named: 'exercises'),
          ),
        );
      },
    );

    test('invalidates the routine list after a successful duplicate', () async {
      final source = _makeRoutine();
      final copy = source.copyWith(
        id: 'copy-id',
        userId: 'user-001',
        isDefault: false,
        name: '${source.name} (Copy)',
      );

      when(() => mockAuth.currentUser).thenReturn(_fakeUser());
      when(
        () => mockRepo.createRoutine(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
          exercises: any(named: 'exercises'),
        ),
      ).thenAnswer((_) async => copy);
      when(() => mockRepo.getRoutines(any())).thenAnswer((_) async => []);

      final container = _makeContainer(repo: mockRepo, auth: mockAuth);
      addTearDown(container.dispose);

      // Force the provider to build (initial fetch) before duplicating.
      await container.read(routineListProvider.future);

      final notifier = container.read(routineListProvider.notifier);
      await notifier.duplicateRoutine(source);

      // Wait for the invalidated build to complete.
      await container.read(routineListProvider.future);

      // getRoutines should have been called at least twice:
      // once during initial build() and once after invalidateSelf().
      verify(() => mockRepo.getRoutines('user-001')).called(greaterThan(1));
    });
  });
}
