/// Integration tests for Phase 18a `record_set_xp` RPC.
///
/// Requires local Supabase running: `npx supabase start`
///
/// Each test gets its own isolated Supabase user (created in setUp, deleted in
/// tearDown) so tests never share mutable state.
///
/// What these tests validate:
///
/// 1. **PG/Dart parity** — for the same (weight, reps, exercise) inputs, the
///    `record_set_xp` Postgres function and the Dart `XpCalculator` produce
///    `body_part_progress.total_xp` within 0.01 of each other.
///
/// 2. **Re-save idempotency (BUG-RPG-001 regression)** — saving the same
///    workout twice must NOT double `body_part_progress.total_xp`. The fix
///    is the REVERSAL PATTERN inside `save_workout`: before cascading the
///    prior sets, decrement body_part_progress by the contribution of the
///    xp_events linked to this session, then let record_set_xp re-add from
///    scratch.
///
/// 3. **Concurrent same-set guard** — two concurrent `record_set_xp` calls for
///    the same set_id produce exactly one xp_events row.
///
/// 4. **exercise_peak_loads advancement** — new PR advances peak; deload
///    does not regress it.
///
/// Run: flutter test --tags integration test/integration/rpg_record_set_xp_test.dart
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/domain/xp_calculator.dart';
import 'package:repsaga/features/rpg/domain/xp_distribution.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';

import 'rpg_integration_setup.dart';

