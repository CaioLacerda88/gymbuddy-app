import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/personal_records/data/pr_repository.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/profile/ui/manage_data_screen.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/shared/widgets/gradient_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockPRRepository extends Mock implements PRRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget buildTestWidget({
  int workoutCount = 14,
  int prCount = 3,
  MockWorkoutRepository? workoutRepo,
  MockPRRepository? prRepo,
}) {
  final mockAuth = MockAuthRepository();
  final mockUser = MockUser();
  when(() => mockUser.id).thenReturn('user-001');
  when(() => mockAuth.currentUser).thenReturn(mockUser);

  final mockWorkoutRepo = workoutRepo ?? MockWorkoutRepository();
  if (workoutRepo == null) {
    when(() => mockWorkoutRepo.clearHistory(any())).thenAnswer((_) async {});
  }

  final mockPRRepo = prRepo ?? MockPRRepository();
  if (prRepo == null) {
    when(() => mockPRRepo.clearAllRecords(any())).thenAnswer((_) async {});
  }

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockAuth),
      workoutRepositoryProvider.overrideWithValue(mockWorkoutRepo),
      prRepositoryProvider.overrideWithValue(mockPRRepo),
      workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
      prCountProvider.overrideWith((ref) => Future.value(prCount)),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: const ManageDataScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ManageDataScreen', () {
    testWidgets('renders both data management options', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('WORKOUT HISTORY'), findsOneWidget);
      expect(find.text('Delete Workout History'), findsOneWidget);
      expect(find.text('DANGER'), findsOneWidget);
      expect(find.text('Reset All Account Data'), findsOneWidget);
    });

    testWidgets('shows live workout count in subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 14));
      await tester.pump();
      await tester.pump();

      expect(find.text('14 workouts will be removed'), findsOneWidget);
    });

    testWidgets('shows 0 workouts in subtitle when none exist', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 0));
      await tester.pump();
      await tester.pump();

      expect(find.text('0 workouts will be removed'), findsOneWidget);
    });

    group('Delete Workout History two-step dialog', () {
      testWidgets('first dialog shows count and delete button', (tester) async {
        await tester.pumpWidget(buildTestWidget(workoutCount: 14));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Delete Workout History'));
        await tester.pumpAndSettle();

        expect(find.text('Delete all workout history?'), findsOneWidget);
        expect(
          find.textContaining('permanently delete all 14 workouts'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete History'), findsOneWidget);
      });

      testWidgets('cancel at first step aborts', (tester) async {
        final mockWorkoutRepo = MockWorkoutRepository();
        when(
          () => mockWorkoutRepo.clearHistory(any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget(workoutRepo: mockWorkoutRepo));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Delete Workout History'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => mockWorkoutRepo.clearHistory(any()));
      });

      testWidgets('second dialog asks for confirmation', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Delete Workout History'));
        await tester.pumpAndSettle();

        // Proceed past first dialog.
        await tester.tap(find.text('Delete History'));
        await tester.pumpAndSettle();

        expect(find.text('Are you sure?'), findsOneWidget);
        expect(
          find.text('Your personal records and routines will be kept.'),
          findsOneWidget,
        );
        expect(find.text('Yes, Delete'), findsOneWidget);
      });

      testWidgets('cancel at second step aborts', (tester) async {
        final mockWorkoutRepo = MockWorkoutRepository();
        when(
          () => mockWorkoutRepo.clearHistory(any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget(workoutRepo: mockWorkoutRepo));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Delete Workout History'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete History'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => mockWorkoutRepo.clearHistory(any()));
      });

      testWidgets('confirm at second step triggers delete and shows snackbar', (
        tester,
      ) async {
        final mockWorkoutRepo = MockWorkoutRepository();
        when(
          () => mockWorkoutRepo.clearHistory(any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildTestWidget(workoutRepo: mockWorkoutRepo));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Delete Workout History'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete History'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yes, Delete'));
        await tester.pumpAndSettle();

        verify(() => mockWorkoutRepo.clearHistory('user-001')).called(1);
        expect(find.text('Workout history cleared'), findsOneWidget);
      });
    });

    group('Reset All Account Data type-to-confirm', () {
      testWidgets('shows full-screen dialog with explanation', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Account Data'), findsOneWidget);
        expect(
          find.textContaining('permanently delete all workouts'),
          findsOneWidget,
        );
        expect(find.text('Type RESET to confirm'), findsOneWidget);
      });

      testWidgets('Reset Account button is disabled until RESET typed', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        // Button should be disabled (GradientButton onPressed is null).
        final button = tester.widget<GradientButton>(
          find.byType(GradientButton),
        );
        expect(button.onPressed, isNull);

        // Type 'RESET'.
        await tester.enterText(find.byType(TextField), 'RESET');
        await tester.pump();

        // Button should now be enabled.
        final updatedButton = tester.widget<GradientButton>(
          find.byType(GradientButton),
        );
        expect(updatedButton.onPressed, isNotNull);
      });

      testWidgets('typing reset (lowercase) also enables button', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'reset');
        await tester.pump();

        final button = tester.widget<GradientButton>(
          find.byType(GradientButton),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('cancel closes dialog without deleting', (tester) async {
        final mockWorkoutRepo = MockWorkoutRepository();
        when(
          () => mockWorkoutRepo.clearHistory(any()),
        ).thenAnswer((_) async {});
        final mockPRRepo = MockPRRepository();
        when(() => mockPRRepo.clearAllRecords(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildTestWidget(workoutRepo: mockWorkoutRepo, prRepo: mockPRRepo),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => mockWorkoutRepo.clearHistory(any()));
        verifyNever(() => mockPRRepo.clearAllRecords(any()));
      });

      testWidgets('confirm triggers reset and shows snackbar', (tester) async {
        final mockWorkoutRepo = MockWorkoutRepository();
        when(
          () => mockWorkoutRepo.clearHistory(any()),
        ).thenAnswer((_) async {});
        final mockPRRepo = MockPRRepository();
        when(() => mockPRRepo.clearAllRecords(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildTestWidget(workoutRepo: mockWorkoutRepo, prRepo: mockPRRepo),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        // Type RESET and confirm.
        await tester.enterText(find.byType(TextField), 'RESET');
        await tester.pump();

        // Tap the Reset Account button (inside GradientButton).
        await tester.tap(find.text('Reset Account'));
        await tester.pumpAndSettle();

        verify(() => mockWorkoutRepo.clearHistory('user-001')).called(1);
        verify(() => mockPRRepo.clearAllRecords('user-001')).called(1);
        expect(find.text('Account data reset'), findsOneWidget);
      });

      testWidgets('reset deletes PRs before workouts (FK order)', (
        tester,
      ) async {
        final callOrder = <String>[];
        final mockWorkoutRepo = MockWorkoutRepository();
        when(() => mockWorkoutRepo.clearHistory(any())).thenAnswer((_) async {
          callOrder.add('clearHistory');
        });
        final mockPRRepo = MockPRRepository();
        when(() => mockPRRepo.clearAllRecords(any())).thenAnswer((_) async {
          callOrder.add('clearAllRecords');
        });

        await tester.pumpWidget(
          buildTestWidget(workoutRepo: mockWorkoutRepo, prRepo: mockPRRepo),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'RESET');
        await tester.pump();

        await tester.tap(find.text('Reset Account'));
        await tester.pumpAndSettle();

        // PRs must be deleted first to avoid FK violation on set_id.
        expect(callOrder, ['clearAllRecords', 'clearHistory']);
      });
    });

    group('Error states show safe messages', () {
      testWidgets('delete history error shows safe message, not raw DB error', (
        tester,
      ) async {
        final mockWorkoutRepo = MockWorkoutRepository();
        when(() => mockWorkoutRepo.clearHistory(any())).thenThrow(
          const DatabaseException(
            'update or delete on table "sets" violates foreign key '
            'constraint "personal_records_set_id_fkey" on table '
            '"personal_records"',
            code: '23503',
          ),
        );

        await tester.pumpWidget(buildTestWidget(workoutRepo: mockWorkoutRepo));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Delete Workout History'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete History'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yes, Delete'));
        await tester.pumpAndSettle();

        // Should show safe message, not raw DB error.
        expect(find.textContaining('Something went wrong'), findsOneWidget);
        // Must NOT show table names.
        expect(find.textContaining('sets'), findsNothing);
        expect(find.textContaining('personal_records'), findsNothing);
        expect(find.textContaining('foreign key'), findsNothing);
      });

      testWidgets('reset all error shows safe message, not raw DB error', (
        tester,
      ) async {
        final mockPRRepo = MockPRRepository();
        when(() => mockPRRepo.clearAllRecords(any())).thenThrow(
          const DatabaseException(
            'relation "personal_records" does not exist',
            code: '42P01',
          ),
        );

        await tester.pumpWidget(buildTestWidget(prRepo: mockPRRepo));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Reset All Account Data'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'RESET');
        await tester.pump();

        await tester.tap(find.text('Reset Account'));
        await tester.pumpAndSettle();

        // Should show safe message.
        expect(find.textContaining('Something went wrong'), findsOneWidget);
        // Must NOT show table names.
        expect(find.textContaining('personal_records'), findsNothing);
      });
    });
  });
}
