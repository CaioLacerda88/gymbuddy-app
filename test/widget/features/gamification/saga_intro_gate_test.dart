import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/gamification/data/xp_repository.dart';
import 'package:repsaga/features/gamification/models/xp_breakdown.dart';
import 'package:repsaga/features/gamification/models/xp_state.dart';
import 'package:repsaga/features/gamification/providers/xp_provider.dart';
import 'package:repsaga/features/gamification/ui/saga_intro_gate.dart';

import '../../../helpers/test_material_app.dart';

class _FakeXpRepository implements XpRepository {
  _FakeXpRepository();

  final GamificationSummary summary = GamificationSummary.empty;
  int retroCalls = 0;

  @override
  Future<GamificationSummary> getSummary() async => summary;

  @override
  Future<GamificationSummary> awardXp({
    required String userId,
    required XpBreakdown breakdown,
    required String source,
    String? workoutId,
  }) async => summary;

  @override
  Future<void> runRetroBackfill(String userId) async {
    retroCalls += 1;
  }

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
  required _FakeXpRepository repo,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          xpRepositoryProvider.overrideWithValue(repo),
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
      final repo = _FakeXpRepository();
      await _pumpGate(tester, userId: null, repo: repo);

      expect(find.text('CHILD'), findsOneWidget);
      expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsNothing);
      expect(repo.retroCalls, 0);
    });

    testWidgets('first mount kicks retro then shows overlay on top of child', (
      tester,
    ) async {
      final repo = _FakeXpRepository();
      await _pumpGate(tester, userId: 'user-1', repo: repo);

      expect(repo.retroCalls, 1);
      expect(hasRunRetroForUser('user-1'), isTrue);
      expect(find.text('CHILD'), findsOneWidget);
      expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsOneWidget);
    });

    testWidgets(
      'second mount (intro already seen) shows no overlay and does not re-run retro',
      (tester) async {
        await tester.runAsync(() async {
          await markSagaIntroSeenForUser('user-2');
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:user-2', true);
        });

        final repo = _FakeXpRepository();
        await _pumpGate(tester, userId: 'user-2', repo: repo);

        expect(repo.retroCalls, 0);
        expect(find.text('CHILD'), findsOneWidget);
        expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsNothing);
      },
    );

    testWidgets(
      'retro already done but intro unseen → overlay appears without re-running retro',
      (tester) async {
        await tester.runAsync(() async {
          final box = Hive.box<dynamic>('user_prefs');
          await box.put('saga_retro_run:user-3', true);
        });

        final repo = _FakeXpRepository();
        await _pumpGate(tester, userId: 'user-3', repo: repo);

        expect(repo.retroCalls, 0);
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

        final repo = _FakeXpRepository();
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
}