void main() {
  // Unique suffix per test run to avoid email conflicts on reruns.
  final runId = DateTime.now().millisecondsSinceEpoch;
  var testIdx = 0;

  // Each test creates and destroys its own user for full isolation.
  TestUser? currentUser;

  Future<TestUser> freshUser() async {
    final idx = testIdx++;
    final u = await createTestUser('rpg-rsx-$runId-$idx@test.local');
    currentUser = u;
    return u;
  }

  tearDown(() async {
    if (currentUser != null) {
      await deleteTestUser(currentUser!.userId);
      currentUser = null;
    }
  });

  // ---------------------------------------------------------------------------
  // PG/Dart parity
  // ---------------------------------------------------------------------------

  group('record_set_xp PG/Dart parity', () {
    /// Bench press 60kg×8 (fresh first set, no prior peak).
    /// Attribution: chest 0.70, shoulders 0.20, arms 0.10.
    test(
      'bench press 60kg×8: body_part_progress matches Dart calculator',
      () async {
        const slug = 'barbell_bench_press';
        const weight = 60.0;
        const reps = 8;

        final user = await freshUser();
        final adminClient = serviceRoleClient();
        final userClient = authenticatedClient(user);

        final seed = await seedWorkout(
          adminClient: adminClient,
          userId: user.userId,
          exerciseSlug: slug,
          weightKg: weight,
          reps: reps,
          numSets: 1,
        );
        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: weight,
          reps: reps,
          numSets: 1,
        );

        // Dart: fresh first set, no prior peak → strength_mult = 1.0
        final dartComps = XpCalculator.computeSetXp(
          weightKg: weight,
          reps: reps,
          peakLoad: 0,
          sessionVolumeForBodyPart: 0,
          weeklyVolumeForBodyPart: 0,
        );
        final dartXp = XpDistribution.distribute(
          setXp: dartComps.setXp,
          attribution: Attribution.fromMap({
            'chest': 0.70,
            'shoulders': 0.20,
            'arms': 0.10,
          }),
        );

        final pgRows = await userClient
            .from('body_part_progress')
            .select('body_part, total_xp')
            .order('body_part');
        final pgByBp = {
          for (final row in pgRows as List)
            (row as Map<String, dynamic>)['body_part'] as String: row,
        };

        for (final bp in [BodyPart.chest, BodyPart.shoulders, BodyPart.arms]) {
          final dartXpBp = dartXp[bp]!;
          final pgRow = pgByBp[bp.dbValue];
          expect(
            pgRow,
            isNotNull,
            reason: 'Expected body_part_progress row for ${bp.dbValue}',
          );
          final pgXp = (pgRow!['total_xp'] as num).toDouble();
          expect(
            (pgXp - dartXpBp).abs(),
            lessThanOrEqualTo(_kTol),
            reason:
                '${bp.dbValue}: PG=$pgXp vs Dart=$dartXpBp '
                '(delta ${(pgXp - dartXpBp).abs().toStringAsFixed(6)})',
          );
        }

        // xp_events: exactly one row.
        final events = await userClient
            .from('xp_events')
            .select('id')
            .eq('set_id', seed.setIds.first);
        expect(events, hasLength(1));
      },
    );

    test('overhead press 80kg×5: three-way attribution matches Dart (shoulders '
        '0.60 / arms 0.20 / core 0.20)', () async {
      const slug = 'overhead_press';
      const weight = 80.0;
      const reps = 5;

      final user = await freshUser();
      final adminClient = serviceRoleClient();
      final userClient = authenticatedClient(user);

      final seed = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: weight,
        reps: reps,
        numSets: 1,
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed,
        userId: user.userId,
        weightKg: weight,
        reps: reps,
        numSets: 1,
      );

      final dartComps = XpCalculator.computeSetXp(
        weightKg: weight,
        reps: reps,
        peakLoad: 0,
        sessionVolumeForBodyPart: 0,
        weeklyVolumeForBodyPart: 0,
      );
      final dartXp = XpDistribution.distribute(
        setXp: dartComps.setXp,
        attribution: Attribution.fromMap({
          'shoulders': 0.60,
          'arms': 0.20,
          'core': 0.20,
        }),
      );

      final pgRows = await userClient
          .from('body_part_progress')
          .select('body_part, total_xp');
      final pgByBp = {
        for (final row in pgRows as List)
          (row as Map<String, dynamic>)['body_part'] as String: row,
      };

      for (final bp in [BodyPart.shoulders, BodyPart.arms, BodyPart.core]) {
        final dartXpBp = dartXp[bp]!;
        final pgRow = pgByBp[bp.dbValue];
        expect(pgRow, isNotNull);
        final pgXp = (pgRow!['total_xp'] as num).toDouble();
        expect(
          (pgXp - dartXpBp).abs(),
          lessThanOrEqualTo(_kTol),
          reason: '${bp.dbValue}: PG=$pgXp vs Dart=$dartXpBp',
        );
      }
    });

    test('deadlift 100kg×5: four-way attribution (back 0.40, legs 0.40, core '
        '0.10, arms 0.10) matches Dart', () async {
      const slug = 'deadlift';
      const weight = 100.0;
      const reps = 5;

      final user = await freshUser();
      final adminClient = serviceRoleClient();
      final userClient = authenticatedClient(user);

      final seed = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: weight,
        reps: reps,
        numSets: 1,
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed,
        userId: user.userId,
        weightKg: weight,
        reps: reps,
        numSets: 1,
      );

      final dartComps = XpCalculator.computeSetXp(
        weightKg: weight,
        reps: reps,
        peakLoad: 0,
        sessionVolumeForBodyPart: 0,
        weeklyVolumeForBodyPart: 0,
      );
      final dartXp = XpDistribution.distribute(
        setXp: dartComps.setXp,
        attribution: Attribution.fromMap({
          'back': 0.40,
          'legs': 0.40,
          'core': 0.10,
          'arms': 0.10,
        }),
      );

      final pgRows = await userClient
          .from('body_part_progress')
          .select('body_part, total_xp');
      final pgByBp = {
        for (final row in pgRows as List)
          (row as Map<String, dynamic>)['body_part'] as String: row,
      };

      for (final bp in [
        BodyPart.back,
        BodyPart.legs,
        BodyPart.core,
        BodyPart.arms,
      ]) {
        final dartXpBp = dartXp[bp]!;
        final pgRow = pgByBp[bp.dbValue];
        expect(pgRow, isNotNull, reason: '${bp.dbValue} row missing');
        final pgXp = (pgRow!['total_xp'] as num).toDouble();
        expect(
          (pgXp - dartXpBp).abs(),
          lessThanOrEqualTo(_kTol),
          reason: '${bp.dbValue}: PG=$pgXp vs Dart=$dartXpBp',
        );
      }
    });

    /// Novelty diminishing returns: 5 back-to-back bench sets. The session
    /// volume for chest accumulates, reducing later sets' XP. The total chest
    /// XP must be less than 5× a single set's XP.
    test('novelty diminishing returns: 5 bench sets in one session earn less '
        'than 5× a single set', () async {
      const slug = 'barbell_bench_press';
      const weight = 80.0;
      const reps = 8;

      final user = await freshUser();
      final adminClient = serviceRoleClient();
      final userClient = authenticatedClient(user);

      final seed = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: weight,
        reps: reps,
        numSets: 5,
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed,
        userId: user.userId,
        weightKg: weight,
        reps: reps,
        numSets: 5,
      );

      final pgRow = await userClient
          .from('body_part_progress')
          .select('total_xp')
          .eq('body_part', 'chest')
          .single();
      final pgChestTotal = (pgRow['total_xp'] as num).toDouble();

      // Single set XP at 80kg×8 (strength_mult=1.0 for first set).
      final singleComps = XpCalculator.computeSetXp(
        weightKg: weight,
        reps: reps,
        peakLoad: 0,
        sessionVolumeForBodyPart: 0,
        weeklyVolumeForBodyPart: 0,
      );
      final singleChestXp = singleComps.setXp * 0.70;

      // 5 sets with diminishing returns must total LESS than 5× single set.
      expect(
        pgChestTotal,
        lessThan(singleChestXp * 5),
        reason:
            'Chest XP from 5 sets ($pgChestTotal) must be less than '
            '5× single-set ($singleChestXp × 5 = ${singleChestXp * 5}) '
            'due to novelty diminishing returns',
      );
      // Must also be positive and > single-set (at least 1 set counted).
      expect(pgChestTotal, greaterThan(singleChestXp * 0.9));

      // 5 xp_events rows.
      final events = await userClient
          .from('xp_events')
          .select('id')
          .eq('session_id', seed.workoutId);
      expect(events, hasLength(5));
    });
  });

  // ---------------------------------------------------------------------------
  // BUG-RPG-001: save_workout re-save doubles body_part_progress XP
  // ---------------------------------------------------------------------------

  group('record_set_xp idempotency / cascade', () {
    /// BUG-RPG-001 regression — REVERSAL PATTERN.
    ///
    /// `save_workout` deletes old workout_exercises (cascade-deleting sets +
    /// xp_events) and re-inserts them. The xp_events rows are wiped. The fix
    /// (inside the migration) decrements `body_part_progress.total_xp` by
    /// the per-bp contributions of the prior session's xp_events BEFORE the
    /// cascade, so `record_set_xp` rebuilds the totals from a clean baseline
    /// for that session.
    ///
    /// Acceptance: re-saving the same workout produces the SAME final
    /// `body_part_progress.total_xp` as a single save (within numeric
    /// tolerance), regardless of how many times the user re-saves.
    test(
      'BUG-RPG-001 regression: re-save does NOT double body_part_progress XP',
      () async {
        const slug = 'barbell_bench_press';
        const weight = 100.0;
        const reps = 5;

        final user = await freshUser();
        final adminClient = serviceRoleClient();
        final userClient = authenticatedClient(user);

        final seed = await seedWorkout(
          adminClient: adminClient,
          userId: user.userId,
          exerciseSlug: slug,
          weightKg: weight,
          reps: reps,
          numSets: 2,
        );

        // First save.
        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: weight,
          reps: reps,
          numSets: 2,
        );
        final chestAfterFirst = await _readBodyPartXp(userClient, 'chest');
        final shouldersAfterFirst = await _readBodyPartXp(
          userClient,
          'shoulders',
        );
        final armsAfterFirst = await _readBodyPartXp(userClient, 'arms');

        // Second save of the same workout.
        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: weight,
          reps: reps,
          numSets: 2,
        );
        final chestAfterSecond = await _readBodyPartXp(userClient, 'chest');
        final shouldersAfterSecond = await _readBodyPartXp(
          userClient,
          'shoulders',
        );
        final armsAfterSecond = await _readBodyPartXp(userClient, 'arms');

        // After fix: re-save reverts the prior contribution before re-adding,
        // so totals match the single-save totals (within rounding tolerance).
        expect(
          (chestAfterSecond - chestAfterFirst).abs(),
          lessThanOrEqualTo(_kTol),
          reason:
              'Re-save must not change chest XP. '
              'After first save: $chestAfterFirst, after second: $chestAfterSecond '
              '(delta ${(chestAfterSecond - chestAfterFirst).abs()}).',
        );
        expect(
          (shouldersAfterSecond - shouldersAfterFirst).abs(),
          lessThanOrEqualTo(_kTol),
          reason:
              'Re-save must not change shoulders XP. '
              'first=$shouldersAfterFirst second=$shouldersAfterSecond',
        );
        expect(
          (armsAfterSecond - armsAfterFirst).abs(),
          lessThanOrEqualTo(_kTol),
          reason:
              'Re-save must not change arms XP. '
              'first=$armsAfterFirst second=$armsAfterSecond',
        );
      },
    );

    /// Re-save with SAME workout id but DIFFERENT weights/reps must update the
    /// totals to the new value (not stack). This guards against a regression
    /// where the reversal pattern accidentally only handles the equal-weights
    /// case.
    test(
      'BUG-RPG-001 regression: re-save with different weights replaces, not stacks',
      () async {
        const slug = 'barbell_bench_press';
        const reps = 5;

        final user = await freshUser();
        final adminClient = serviceRoleClient();
        final userClient = authenticatedClient(user);

        // First save: 80kg×5
        final seed = await seedWorkout(
          adminClient: adminClient,
          userId: user.userId,
          exerciseSlug: slug,
          weightKg: 80.0,
          reps: reps,
          numSets: 1,
        );
        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: 80.0,
          reps: reps,
          numSets: 1,
        );

        // Second save: 90kg×5 (heavier — peak advances, strength_mult=1.0
        // both times because peak advances inline before strength_mult).
        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: 90.0,
          reps: reps,
          numSets: 1,
        );

        // Final state must equal a single-save of 90kg×5 — NOT
        // (80kg + 90kg) stacked.
        final finalChest = await _readBodyPartXp(userClient, 'chest');

        // Reference: single 90kg×5 save on a fresh user.
        final ref = await freshUser();
        final refClient = authenticatedClient(ref);
        final refSeed = await seedWorkout(
          adminClient: adminClient,
          userId: ref.userId,
          exerciseSlug: slug,
          weightKg: 90.0,
          reps: reps,
          numSets: 1,
        );
        await saveWorkoutRpc(
          userClient: refClient,
          seed: refSeed,
          userId: ref.userId,
          weightKg: 90.0,
          reps: reps,
          numSets: 1,
        );
        final refChest = await _readBodyPartXp(refClient, 'chest');

        // Re-save user's chest XP must approximately equal a single save of
        // the final weight (modulo strength_mult differences from the prior
        // peak being 80 — which actually means the second save's
        // strength_mult is 1.0 since peak advances to 90 inside record_set_xp
        // before strength_mult is computed; same as the reference).
        expect(
          (finalChest - refChest).abs(),
          lessThanOrEqualTo(0.5),
          reason:
              'Re-save with heavier weight must produce ~the same XP as a '
              'single save of the heavier weight. Re-saved=$finalChest, '
              'reference=$refChest, delta=${(finalChest - refChest).abs()}',
        );
      },
    );

    test(
      'xp_events cascade: re-save deletes old events and creates fresh ones',
      () async {
        const slug = 'barbell_bench_press';
        const weight = 100.0;
        const reps = 5;

        final user = await freshUser();
        final adminClient = serviceRoleClient();
        final userClient = authenticatedClient(user);

        final seed = await seedWorkout(
          adminClient: adminClient,
          userId: user.userId,
          exerciseSlug: slug,
          weightKg: weight,
          reps: reps,
          numSets: 2,
        );

        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: weight,
          reps: reps,
          numSets: 2,
        );
        final ids1 = {
          for (final row
              in (await userClient
                      .from('xp_events')
                      .select('id')
                      .eq('session_id', seed.workoutId))
                  as List)
            (row as Map<String, dynamic>)['id'] as String,
        };
        expect(ids1, hasLength(2));

        await saveWorkoutRpc(
          userClient: userClient,
          seed: seed,
          userId: user.userId,
          weightKg: weight,
          reps: reps,
          numSets: 2,
        );
        final ids2 = {
          for (final row
              in (await userClient
                      .from('xp_events')
                      .select('id')
                      .eq('session_id', seed.workoutId))
                  as List)
            (row as Map<String, dynamic>)['id'] as String,
        };
        expect(ids2, hasLength(2));

        // IDs must be NEW (old ones were cascade-deleted and new ones created).
        expect(
          ids2.intersection(ids1),
          isEmpty,
          reason:
              'xp_events IDs must change on re-save (cascade delete + fresh '
              'insert by record_set_xp)',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Concurrent same-set guard
  // ---------------------------------------------------------------------------

  group('record_set_xp concurrent same-set guard', () {
    test('two concurrent record_set_xp calls for the same set_id produce '
        'exactly one xp_events row (UNIQUE INDEX guard)', () async {
      const slug = 'barbell_bench_press';

      final user = await freshUser();
      final adminClient = serviceRoleClient();
      final userClient = authenticatedClient(user);

      final seed = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: 100.0,
        reps: 5,
        numSets: 1,
      );

      // Call record_set_xp twice concurrently for the same set_id.
      await Future.wait([
        userClient.rpc(
          'record_set_xp',
          params: {'p_set_id': seed.setIds.first},
        ),
        userClient.rpc(
          'record_set_xp',
          params: {'p_set_id': seed.setIds.first},
        ),
      ]);

      final events = await userClient
          .from('xp_events')
          .select('id')
          .eq('set_id', seed.setIds.first);
      expect(
        events,
        hasLength(1),
        reason:
            'Concurrent calls for the same set_id must produce exactly '
            'one xp_events row. Got ${(events as List).length}',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // exercise_peak_loads
  // ---------------------------------------------------------------------------

  group('exercise_peak_loads advancement', () {
    test('new PR advances peak_weight', () async {
      const slug = 'barbell_bench_press';
      final user = await freshUser();
      final adminClient = serviceRoleClient();
      final userClient = authenticatedClient(user);

      final seed1 = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: 80.0,
        reps: 5,
        numSets: 1,
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed1,
        userId: user.userId,
        weightKg: 80.0,
        reps: 5,
        numSets: 1,
      );

      final peak1 = await userClient
          .from('exercise_peak_loads')
          .select('peak_weight')
          .eq('exercise_id', seed1.exerciseId)
          .single();
      expect((peak1['peak_weight'] as num).toDouble(), equals(80.0));

      final seed2 = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: 90.0,
        reps: 5,
        numSets: 1,
        startedAt: DateTime.now(),
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed2,
        userId: user.userId,
        weightKg: 90.0,
        reps: 5,
        numSets: 1,
      );

      final peak2 = await userClient
          .from('exercise_peak_loads')
          .select('peak_weight')
          .eq('exercise_id', seed1.exerciseId)
          .single();
      expect(
        (peak2['peak_weight'] as num).toDouble(),
        equals(90.0),
        reason: 'Peak must advance from 80 to 90 on new PR',
      );
    });

    test('deload does not lower peak_weight', () async {
      const slug = 'barbell_bench_press';
      final user = await freshUser();
      final adminClient = serviceRoleClient();
      final userClient = authenticatedClient(user);

      final seed1 = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: 100.0,
        reps: 5,
        numSets: 1,
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed1,
        userId: user.userId,
        weightKg: 100.0,
        reps: 5,
        numSets: 1,
      );

      final seed2 = await seedWorkout(
        adminClient: adminClient,
        userId: user.userId,
        exerciseSlug: slug,
        weightKg: 70.0,
        reps: 5,
        numSets: 1,
        startedAt: DateTime.now(),
      );
      await saveWorkoutRpc(
        userClient: userClient,
        seed: seed2,
        userId: user.userId,
        weightKg: 70.0,
        reps: 5,
        numSets: 1,
      );

      final peakAfterDeload = await userClient
          .from('exercise_peak_loads')
          .select('peak_weight')
          .eq('exercise_id', seed1.exerciseId)
          .single();
      expect(
        (peakAfterDeload['peak_weight'] as num).toDouble(),
        equals(100.0),
        reason: 'Peak must remain 100 after deload at 70',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<double> _readBodyPartXp(dynamic userClient, String bodyPart) async {
  final row = await (userClient as dynamic)
      .from('body_part_progress')
      .select('total_xp')
      .eq('body_part', bodyPart)
      .maybeSingle();
  if (row == null) return 0.0;
  return ((row as Map<String, dynamic>)['total_xp'] as num).toDouble();
}

/// Absolute XP tolerance for PG/Dart parity comparisons.
const double _kTol = 0.01;
