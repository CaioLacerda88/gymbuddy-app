import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/gamification/data/xp_repository.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';
import 'package:repsaga/features/gamification/models/xp_breakdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ---------------------------------------------------------------------------
// Fake Supabase infrastructure
//
// XpRepository uses the following chains:
//   getSummary:       .from('user_xp').select('total_xp').eq(..).maybeSingle()
//   awardXp (on row): .rpc('award_xp', params: {...})
//   runRetroBackfill: .rpc('retro_backfill_xp', params: {...})
// ---------------------------------------------------------------------------

class _FakeAuth extends Fake implements supabase.GoTrueClient {
  _FakeAuth(this._user);
  supabase.User? _user;
  void setUser(supabase.User? user) => _user = user;

  @override
  supabase.User? get currentUser => _user;
}

class _FakeUser extends Fake implements supabase.User {
  _FakeUser(this._id);
  final String _id;

  @override
  String get id => _id;
}

class _FakeSupabaseClient extends Fake implements supabase.SupabaseClient {
  _FakeSupabaseClient({required this.auth, required this.builder});

  @override
  final _FakeAuth auth;
  final _FakeQueryBuilder builder;

  int rpcCallCount = 0;
  String? lastRpcName;
  Map<String, dynamic>? lastRpcParams;

  @override
  supabase.SupabaseQueryBuilder from(String table) => builder;

  @override
  supabase.PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    rpcCallCount += 1;
    lastRpcName = fn;
    lastRpcParams = params == null ? null : Map<String, dynamic>.from(params);
    return _FakeRpcBuilder<T>() as supabase.PostgrestFilterBuilder<T>;
  }
}

/// Terminal future for rpc() — awaits to null (award_xp has no meaningful
/// return payload from the client's perspective in this unit test).
class _FakeRpcBuilder<T> extends Fake
    implements supabase.PostgrestFilterBuilder<T> {
  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    return Future.value(onValue(null as T));
  }
}

// ignore: must_be_immutable
class _FakeQueryBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  _FakeQueryBuilder({this.singleResult});

  Map<String, dynamic>? singleResult;

  @override
  _FakeFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return _FakeFilterBuilder<List<Map<String, dynamic>>>(this);
  }
}

class _FakeFilterBuilder<T> extends Fake
    implements supabase.PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._parent);

  final _FakeQueryBuilder _parent;

  @override
  _FakeFilterBuilder<T> eq(String column, Object value) => this;

  @override
  _FakeSingleBuilder<Map<String, dynamic>?> maybeSingle() {
    return _FakeSingleBuilder<Map<String, dynamic>?>(_parent);
  }
}

class _FakeSingleBuilder<T> extends Fake
    implements supabase.PostgrestTransformBuilder<T> {
  _FakeSingleBuilder(this._parent);

  final _FakeQueryBuilder _parent;

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    final result = _parent.singleResult as T;
    return Future.value(onValue(result));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

_FakeSupabaseClient _makeClient({
  supabase.User? user,
  Map<String, dynamic>? row,
}) {
  final builder = _FakeQueryBuilder(singleResult: row);
  final auth = _FakeAuth(user);
  return _FakeSupabaseClient(auth: auth, builder: builder);
}

void main() {
  group('XpRepository.getSummary', () {
    test('returns empty summary when the caller has no session', () async {
      final client = _makeClient();
      final repo = XpRepository(client);

      final summary = await repo.getSummary();

      expect(summary.totalXp, 0);
      expect(summary.currentLevel, 1);
      expect(summary.rank, Rank.rookie);
    });

    test(
      'returns empty summary when no user_xp row exists (first-run path)',
      () async {
        final client = _makeClient(user: _FakeUser('user-001'));
        final repo = XpRepository(client);

        final summary = await repo.getSummary();

        expect(summary.totalXp, 0);
        expect(summary.currentLevel, 1);
      },
    );

    test(
      'derives level + rank from persisted total_xp (client curve authoritative)',
      () async {
        final client = _makeClient(
          user: _FakeUser('user-001'),
          // Enough XP to put the user above Rank.iron threshold (2500) and
          // above LVL 1. Exercises the "re-derive from fromTotal" path.
          row: {'total_xp': 3000},
        );
        final repo = XpRepository(client);

        final summary = await repo.getSummary();

        expect(summary.totalXp, 3000);
        expect(summary.currentLevel, greaterThan(1));
        expect(summary.rank, Rank.iron);
      },
    );
  });

  group('XpBreakdown.toJson payload contract', () {
    // The award_xp RPC reads `level` and `rank` from p_breakdown.
    // XpRepository.awardXp must merge those into the breakdown jsonb.
    // This test locks the json-key shape that both sides agree on so a
    // Freezed field rename cannot silently break the RPC contract.
    test('exposes the six expected component keys plus total', () {
      final json = XpBreakdown.zero.toJson();
      expect(json.keys.toSet(), {
        'base',
        'volume',
        'intensity',
        'pr',
        'quest',
        'comeback',
        'total',
      });
    });
  });

  group('XpRepository.awardXp', () {
    test(
      'returns the current summary without RPC when total XP is 0 (no-op)',
      () async {
        final client = _makeClient(user: _FakeUser('user-001'));
        final repo = XpRepository(client);

        final summary = await repo.awardXp(
          userId: 'user-001',
          breakdown: XpBreakdown.zero,
          source: 'workout',
        );

        expect(summary.totalXp, 0);
        expect(client.rpcCallCount, 0);
      },
    );

    test(
      'calls award_xp with level + rank merged into the breakdown jsonb',
      () async {
        final client = _makeClient(
          user: _FakeUser('user-001'),
          row: {'total_xp': 0}, // fresh user, first award
        );
        final repo = XpRepository(client);

        const breakdown = XpBreakdown(
          base: 50,
          volume: 10,
          intensity: 20,
          pr: 100,
          quest: 0,
          comeback: 0,
          total: 180,
        );

        final summary = await repo.awardXp(
          userId: 'user-001',
          breakdown: breakdown,
          source: 'workout',
          workoutId: 'wk-abc',
        );

        expect(client.rpcCallCount, 1);
        expect(client.lastRpcName, 'award_xp');
        final params = client.lastRpcParams!;
        expect(params['p_user_id'], 'user-001');
        expect(params['p_workout_id'], 'wk-abc');
        expect(params['p_amount'], 180);
        expect(params['p_source'], 'workout');

        final payload = params['p_breakdown'] as Map<String, dynamic>;
        // Breakdown keys passed through.
        expect(payload['base'], 50);
        expect(payload['total'], 180);
        // Client-side snapshot fields merged in for the server to persist.
        expect(payload['level'], isA<int>());
        expect(payload['rank'], isA<String>());
        // 180 XP is below LVL 2 threshold — level must stay at 1.
        expect(payload['level'], 1);
        expect(payload['rank'], 'rookie');

        expect(summary.totalXp, 180);
      },
    );
  });

  group('XpRepository.runRetroBackfill', () {
    test('invokes retro_backfill_xp with the user id', () async {
      final client = _makeClient(user: _FakeUser('user-001'));
      final repo = XpRepository(client);

      await repo.runRetroBackfill('user-001');

      expect(client.rpcCallCount, 1);
      expect(client.lastRpcName, 'retro_backfill_xp');
      expect(client.lastRpcParams, {'p_user_id': 'user-001'});
    });
  });
}
