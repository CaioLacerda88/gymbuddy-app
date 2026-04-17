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

    testWidgets('tapping Dismiss calls dismissTerminalItems on notifier', (
      tester,
    ) async {
      final trackingService = _TrackingSyncService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncServiceProvider.overrideWith(() => trackingService),
            isOnlineProvider.overrideWithValue(true),
            onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: SyncFailureCard())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dismiss'), findsOneWidget);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(trackingService.dismissCalled, isTrue);
    });

    testWidgets('tapping Retry while online calls retryTerminalItems', (
      tester,
    ) async {
      final trackingService = _TrackingSyncService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncServiceProvider.overrideWith(() => trackingService),
            isOnlineProvider.overrideWithValue(true),
            onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: SyncFailureCard())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(trackingService.retryCalled, isTrue);
    });

    // Note: the "Retry while offline" snackbar path (_handleRetry guard) is not
    // testable via the widget because the card hides itself (returns
    // SizedBox.shrink) whenever isOnlineProvider is false, which means the
    // Retry button is never rendered while the guard would trigger.
    // The guard is a safety net for the edge case where connectivity drops
    // between the card rendering and the tap completing. It is covered by
    // code inspection; no additional widget test is warranted.
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

/// Tracking fake that records which action methods were called.
class _TrackingSyncService extends SyncService {
  bool dismissCalled = false;
  bool retryCalled = false;

  @override
  SyncState build() => const SyncState(terminalFailureCount: 2);

  @override
  Future<void> dismissTerminalItems() async {
    dismissCalled = true;
    state = const SyncState();
  }

  @override
  Future<void> retryTerminalItems() async {
    retryCalled = true;
  }
}
