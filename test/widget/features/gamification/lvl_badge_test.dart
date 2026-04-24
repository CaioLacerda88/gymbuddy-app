/// Widget tests for the _LvlBadge placeholder added in Phase 17b
/// (retained through the Phase 17.0c Arcane Ascent material migration).
///
/// The badge is a minimal ConsumerWidget inside HomeScreen that watches
/// xpProvider and renders "LVL {n}" using `AppTextStyles.label` tinted
/// with `AppColors.hotViolet` — the Arcane structural accent. Gold
/// (`heroGold` via `RewardAccent`) is reserved for level-up celebration,
/// PR flashes, and streak milestones.
///
/// Full styling and animation land in Phase 17e; these tests verify:
///   - LVL 1 renders while xpProvider is loading
///   - LVL 1 renders on error
///   - Correct level renders when xpProvider emits data
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/gamification/data/xp_repository.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';
import 'package:repsaga/features/gamification/models/xp_breakdown.dart';
import 'package:repsaga/features/gamification/models/xp_state.dart';
import 'package:repsaga/features/gamification/providers/xp_provider.dart';

import '../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Fake XpRepository implementations
// ---------------------------------------------------------------------------

class _FakeXpRepo implements XpRepository {
  _FakeXpRepo({required this.summary});

  final GamificationSummary summary;

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
  Future<void> runRetroBackfill(String userId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Never resolves — keeps xpProvider in AsyncLoading.
class _LoadingXpRepo implements XpRepository {
  @override
  Future<GamificationSummary> getSummary() {
    final completer = Completer<GamificationSummary>();
    // intentionally not completed so the provider stays loading.
    return completer.future;
  }

  @override
  Future<GamificationSummary> awardXp({
    required String userId,
    required XpBreakdown breakdown,
    required String source,
    String? workoutId,
  }) async => GamificationSummary.empty;

  @override
  Future<void> runRetroBackfill(String userId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Throws on getSummary — drives xpProvider into AsyncError.
class _ErrorXpRepo implements XpRepository {
  @override
  Future<GamificationSummary> getSummary() async =>
      throw Exception('network error');

  @override
  Future<GamificationSummary> awardXp({
    required String userId,
    required XpBreakdown breakdown,
    required String source,
    String? workoutId,
  }) async => GamificationSummary.empty;

  @override
  Future<void> runRetroBackfill(String userId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Minimal badge widget (mirrors _LvlBadge from home_screen.dart).
// _LvlBadge is private so we replicate behaviour in a test-only widget
// that uses the same provider and helper.
// ---------------------------------------------------------------------------

class _BadgeTestWidget extends ConsumerWidget {
  const _BadgeTestWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(xpProvider);
    final level = currentLevelOrDefault(summaryAsync);
    return Semantics(
      identifier: 'lvl-badge',
      label: 'LVL $level',
      child: Text('LVL $level'),
    );
  }
}

Widget _buildBadge(XpRepository repo) {
  return ProviderScope(
    overrides: [xpRepositoryProvider.overrideWithValue(repo)],
    child: const TestMaterialApp(home: Scaffold(body: _BadgeTestWidget())),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('_LvlBadge (Phase 17b placeholder)', () {
    testWidgets('renders LVL 1 while xpProvider is loading', (tester) async {
      await tester.pumpWidget(_buildBadge(_LoadingXpRepo()));
      // First pump — AsyncLoading state; the future never resolves in this test.
      await tester.pump();

      expect(find.text('LVL 1'), findsOneWidget);
    });

    testWidgets('renders LVL 1 when xpProvider errors', (tester) async {
      await tester.pumpWidget(_buildBadge(_ErrorXpRepo()));
      // Allow the error future to propagate.
      await tester.pump();
      await tester.pump();

      expect(find.text('LVL 1'), findsOneWidget);
    });

    testWidgets('renders correct level when xpProvider emits level 7', (
      tester,
    ) async {
      const summary = GamificationSummary(
        totalXp: 3700,
        currentLevel: 7,
        xpIntoLevel: 0,
        xpToNext: 100,
        rank: Rank.iron,
      );
      await tester.pumpWidget(_buildBadge(_FakeXpRepo(summary: summary)));
      await tester.pump();

      expect(find.text('LVL 7'), findsOneWidget);
      expect(find.text('LVL 1'), findsNothing);
    });

    testWidgets('renders LVL 1 for a fresh user (totalXp = 0)', (tester) async {
      await tester.pumpWidget(
        _buildBadge(_FakeXpRepo(summary: GamificationSummary.empty)),
      );
      await tester.pump();

      expect(find.text('LVL 1'), findsOneWidget);
    });
  });
}
