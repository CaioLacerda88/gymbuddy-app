import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/core/offline/offline_queue_service.dart';
import 'package:repsaga/core/offline/pending_action.dart';
import 'package:repsaga/shared/widgets/pending_sync_sheet.dart';

import '../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// BUG-008: PendingSyncSheet shows the right CTA per action.errorCategory
//
// - errorCategory in {none, network, transient, unknown} -> "Retry" button
// - errorCategory in {structural, session} -> "Dismiss" button plus a body
//   line with the canned structural copy.
//
// `unknown` is intentionally permissive (PR #127 review): a genuinely
// unfamiliar exception class might be a one-off transient crash that
// retry resolves; if the underlying issue is actually structural, the next
// attempt surfaces a more specific exception class that the mapper routes
// to `structural` and the CTA flips to Dismiss then.
//
// We seed the offline queue Hive box directly with pre-classified actions
// (the production write path goes through SyncErrorMapper.classifyCategory
// inside PendingSyncNotifier.retryItem; that path is covered by the
// notifier unit tests). The sheet is what we exercise here.
//
// Two important testing constraints:
//
// 1. PendingSyncSheet uses a DraggableScrollableSheet, which requires an
//    unbounded-height parent (otherwise its animation controller schedules
//    frames indefinitely and the test hangs). Production mounts the sheet
//    via showModalBottomSheet (see PendingSyncBadge._showSyncSheet); we
//    mirror that here so the sheet has the right layout context.
//
// 2. Hive.box.put completes on Dart's real event loop, not the fake async
//    pumped by testWidgets. Anything that touches Hive (the seeding
//    enqueue and any pump that reads the box) must run inside
//    tester.runAsync, otherwise the pending I/O future is tracked by the
//    test zone and the test never reports "complete".
// ---------------------------------------------------------------------------
void main() {
  group('PendingSyncSheet — BUG-008 CTA per error category', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_sync_sheet_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(HiveService.offlineQueue);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    PendingSaveWorkout seedSaveWorkout({
      required String id,
      required SyncErrorCategory category,
    }) {
      return PendingAction.saveWorkout(
            id: id,
            workoutJson: {'id': id},
            exercisesJson: const [],
            setsJson: const [],
            userId: 'user-1',
            queuedAt: DateTime.utc(2026, 4, 17, 12, 0, 0),
            retryCount: 1,
            lastError: 'previous failure',
            errorCategory: category,
          )
          as PendingSaveWorkout;
    }

    Widget buildHost() {
      return ProviderScope(
        child: TestMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const PendingSyncSheet(),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> seedAndOpen(
      WidgetTester tester,
      PendingSaveWorkout action,
    ) async {
      await tester.runAsync(() async {
        const queue = OfflineQueueService();
        await queue.enqueue(action);

        await tester.pumpWidget(buildHost());
        // Real-time delay so the box write settles before the first pump
        // reads pendingSyncProvider's count.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        await tester.tap(find.text('Open'));
        // Bounded settle so a runaway animation fails fast (2s) instead of
        // the default 10-minute test timeout.
        await tester.pumpAndSettle(const Duration(seconds: 2));
      });
    }

    testWidgets('structural error shows Dismiss CTA and structural body copy', (
      tester,
    ) async {
      await seedAndOpen(
        tester,
        seedSaveWorkout(
          id: 'w-structural',
          category: SyncErrorCategory.structural,
        ),
      );

      // CTA: "Dismiss" — the en ARB string is exact.
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      // Body copy: canned structural error message.
      expect(
        find.text("We couldn't send this — please contact support."),
        findsOneWidget,
      );
    });

    testWidgets('transient error keeps Retry CTA and no structural body copy', (
      tester,
    ) async {
      await seedAndOpen(
        tester,
        seedSaveWorkout(
          id: 'w-transient',
          category: SyncErrorCategory.transient,
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Dismiss'), findsNothing);

      // No structural body copy when we still expect retry to help.
      expect(
        find.text("We couldn't send this — please contact support."),
        findsNothing,
      );
    });

    testWidgets(
      'session-expired error shows Dismiss CTA (treated as terminal)',
      (tester) async {
        await seedAndOpen(
          tester,
          seedSaveWorkout(id: 'w-session', category: SyncErrorCategory.session),
        );

        expect(find.text('Dismiss'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    // PR #127 review: unknown is non-terminal — retry might still resolve
    // a one-off plugin crash, and forcing Dismiss removes the user's
    // recovery path. If the issue is genuinely structural the next attempt
    // surfaces a specific exception class that re-classifies and flips
    // the CTA on its own.
    testWidgets(
      'unknown error keeps Retry CTA (non-terminal, permissive policy)',
      (tester) async {
        await seedAndOpen(
          tester,
          seedSaveWorkout(id: 'w-unknown', category: SyncErrorCategory.unknown),
        );

        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Dismiss'), findsNothing);

        // No structural body copy when retry is still the offered path.
        expect(
          find.text("We couldn't send this — please contact support."),
          findsNothing,
        );
      },
    );
  });
}
