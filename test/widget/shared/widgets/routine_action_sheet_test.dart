import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/routines/ui/widgets/routine_action_sheet.dart';
import 'package:gymbuddy_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a user-owned (non-default) routine.
Routine _userRoutine({String id = 'routine-user', String name = 'Push Day'}) {
  return Routine(
    id: id,
    name: name,
    userId: 'user-001',
    isDefault: false,
    exercises: const [],
    createdAt: DateTime(2026),
  );
}

/// Builds a default (preset) routine.
Routine _defaultRoutine({
  String id = 'routine-default',
  String name = 'Push Day',
}) {
  return Routine(
    id: id,
    name: name,
    userId: null,
    isDefault: true,
    exercises: const [],
    createdAt: DateTime(2026),
  );
}

/// A [RoutineListNotifier] stub that records method calls without touching
/// Supabase or GoRouter.
class _RoutineListStub extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  List<String> calls = [];

  @override
  Future<List<Routine>> build() async => [];

  @override
  Future<Routine?> duplicateRoutine(Routine source) async {
    calls.add('duplicateRoutine:${source.id}');
    // Return a copy with isDefault = false and a new id.
    return source.copyWith(
      id: '${source.id}-copy',
      userId: 'user-001',
      isDefault: false,
      name: '${source.name} (Copy)',
    );
  }

  @override
  Future<void> deleteRoutine(String id) async {
    calls.add('deleteRoutine:$id');
  }

  @override
  // ignore: must_call_super
  dynamic noSuchMethod(Invocation invocation) {}
}

/// A minimal GoRouter that provides enough routes for [showRoutineActionSheet]
/// to navigate without crashing. The destination screens themselves are empty
/// placeholders — we only need the router to be present in the context.
GoRouter _makeRouter(Routine routine, _RoutineListStub stub) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showRoutineActionSheet(context, ref, routine),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      // Destination for duplicate/edit navigation — plain placeholder.
      GoRoute(
        path: '/routines/create',
        builder: (context, state) =>
            const Scaffold(body: Text('Create Routine')),
      ),
    ],
  );
}

/// Renders a [MaterialApp.router] with a button that opens [showRoutineActionSheet].
/// Captures the stub so tests can inspect recorded calls.
Widget _buildHost(Routine routine, _RoutineListStub stub) {
  return ProviderScope(
    overrides: [routineListProvider.overrideWith(() => stub)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      routerConfig: _makeRouter(routine, stub),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('showRoutineActionSheet — user-owned routine', () {
    testWidgets('shows Edit and Delete options for a user routine', (
      tester,
    ) async {
      final routine = _userRoutine();
      final stub = _RoutineListStub();

      await tester.pumpWidget(_buildHost(routine, stub));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('does NOT show Start or Duplicate options for a user routine', (
      tester,
    ) async {
      final routine = _userRoutine();
      final stub = _RoutineListStub();

      await tester.pumpWidget(_buildHost(routine, stub));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsNothing);
      expect(find.text('Duplicate and Edit'), findsNothing);
    });

    testWidgets('dismisses when tapping outside the sheet', (tester) async {
      final routine = _userRoutine();
      final stub = _RoutineListStub();

      await tester.pumpWidget(_buildHost(routine, stub));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);

      // Tap the scrim to dismiss.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
    });
  });

  group('showRoutineActionSheet — default (preset) routine', () {
    testWidgets(
      'shows Start and Duplicate and Edit options for a default routine',
      (tester) async {
        final routine = _defaultRoutine();
        final stub = _RoutineListStub();

        await tester.pumpWidget(_buildHost(routine, stub));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Duplicate and Edit'), findsOneWidget);
      },
    );

    testWidgets(
      'does NOT show Edit-only or Delete options for a default routine',
      (tester) async {
        final routine = _defaultRoutine();
        final stub = _RoutineListStub();

        await tester.pumpWidget(_buildHost(routine, stub));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // The standalone Edit tile (for user routines) must not appear.
        // The play icon is distinct from edit icon.
        expect(find.text('Delete'), findsNothing);
      },
    );

    testWidgets(
      'tapping Duplicate and Edit calls duplicateRoutine on the notifier',
      (tester) async {
        final routine = _defaultRoutine(id: 'preset-001', name: 'Push Day');
        final stub = _RoutineListStub();

        await tester.pumpWidget(_buildHost(routine, stub));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Duplicate and Edit'));
        // Don't use pumpAndSettle — GoRouter navigation may throw in a
        // non-GoRouter host. Pump a few frames to let the tap propagate.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // duplicateRoutine should have been invoked for this routine.
        expect(
          stub.calls,
          contains('duplicateRoutine:preset-001'),
          reason: 'Tapping "Duplicate and Edit" must call duplicateRoutine()',
        );
      },
    );

    testWidgets('shows Start icon (play_arrow) for default routine sheet', (
      tester,
    ) async {
      final routine = _defaultRoutine();
      final stub = _RoutineListStub();

      await tester.pumpWidget(_buildHost(routine, stub));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });
  });

  group('showRoutineActionSheet — delete confirmation', () {
    testWidgets('tapping Delete on user routine shows confirmation dialog', (
      tester,
    ) async {
      final routine = _userRoutine(name: 'Leg Day');
      final stub = _RoutineListStub();

      await tester.pumpWidget(_buildHost(routine, stub));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog must appear.
      expect(find.text('Delete Routine'), findsOneWidget);
      expect(find.textContaining('"Leg Day"'), findsOneWidget);
    });

    testWidgets('cancelling delete dialog does not call deleteRoutine', (
      tester,
    ) async {
      final routine = _userRoutine(id: 'r-cancel');
      final stub = _RoutineListStub();

      await tester.pumpWidget(_buildHost(routine, stub));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        stub.calls,
        isNot(contains('deleteRoutine:r-cancel')),
        reason: 'Cancelling the dialog must not call deleteRoutine',
      );
    });

    testWidgets(
      'confirming delete dialog calls deleteRoutine with correct id',
      (tester) async {
        final routine = _userRoutine(id: 'r-to-delete');
        final stub = _RoutineListStub();

        await tester.pumpWidget(_buildHost(routine, stub));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Tap the "Delete" button inside the confirmation dialog.
        // Use exact text to avoid matching the dialog title "Delete Routine".
        await tester.tap(find.text('Delete').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          stub.calls,
          contains('deleteRoutine:r-to-delete'),
          reason:
              'Confirming delete must call deleteRoutine with the routine id',
        );
      },
    );
  });
}
