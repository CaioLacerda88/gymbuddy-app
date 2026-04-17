import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/offline/pending_action.dart';
import 'package:gymbuddy_app/core/offline/pending_sync_provider.dart';
import 'package:gymbuddy_app/shared/widgets/pending_sync_badge.dart';

void main() {
  group('PendingSyncBadge', () {
    Widget buildSubject({required int pendingCount}) {
      return ProviderScope(
        overrides: [
          pendingSyncProvider.overrideWith(() => _FakeNotifier(pendingCount)),
        ],
        child: const MaterialApp(home: Scaffold(body: PendingSyncBadge())),
      );
    }

    testWidgets('renders nothing when count is 0', (tester) async {
      await tester.pumpWidget(buildSubject(pendingCount: 0));
      await tester.pumpAndSettle();

      expect(find.byType(PendingSyncBadge), findsOneWidget);
      // The badge should render SizedBox.shrink — no text visible.
      expect(find.text('0 workouts pending sync'), findsNothing);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    });

    testWidgets('shows "1 workout pending sync" when count is 1', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(pendingCount: 1));
      await tester.pumpAndSettle();

      expect(find.text('1 workout pending sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('shows "3 workouts pending sync" when count is 3', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(pendingCount: 3));
      await tester.pumpAndSettle();

      expect(find.text('3 workouts pending sync'), findsOneWidget);
    });

    testWidgets('tap opens bottom sheet', (tester) async {
      await tester.pumpWidget(buildSubject(pendingCount: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 workout pending sync'));
      await tester.pumpAndSettle();

      // The PendingSyncSheet should appear as a bottom sheet.
      // It shows "Pending Sync" title and "All synced!" since the fake
      // notifier getAll returns empty.
      expect(find.text('Pending Sync'), findsOneWidget);
    });
  });
}

class _FakeNotifier extends PendingSyncNotifier {
  _FakeNotifier(this._count);
  final int _count;

  @override
  int build() => _count;

  @override
  List<PendingAction> getAll() => const [];
}
