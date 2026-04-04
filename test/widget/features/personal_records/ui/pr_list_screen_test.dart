import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/personal_records/ui/pr_list_screen.dart';

void main() {
  Widget buildTestWidget({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.dark, home: const PRListScreen()),
    );
  }

  PRWithExercise makePRWithExercise({
    String exerciseId = 'exercise-001',
    String exerciseName = 'Bench Press',
    RecordType recordType = RecordType.maxWeight,
    double value = 100,
  }) {
    return (
      record: PersonalRecord(
        id: 'pr-${recordType.name}-$exerciseId',
        userId: 'user-001',
        exerciseId: exerciseId,
        recordType: recordType,
        value: value,
        achievedAt: DateTime(2026),
      ),
      exerciseName: exerciseName,
      equipmentType: EquipmentType.barbell,
    );
  }

  group('PRListScreen', () {
    testWidgets('shows empty state when no records', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            prListWithExercisesProvider.overrideWith(
              (ref) => Future.value(<PRWithExercise>[]),
            ),
          ],
        ),
      );
      // Let FutureProvider resolve
      await tester.pump();
      await tester.pump();

      expect(find.text('No Records Yet'), findsOneWidget);
      expect(
        find.text('Complete a workout to start tracking records'),
        findsOneWidget,
      );
    });

    testWidgets('shows records when data present', (tester) async {
      final records = [
        makePRWithExercise(
          exerciseName: 'Bench Press',
          recordType: RecordType.maxWeight,
          value: 120,
        ),
        makePRWithExercise(
          exerciseName: 'Bench Press',
          recordType: RecordType.maxReps,
          value: 12,
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            prListWithExercisesProvider.overrideWith(
              (ref) => Future.value(records),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('120.0 kg'), findsOneWidget);
      expect(find.text('12 reps'), findsOneWidget);
    });

    testWidgets('shows loading indicator', (tester) async {
      final completer = Completer<List<PRWithExercise>>();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            prListWithExercisesProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer issues.
      completer.complete([]);
      await tester.pump();
    });
  });
}
