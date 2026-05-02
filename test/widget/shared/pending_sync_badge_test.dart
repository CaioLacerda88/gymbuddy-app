import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/offline/pending_action.dart';
import 'package:repsaga/core/offline/pending_sync_provider.dart';
import 'package:repsaga/shared/widgets/pending_sync_badge.dart';
import '../../helpers/test_material_app.dart';

void main() {
  group('PendingSyncBadge', () {
    Widget buildSubject({required int pendingCount}) {
      return ProviderScope(
        overrides: [
          pendingSyncProvider.overrideWith(() => _FakeNotifier(pendingCount)),
        ],
        child: const TestMaterialApp(home: Scaffold(body: PendingSyncBadge())),
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

    // BUG-021: Semantics label was hardcoded English. The badge must compose
    // the localized visible label through `pendingSyncBadgeSemantics(label)`
    // so screen-readers in pt-BR don't read English while the visible text
    // is Portuguese. We pin the composed string by walking the Semantics
    // tree under the badge and reading the merged label off the node that
    // carries the `offline-pending-badge` identifier.
    testWidgets('exposes localized Semantics label (BUG-021)', (tester) async {
      await tester.pumpWidget(buildSubject(pendingCount: 2));
      await tester.pumpAndSettle();

      // Walk the merged semantics tree depth-first from the badge's
      // [Semantics] node and look for any descendant whose label contains
      // the localized hint suffix the widget composes via
      // `pendingSyncBadgeSemantics(label)` ("{label}. Tap to manage."). The
      // badge merges its container into ancestor nodes, so we start from
      // the badge's containing widget rather than the [Semantics] widget
      // directly. `getSemantics` enables semantics for the duration of the
      // test internally — no explicit `ensureSemantics()` needed.
      final node = tester.getSemantics(find.byType(PendingSyncBadge));

      bool labelMatches(SemanticsNode n) {
        final data = n.getSemanticsData();
        if (data.label.contains('Tap to manage') &&
            data.label.contains('2 workouts pending sync')) {
          return true;
        }
        var found = false;
        n.visitChildren((child) {
          if (labelMatches(child)) {
            found = true;
            return false;
          }
          return true;
        });
        return found;
      }

      expect(
        labelMatches(node),
        isTrue,
        reason:
            'Expected the badge to expose a localized semantics label of the '
            'form "{plural label}. Tap to manage." but no merged node '
            'matched. Hardcoded English label regression (BUG-021).',
      );
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
