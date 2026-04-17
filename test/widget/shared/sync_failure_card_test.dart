import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/connectivity/connectivity_provider.dart';
import 'package:gymbuddy_app/core/offline/sync_service.dart';
import 'package:gymbuddy_app/shared/widgets/sync_failure_card.dart';

void main() {
  group('SyncFailureCard', () {
    Widget buildSubject({required int terminalCount, bool isOnline = true}) {
      return ProviderScope(
        overrides: [
          syncServiceProvider.overrideWith(
            () => _TestSyncService(terminalCount),
          ),
          isOnlineProvider.overrideWithValue(isOnline),
          // Provide onlineStatusProvider so isOnlineProvider's upstream
          // doesn't attempt real connectivity checks.
          onlineStatusProvider.overrideWith((ref) => Stream.value(isOnline)),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncFailureCard())),
      );
    }

    testWidgets('renders nothing when terminalFailureCount is 0', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(terminalCount: 0));
      await tester.pumpAndSettle();

      expect(find.byType(SyncFailureCard), findsOneWidget);
      expect(find.text("Workout couldn't sync"), findsNothing);
      expect(find.text('Saved locally. Retry or dismiss.'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('renders failure card when terminalFailureCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(terminalCount: 3));
      await tester.pumpAndSettle();

      expect(find.text("3 workouts couldn't sync"), findsOneWidget);
      expect(find.text('Saved locally. Retry or dismiss.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('singular copy for 1 failure', (tester) async {
      await tester.pumpWidget(buildSubject(terminalCount: 1));
      await tester.pumpAndSettle();

      expect(find.text("Workout couldn't sync"), findsOneWidget);
    });

    testWidgets('plural copy for multiple failures', (tester) async {
      await tester.pumpWidget(buildSubject(terminalCount: 2));
      await tester.pumpAndSettle();

      expect(find.text("2 workouts couldn't sync"), findsOneWidget);
    });

    testWidgets('hidden when offline even with terminal failures', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(terminalCount: 3, isOnline: false));
      await tester.pumpAndSettle();

      expect(find.text("3 workouts couldn't sync"), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
    });
  });
}

/// Minimal fake that returns a [SyncState] with a given terminal count
/// without triggering real connectivity or queue logic.
class _TestSyncService extends SyncService {
  _TestSyncService(this._count);
  final int _count;

  @override
  SyncState build() => SyncState(terminalFailureCount: _count);
}
