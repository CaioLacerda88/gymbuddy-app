import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/ui/widgets/routine_action_sheet.dart';

void main() {
  group('showRoutineActionSheet (PO-033)', () {
    testWidgets('shows Edit and Delete options', (tester) async {
      final routine = Routine(
        id: 'routine-1',
        name: 'Push Day',
        isDefault: false,
        exercises: const [],
        createdAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        showRoutineActionSheet(context, ref, routine),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('dismisses when tapping outside', (tester) async {
      final routine = Routine(
        id: 'routine-1',
        name: 'Push Day',
        isDefault: false,
        exercises: const [],
        createdAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        showRoutineActionSheet(context, ref, routine),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);

      // Tap the scrim to dismiss.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
    });
  });
}
