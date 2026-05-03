/// Widget tests for [SagaIntroGate] (Phase 18 follow-ups rewire).
///
/// The gate previously hung off the legacy gamification `xpProvider`.
/// After deleting `lib/features/gamification/`, the gate reads from
/// `rpgProgressProvider` and triggers backfill via `RpgRepository.runBackfill`
/// (which loops `backfill_rpg_v1` server-side — same procedure the legacy
/// shim called, just routed through the canonical RPG repo).
///
/// Tests pin the contract:
///   - unauthenticated → no overlay, no backfill kick
///   - first mount kicks backfill, persists `saga_retro_run:` flag, shows
///     overlay
///   - second mount with `saga_intro_seen:` flag set → no overlay, no
///     re-kick
///   - retro already done but intro unseen → overlay only, no backfill
///   - dismiss persists `saga_intro_seen:` and prevents re-show
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/rpg/data/rpg_repository.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/body_part_progress.dart';
import 'package:repsaga/features/rpg/models/xp_event.dart';
import 'package:repsaga/features/rpg/providers/rpg_progress_provider.dart';
import 'package:repsaga/features/rpg/ui/saga_intro_gate.dart';

import '../../../../helpers/test_material_app.dart';

class _FakeRpgRepository implements RpgRepository {
  _FakeRpgRepository();

  int backfillCalls = 0;

  @override
  Future<List<BodyPartProgress>> getAllBodyPartProgress() async {
    return const <BodyPartProgress>[];
  }

  @override
  Future<BodyPartProgress?> getBodyPartProgress(BodyPart bodyPart) async {
    return null;
  }

  @override
  Future<CharacterState> getCharacterState() async {
    return CharacterState.empty;
  }

  @override
  Future<List<XpEvent>> getRecentXpEvents({
    int limit = 50,
    DateTime? olderThan,
  }) async {
    return const <XpEvent>[];
  }

  @override
  Future<List<XpEvent>> getXpEventsForSession(String sessionId) async {
    return const <XpEvent>[];
  }

  @override
  Future<int> runBackfill({int chunkSize = 500}) async {
    backfillCalls += 1;
    return 0;
  }

  @override
  Future<BackfillProgress?> getBackfillProgress() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChildMarker extends StatelessWidget {
  const _ChildMarker();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('CHILD')));
}

