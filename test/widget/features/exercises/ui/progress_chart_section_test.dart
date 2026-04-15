import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/progress_point.dart';
import 'package:gymbuddy_app/features/exercises/providers/exercise_progress_provider.dart';
import 'package:gymbuddy_app/features/exercises/ui/widgets/progress_chart_section.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  _FakeProfileNotifier(this._unit);
  final String _unit;

  @override
  Future<Profile?> build() async => Profile(id: 'user-001', weightUnit: _unit);

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

Widget _buildHarness({
  required String unit,
  required List<ProgressPoint> points,
}) {
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(() => _FakeProfileNotifier(unit)),
      exerciseProgressProvider.overrideWith((ref, _) async => points),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: ProgressChartSection(exerciseId: 'ex-1')),
    ),
  );
}

void main() {
  group('ProgressChartSection', () {
    testWidgets('renders empty-state copy when no points', (tester) async {
      await tester.pumpWidget(_buildHarness(unit: 'kg', points: const []));
      await tester.pumpAndSettle();

      expect(find.text('Progress (kg)'), findsOneWidget);
      expect(
        find.text('Log this exercise to see your progress'),
        findsOneWidget,
      );
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets(
      'renders chart with one dot and "1 session logged" for single point',
      (tester) async {
        final points = [
          ProgressPoint(
            date: DateTime(2026, 3, 1),
            weight: 100,
            sessionReps: 5,
          ),
        ];
        await tester.pumpWidget(_buildHarness(unit: 'kg', points: points));
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsOneWidget);
        expect(find.text('1 session logged'), findsOneWidget);
      },
    );

    testWidgets('renders multi-point chart without caption when >1 point', (
      tester,
    ) async {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 80, sessionReps: 10),
        ProgressPoint(date: DateTime(2026, 3, 8), weight: 90, sessionReps: 8),
        ProgressPoint(date: DateTime(2026, 3, 15), weight: 100, sessionReps: 5),
      ];
      await tester.pumpWidget(_buildHarness(unit: 'kg', points: points));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('1 session logged'), findsNothing);
      expect(find.text('Log this exercise to see your progress'), findsNothing);
    });

    testWidgets('header label swaps kg ↔ lbs with profile', (tester) async {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 100, sessionReps: 5),
      ];

      await tester.pumpWidget(_buildHarness(unit: 'lbs', points: points));
      await tester.pumpAndSettle();
      expect(find.text('Progress (lbs)'), findsOneWidget);
      expect(find.text('Progress (kg)'), findsNothing);
    });

    testWidgets('toggling 90d → All time triggers provider reload', (
      tester,
    ) async {
      // Arrange: track which window the provider was called with.
      final callLog = <TimeWindow>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier('kg')),
            exerciseProgressProvider.overrideWith((ref, key) async {
              callLog.add(key.window);
              return <ProgressPoint>[];
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              body: ProgressChartSection(exerciseId: 'ex-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(callLog, contains(TimeWindow.last90Days));
      final before = callLog.length;

      // Act: tap the "All time" segment.
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();

      // Assert: provider was re-resolved with the new window.
      expect(callLog.length, greaterThan(before));
      expect(callLog.last, TimeWindow.allTime);
    });

    testWidgets('sets Semantics label describing session count', (
      tester,
    ) async {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 80, sessionReps: 10),
        ProgressPoint(date: DateTime(2026, 3, 8), weight: 90, sessionReps: 8),
      ];
      await tester.pumpWidget(_buildHarness(unit: 'kg', points: points));
      await tester.pumpAndSettle();

      // Asserts the Semantics widget's `label` property carries the
      // session count — doesn't depend on the semantics tree being enabled.
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Progress chart, 2 sessions logged',
        ),
      );
      expect(semantics.properties.label, 'Progress chart, 2 sessions logged');
    });

    testWidgets('single-point Semantics label uses singular "session"', (
      tester,
    ) async {
      final points = [
        ProgressPoint(date: DateTime(2026, 3, 1), weight: 80, sessionReps: 10),
      ];
      await tester.pumpWidget(_buildHarness(unit: 'kg', points: points));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Progress chart, 1 session logged',
        ),
        findsOneWidget,
      );
    });
  });

  group('AppTheme.dark SegmentedButton', () {
    // Guards the dark-surface treatment added for the progress-chart window
    // toggle (and any other SegmentedButton in the app). A regression to
    // the M3 default would flip selected-segment foreground to `onSurface`
    // and drop unselected alpha back toward 0.38 — both caught here.
    const primary = Color(0xFF00E676);

    testWidgets('selected segment resolves to primary-tinted container', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('A')),
                ButtonSegment(value: 1, label: Text('B')),
              ],
              selected: const {0},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SegmentedButton<int>));
      final style = Theme.of(context).segmentedButtonTheme.style!;
      final selectedBg = style.backgroundColor!.resolve({WidgetState.selected});
      final selectedFg = style.foregroundColor!.resolve({WidgetState.selected});
      final selectedText = style.textStyle!.resolve({WidgetState.selected});

      expect(selectedBg, primary.withValues(alpha: 0.15));
      expect(selectedFg, primary);
      expect(selectedText?.fontWeight, FontWeight.w600);
    });

    testWidgets('unselected segment foreground is not ghostly (>= 0.5 alpha)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('A')),
                ButtonSegment(value: 1, label: Text('B')),
              ],
              selected: const {0},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SegmentedButton<int>));
      final style = Theme.of(context).segmentedButtonTheme.style!;
      final unselectedFg = style.foregroundColor!.resolve(
        const <WidgetState>{},
      );

      expect(unselectedFg, isNotNull);
      // Default M3 unselected alpha is ~0.38; our override lifts it to 0.75.
      expect(unselectedFg!.a, greaterThanOrEqualTo(0.5));
    });
  });
}
