import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/personal_records/domain/pr_detection_service.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';
import 'package:gymbuddy_app/features/personal_records/ui/pr_celebration_screen.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';

void main() {
  Widget buildTestWidget({
    required PRDetectionResult result,
    required Map<String, String> exerciseNames,
  }) {
    return ProviderScope(
      overrides: [profileProvider.overrideWith(() => _FakeProfileNotifier())],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: PRCelebrationScreen(result: result, exerciseNames: exerciseNames),
      ),
    );
  }

  PersonalRecord makeRecord({
    String exerciseId = 'exercise-001',
    RecordType recordType = RecordType.maxWeight,
    double value = 100,
  }) {
    return PersonalRecord(
      id: 'pr-${recordType.name}-$exerciseId',
      userId: 'user-001',
      exerciseId: exerciseId,
      recordType: recordType,
      value: value,
      achievedAt: DateTime(2026),
    );
  }

  group('PRCelebrationScreen', () {
    testWidgets('shows first workout message when isFirstWorkout is true', (
      tester,
    ) async {
      final result = PRDetectionResult(
        newRecords: [
          makeRecord(recordType: RecordType.maxWeight, value: 100),
          makeRecord(recordType: RecordType.maxReps, value: 10),
        ],
        isFirstWorkout: true,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First Workout Complete!'), findsOneWidget);
      expect(find.text('These are your starting benchmarks'), findsOneWidget);
    });

    testWidgets('shows NEW PR banner for subsequent PRs', (tester) async {
      final result = PRDetectionResult(
        newRecords: [makeRecord(recordType: RecordType.maxWeight, value: 120)],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEW PR'), findsOneWidget);
    });

    testWidgets('shows exercise name and record values', (tester) async {
      final result = PRDetectionResult(
        newRecords: [
          makeRecord(
            exerciseId: 'exercise-001',
            recordType: RecordType.maxWeight,
            value: 120,
          ),
        ],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('120 kg'), findsOneWidget);
    });

    testWidgets('continue button is present', (tester) async {
      final result = PRDetectionResult(
        newRecords: [makeRecord()],
        isFirstWorkout: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          result: result,
          exerciseNames: {'exercise-001': 'Bench Press'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
    });
  });
}

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async {
    return const Profile(id: 'user-001', weightUnit: 'kg');
  }

  @override
  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
    int trainingFrequencyPerWeek = 3,
  }) async {}

  @override
  Future<void> updateTrainingFrequency(int frequency) async {}

  @override
  Future<void> toggleWeightUnit() async {}
}