// The gate triggers Hive writes as a side-effect of retro-backfill and of
// dismissing the overlay. Hive.box.put completes on Dart's real event loop,
// not the fake async pumped by testWidgets, so any widget pump that touches
// Hive must run inside tester.runAsync — otherwise the pending I/O future is
// tracked by the test zone and the test never reports "complete".
Future<void> _pumpGate(
  WidgetTester tester, {
  required String? userId,
  required _FakeRpgRepository repo,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          rpgRepositoryProvider.overrideWithValue(repo),
        ],
        child: const TestMaterialApp(
          home: SagaIntroGate(child: _ChildMarker()),
        ),
      ),
    );
    // One microtask drain for fake async (state hydration), then a real-time
    // delay to let Hive's write-queue settle and the AsyncNotifier transition
    // out of AsyncLoading.
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  });
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('saga_gate_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('user_prefs');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('SagaIntroGate', () {
    testWidgets('renders only child when user is unauthenticated', (
      tester,
    ) async {
      final repo = _FakeRpgRepository();
      await _pumpGate(tester, userId: null, repo: repo);

      expect(find.text('CHILD'), findsOneWidget);
      expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsNothing);
      expect(repo.backfillCalls, 0);
    });

    testWidgets(
      'first mount kicks backfill then shows overlay on top of child',
      (tester) async {
        final repo = _FakeRpgRepository();
        await _pumpGate(tester, userId: 'user-1', repo: repo);

        expect(repo.backfillCalls, 1);
        expect(hasRunRetroForUser('user-1'), isTrue);
        expect(find.text('CHILD'), findsOneWidget);
        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsOneWidget);
      },
    );

    testWidgets(
      'second mount (intro already seen) shows no overlay and does not re-run backfill',
      (tester) async {
        await tester.runAsync(() async {
          await markSagaIntroSeenForUser('user-2');
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:user-2', true);
        });

        final repo = _FakeRpgRepository();
        await _pumpGate(tester, userId: 'user-2', repo: repo);

        expect(repo.backfillCalls, 0);
        expect(find.text('CHILD'), findsOneWidget);
        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsNothing);
      },
    );

    testWidgets(
      'retro already done but intro unseen → overlay appears without re-running backfill',
      (tester) async {
        await tester.runAsync(() async {
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:user-3', true);
        });

        final repo = _FakeRpgRepository();
        await _pumpGate(tester, userId: 'user-3', repo: repo);

        expect(repo.backfillCalls, 0);
        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsOneWidget);
      },
    );

    testWidgets(
      'dismissing overlay persists the seen flag and unmount/remount does not re-show',
      (tester) async {
        await tester.runAsync(() async {
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:user-4', true);
        });

        final repo = _FakeRpgRepository();
        await _pumpGate(tester, userId: 'user-4', repo: repo);

        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsOneWidget);

        await tester.runAsync(() async {
          await tester.tap(find.text('NEXT'));
          await tester.pump();
          await tester.tap(find.text('NEXT'));
          await tester.pump();
          await tester.tap(find.text('BEGIN'));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        });

        expect(hasSeenSagaIntroForUser('user-4'), isTrue);
        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsNothing);
        expect(find.text('CHILD'), findsOneWidget);

        // Simulate remount by pumping a fresh widget tree.
        await _pumpGate(tester, userId: 'user-4', repo: repo);

        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsNothing);
        expect(find.text('CHILD'), findsOneWidget);
      },
    );
  });

  group('hasSeenSagaIntroForUser / markSagaIntroSeenForUser', () {
    test('hasSeenSagaIntroForUser defaults to false for an untouched user', () {
      expect(hasSeenSagaIntroForUser('user-abc'), isFalse);
    });

    test(
      'markSagaIntroSeenForUser flips the flag for that user only',
      () async {
        await markSagaIntroSeenForUser('user-abc');
        expect(hasSeenSagaIntroForUser('user-abc'), isTrue);
        expect(hasSeenSagaIntroForUser('user-xyz'), isFalse);
      },
    );

    test('a second launch after dismiss still reports true '
        '(persistence across provider re-reads)', () async {
      await markSagaIntroSeenForUser('user-abc');
      // Simulate a "second launch" by re-checking. Hive is backed by the
      // same temp box, so the flag must persist.
      expect(hasSeenSagaIntroForUser('user-abc'), isTrue);
    });
  });

  group('hasRunRetroForUser', () {
    test('defaults to false for an untouched user', () {
      expect(hasRunRetroForUser('user-001'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // BUG-012 (Cluster 3) — saga-intro / celebration sequencing
  //
  // The sequencer ensures the celebration queue waits for intro dismissal
  // before draining. Two paths:
  //   * already-seen user: future resolves on first gate mount
  //   * fresh user: future resolves on dismiss (BEGIN tap)
  // ---------------------------------------------------------------------------
  group('SagaIntroSequencer (BUG-012)', () {
    setUp(() {
      // Reset between tests so each test gets a fresh per-user completer.
      SagaIntroSequencer.resetForTesting();
    });

    testWidgets(
      'returning user (intro already seen) → sequencer resolves immediately on '
      'first gate mount',
      (tester) async {
        await tester.runAsync(() async {
          await markSagaIntroSeenForUser('seq-1');
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:seq-1', true);
        });

        // Subscribe BEFORE pumping the gate so we observe the resolution
        // on the first build (idempotency check).
        final future = SagaIntroSequencer.waitForIntroDismissed('seq-1');
        var resolved = false;
        unawaited(future.then((_) => resolved = true));

        final repo = _FakeRpgRepository();
        await _pumpGate(tester, userId: 'seq-1', repo: repo);
        // Drain microtasks so the .then callback fires.
        await tester.runAsync(() async {});
        await tester.pump();

        expect(resolved, isTrue);
      },
    );

    testWidgets(
      'fresh user → sequencer remains pending until BEGIN tap, then resolves',
      (tester) async {
        await tester.runAsync(() async {
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:seq-2', true);
        });

        var resolved = false;
        unawaited(
          SagaIntroSequencer.waitForIntroDismissed(
            'seq-2',
          ).then((_) => resolved = true),
        );

        final repo = _FakeRpgRepository();
        await _pumpGate(tester, userId: 'seq-2', repo: repo);
        // Intro is showing — sequencer should NOT have resolved yet.
        await tester.runAsync(() async {});
        await tester.pump();
        expect(resolved, isFalse);

        // Dismiss the intro via the full step sequence.
        await tester.runAsync(() async {
          await tester.tap(find.text('NEXT'));
          await tester.pump();
          await tester.tap(find.text('NEXT'));
          await tester.pump();
          await tester.tap(find.text('BEGIN'));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        });

        // Sequencer fires on dismiss.
        expect(resolved, isTrue);
      },
    );

    testWidgets('duplicate dismissals are no-ops (idempotent completer)', (
      tester,
    ) async {
      // The completer is single-fire by construction. A double-dismiss
      // (e.g. session re-mount after Hive flag was set in another tab)
      // must not throw. This pins the safe behaviour.
      SagaIntroSequencer.markIntroDismissedForSequencer('seq-3');
      // Should not throw on the second call.
      SagaIntroSequencer.markIntroDismissedForSequencer('seq-3');

      final future = SagaIntroSequencer.waitForIntroDismissed('seq-3');
      // Future is already complete.
      await expectLater(future, completes);
    });

    testWidgets(
      'per-user isolation: user A completing intro does not affect user B '
      '(sign-out → sign-in scenario)',
      (tester) async {
        // Production scenario: user A uses the app, dismisses the intro
        // (completer for "user-A" is resolved). User A signs out. User B
        // signs in on the same device. User B has NOT dismissed the intro
        // yet — their completer must start PENDING, not inherit user A's
        // completed state.
        //
        // Why this matters: `_completersByUser` is a static map keyed by
        // userId. Each key is independent, so user B's completer is lazily
        // created the first time `waitForIntroDismissed('user-B')` is
        // called — it never touches user A's slot. This test pins that
        // isolation contract.

        // User A: mark intro dismissed (simulates prior session or sign-out
        // then sign back in for user A).
        SagaIntroSequencer.markIntroDismissedForSequencer('switch-user-A');
        final futureA = SagaIntroSequencer.waitForIntroDismissed(
          'switch-user-A',
        );
        await tester.runAsync(() async {});
        await tester.pump();
        // User A's future must be complete.
        var resolvedA = false;
        unawaited(futureA.then((_) => resolvedA = true));
        await tester.runAsync(() async {});
        await tester.pump();
        expect(resolvedA, isTrue);

        // User B: new user signs in. Their completer has never been touched.
        var resolvedB = false;
        unawaited(
          SagaIntroSequencer.waitForIntroDismissed(
            'switch-user-B',
          ).then((_) => resolvedB = true),
        );
        await tester.runAsync(() async {});
        await tester.pump();
        // User B's future must still be PENDING — user A's resolved state
        // must NOT have leaked across to user B's key.
        expect(resolvedB, isFalse);

        // Confirm resolution fires when user B's gate marks dismissed.
        SagaIntroSequencer.markIntroDismissedForSequencer('switch-user-B');
        await tester.runAsync(() async {});
        await tester.pump();
        expect(resolvedB, isTrue);
      },
    );
  });

  // The ladder is the source of truth for the saga intro overlay's
  // "LVL N — RANK" preview. Pin each tier so future ladder edits surface as
  // test failures instead of silent UI regressions for existing lifters.
  group('rankSlugFromLifetimeXp', () {
    test('returns diamond at and above the top threshold (250_000)', () {
      expect(rankSlugFromLifetimeXp(300000), 'diamond');
    });

    test('returns platinum between 125_000 and 250_000', () {
      expect(rankSlugFromLifetimeXp(150000), 'platinum');
    });

    test('returns iron between 2_500 and 10_000', () {
      // 5_000 sits in [2_500, 10_000) → iron tier.
      expect(rankSlugFromLifetimeXp(5000), 'iron');
    });

    test('returns rookie at the 0 floor', () {
      expect(rankSlugFromLifetimeXp(0), 'rookie');
    });
  });
}
