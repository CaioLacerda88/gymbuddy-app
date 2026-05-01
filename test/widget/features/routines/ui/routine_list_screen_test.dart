/// Widget tests for the Routines screen (`/routines`).
///
/// Per PLAN W8, starter routines are moved OFF the home screen and must
/// surface on the Routines screen. This test file locks down that
/// contract so we never accidentally drop the starter section when
/// refactoring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/routines/models/routine.dart';
import 'package:repsaga/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:repsaga/features/routines/ui/routine_list_screen.dart';
import '../../../../helpers/test_material_app.dart';

class _RoutineListStub extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  _RoutineListStub(this.routines);
  final List<Routine> routines;

  @override
  Future<List<Routine>> build() async => routines;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Routine _routine({
  required String id,
  required String name,
  bool isDefault = false,
  String? userId,
}) => Routine(
  id: id,
  name: name,
  userId: userId,
  isDefault: isDefault,
  exercises: const [],
  createdAt: DateTime(2026),
);

Widget _build({required List<Routine> routines}) {
  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _RoutineListStub(routines)),
    ],
    child: TestMaterialApp(
      theme: AppTheme.dark,
      home: const RoutineListScreen(),
    ),
  );
}

void main() {
  group('RoutineListScreen - starter routines section', () {
    testWidgets('renders STARTER ROUTINES section when defaults exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          routines: [
            _routine(id: 'default-1', name: 'Full Body', isDefault: true),
            _routine(id: 'default-2', name: 'Upper Body', isDefault: true),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('STARTER ROUTINES'), findsOneWidget);
      expect(find.text('Full Body'), findsOneWidget);
      expect(find.text('Upper Body'), findsOneWidget);
    });

    testWidgets(
      'renders both MY ROUTINES and STARTER ROUTINES when user has both',
      (tester) async {
        await tester.pumpWidget(
          _build(
            routines: [
              _routine(id: 'u-1', name: 'My Workout', userId: 'user-001'),
              _routine(id: 'd-1', name: 'Full Body', isDefault: true),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('MY ROUTINES'), findsOneWidget);
        expect(find.text('STARTER ROUTINES'), findsOneWidget);
        expect(find.text('My Workout'), findsOneWidget);
        expect(find.text('Full Body'), findsOneWidget);
      },
    );

    testWidgets('omits STARTER ROUTINES when no defaults exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          routines: [_routine(id: 'u-1', name: 'X', userId: 'user-001')],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('STARTER ROUTINES'), findsNothing);
    });
  });

  group('RoutineListScreen - BUG-029 branded empty state', () {
    testWidgets('renders branded empty state when there are no user routines', (
      tester,
    ) async {
      await tester.pumpWidget(_build(routines: const []));
      await tester.pump();
      await tester.pump();

      // Title + body + CTA must all surface from the new ARB keys.
      expect(find.text('No routines yet'), findsOneWidget);
      expect(
        find.text('Plan a workout sequence once and reuse it every session.'),
        findsOneWidget,
      );
      expect(find.text('Create routine'), findsOneWidget);
    });

    testWidgets('empty-state CTA is wrapped in a FilledButton.icon', (
      tester,
    ) async {
      await tester.pumpWidget(_build(routines: const []));
      await tester.pump();
      await tester.pump();

      // The CTA must be the inline FilledButton, not a TextButton or a
      // pointer to the AppBar `+` icon — that was BUG-029's ergonomic miss.
      expect(
        find.widgetWithText(FilledButton, 'Create routine'),
        findsOneWidget,
      );
    });

    testWidgets(
      'empty state still renders alongside STARTER ROUTINES when defaults exist',
      (tester) async {
        await tester.pumpWidget(
          _build(
            routines: [_routine(id: 'd-1', name: 'Full Body', isDefault: true)],
          ),
        );
        await tester.pump();
        await tester.pump();

        // The user has no custom routines → empty state renders. The starter
        // section still ships below it.
        expect(find.text('No routines yet'), findsOneWidget);
        expect(find.text('STARTER ROUTINES'), findsOneWidget);
        expect(find.text('Full Body'), findsOneWidget);
      },
    );
  });
}
