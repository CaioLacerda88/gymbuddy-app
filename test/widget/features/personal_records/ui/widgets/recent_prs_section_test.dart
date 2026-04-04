import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/personal_records/ui/widgets/recent_prs_section.dart';

void main() {
  Widget buildTestWidget({
    required List<Override> overrides,
    GoRouter? router,
  }) {
    final goRouter =
        router ??
        GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: RecentPRsSection()),
            ),
            GoRoute(
              path: '/records',
              builder: (context, state) =>
                  const Scaffold(body: Text('Records Screen')),
            ),
          ],
        );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: goRouter),
    );
  }

  PRWithExercise makePR({
    String id = 'pr-1',
    String exerciseId = 'e-1',
    String exerciseName = 'Bench Press',
    RecordType recordType = RecordType.maxWeight,
    double value = 100.0,
    DateTime? achievedAt,
  }) {
    return (
      record: PersonalRecord(
        id: id,
        userId: 'u-1',
        exerciseId: exerciseId,
        recordType: recordType,
        value: value,
        achievedAt: achievedAt ?? DateTime.now().toUtc(),
      ),
      exerciseName: exerciseName,
      equipmentType: EquipmentType.barbell,
    );
  }

  group('RecentPRsSection', () {
    testWidgets('is hidden when PR list is empty', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith((ref) async => <PRWithExercise>[]),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('RECENT RECORDS'), findsNothing);
      expect(find.text('View All'), findsNothing);
    });

    testWidgets('is hidden when loading', (tester) async {
      final completer = Completer<List<PRWithExercise>>();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('RECENT RECORDS'), findsNothing);

      // Complete to avoid pending timer assertion.
      completer.complete([]);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('is hidden when error', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith(
              (ref) async => throw Exception('network error'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('RECENT RECORDS'), findsNothing);
    });

    testWidgets('shows section header and View All when PRs exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith((ref) async => [makePR()]),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('RECENT RECORDS'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('shows exercise name and formatted value for maxWeight', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith(
              (ref) async => [
                makePR(
                  exerciseName: 'Bench Press',
                  recordType: RecordType.maxWeight,
                  value: 100.0,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('100 kg'), findsOneWidget);
    });

    testWidgets('shows decimal value for non-whole weight', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith(
              (ref) async => [
                makePR(
                  exerciseName: 'Squat',
                  recordType: RecordType.maxWeight,
                  value: 22.5,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('22.5 kg'), findsOneWidget);
    });

    testWidgets('shows formatted value for maxReps', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith(
              (ref) async => [
                makePR(
                  exerciseName: 'Pull-ups',
                  recordType: RecordType.maxReps,
                  value: 15.0,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Pull-ups'), findsOneWidget);
      expect(find.text('15 reps'), findsOneWidget);
    });

    testWidgets('shows up to 3 PR rows', (tester) async {
      final prs = [
        makePR(id: 'pr-1', exerciseName: 'Bench Press'),
        makePR(id: 'pr-2', exerciseName: 'Squat'),
        makePR(id: 'pr-3', exerciseName: 'Deadlift'),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [recentPRsProvider.overrideWith((ref) async => prs)],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Deadlift'), findsOneWidget);
    });

    testWidgets('shows Today for same-day PR', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith(
              (ref) async => [makePR(achievedAt: DateTime.now().toUtc())],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('navigates to /records when View All is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            recentPRsProvider.overrideWith((ref) async => [makePR()]),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();

      expect(find.text('Records Screen'), findsOneWidget);
    });
  });
}
