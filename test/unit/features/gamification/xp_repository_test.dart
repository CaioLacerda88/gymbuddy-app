import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/gamification/data/xp_repository.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';
import 'package:repsaga/features/gamification/models/xp_breakdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ---------------------------------------------------------------------------
// Fake Supabase infrastructure
//
// XpRepository (18a shim) uses the following chains:
//   getSummary:       .from('character_state').select('lifetime_xp').maybeSingle()
//   awardXp:          re-reads getSummary (no-op; record_set_xp inside save_workout
//                     is the actual writer)
//   runRetroBackfill: loops .rpc('backfill_rpg_v1', params: {p_user_id, p_chunk_size})
//                     until the response's out_is_complete is true.
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
  _FakeSupabaseClient({
    required this.auth,
    required this.builder,
    this.rpcResponses = const <Object?>[],
  });

  @override
  final _FakeAuth auth;
  final _FakeQueryBuilder builder;

  /// Sequenced RPC responses. Each rpc() invocation pops the next entry
  /// (or returns null if the queue is empty). For backfill_rpg_v1 the
  /// repository loops until out_is_complete=true, so tests must supply
  /// at least one terminal payload.
  final List<Object?> rpcResponses;
  int _rpcResponseIdx = 0;

  int rpcCallCount = 0;
  final List<String> rpcNames = <String>[];
  final List<Map<String, dynamic>?> rpcParams = <Map<String, dynamic>?>[];

  String? get lastRpcName => rpcNames.isEmpty ? null : rpcNames.last;
  Map<String, dynamic>? get lastRpcParams =>
      rpcParams.isEmpty ? null : rpcParams.last;

  @override
  supabase.SupabaseQueryBuilder from(String table) => builder;

  @override
  supabase.PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    rpcCallCount += 1;
    rpcNames.add(fn);
    rpcParams.add(params == null ? null : Map<String, dynamic>.from(params));
    final response = _rpcResponseIdx < rpcResponses.length
        ? rpcResponses[_rpcResponseIdx]
        : null;
    _rpcResponseIdx += 1;
    return _FakeRpcBuilder<T>(response) as supabase.PostgrestFilterBuilder<T>;
  }
}

/// Terminal future for rpc(). Returns the canned response payload cast
/// to T. `null` is acceptable for callers that ignore the return value.
class _FakeRpcBuilder<T> extends Fake
    implements supabase.PostgrestFilterBuilder<T> {
  _FakeRpcBuilder(this._response);
  final Object? _response;

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    return Future.value(onValue(_response as T));
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
  List<Object?> rpcResponses = const <Object?>[],
}) {
  final builder = _FakeQueryBuilder(singleResult: row);
  final auth = _FakeAuth(user);
  return _FakeSupabaseClient(
    auth: auth,
    builder: builder,
    rpcResponses: rpcResponses,
  );
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
      'returns empty summary when no character_state row exists (first-run path)',
      () async {
        final client = _makeClient(user: _FakeUser('user-001'));
        final repo = XpRepository(client);

        final summary = await repo.getSummary();

        expect(summary.totalXp, 0);
        expect(summary.currentLevel, 1);
      },
    );

    test(
      'derives level + rank from character_state.lifetime_xp (18a shim)',
      () async {
        final client = _makeClient(
          user: _FakeUser('user-001'),
          // Enough XP to put the user above Rank.iron threshold (2500) and
          // above LVL 1. Exercises the "re-derive from fromTotal" path.
          row: {'lifetime_xp': 3000},
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
    // The breakdown shape is preserved across the 18a shim so any future
    // re-introduction of a client-side award path doesn't have to change
    // model serialization. Lock the keys here.
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

  group('XpRepository.awardXp — 18a no-op shim', () {
    // 18a contract: awardXp must NOT call the dropped award_xp RPC. The
    // server-side `record_set_xp` (called from `save_workout`) is the
    // single writer. awardXp re-reads the post-save summary so the
    // notifier's optimistic state can reconcile with server truth.

    test(
      'returns the current summary without calling award_xp (zero XP)',
      () async {
        final client = _makeClient(user: _FakeUser('user-001'));
        final repo = XpRepository(client);

        final summary = await repo.awardXp(
          userId: 'user-001',
          breakdown: XpBreakdown.zero,
          source: 'workout',
        );

        expect(summary.totalXp, 0);
        expect(
          client.rpcCallCount,
          0,
          reason: '18a shim must not call any RPC from awardXp',
        );
      },
    );

    test(
      'returns the current summary without calling award_xp (non-zero XP)',
      () async {
        final client = _makeClient(
          user: _FakeUser('user-001'),
          row: {'lifetime_xp': 3000},
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

        expect(
          client.rpcCallCount,
          0,
          reason:
              '18a shim must not call award_xp — record_set_xp '
              'already wrote XP server-side.',
        );
        expect(
          summary.totalXp,
          3000,
          reason:
              'awardXp returns the freshly-read summary, not '
              'optimistic + breakdown.total',
        );
      },
    );
  });

  group('XpRepository.runRetroBackfill', () {
    test('invokes backfill_rpg_v1 with user id and chunk size, stopping on '
        'is_complete=true', () async {
      final client = _makeClient(
        user: _FakeUser('user-001'),
        rpcResponses: <Object?>[
          // Mirrors the SQL function's RETURNS TABLE shape.
          <Map<String, dynamic>>[
            {
              'out_processed': 0,
              'out_total_processed': 0,
              'out_is_complete': true,
            },
          ],
        ],
      );
      final repo = XpRepository(client);

      await repo.runRetroBackfill('user-001');

      expect(client.rpcCallCount, 1);
      expect(client.lastRpcName, 'backfill_rpg_v1');
      expect(client.lastRpcParams, {
        'p_user_id': 'user-001',
        'p_chunk_size': 500,
      });
    });

    test('loops until is_complete=true (multi-chunk path)', () async {
      final client = _makeClient(
        user: _FakeUser('user-001'),
        rpcResponses: <Object?>[
          <Map<String, dynamic>>[
            {
              'out_processed': 500,
              'out_total_processed': 500,
              'out_is_complete': false,
            },
          ],
          <Map<String, dynamic>>[
            {
              'out_processed': 500,
              'out_total_processed': 1000,
              'out_is_complete': false,
            },
          ],
          <Map<String, dynamic>>[
            {
              'out_processed': 250,
              'out_total_processed': 1250,
              'out_is_complete': true,
            },
          ],
        ],
      );
      final repo = XpRepository(client);

      await repo.runRetroBackfill('user-001');

      expect(
        client.rpcCallCount,
        3,
        reason:
            'shim must keep calling backfill_rpg_v1 until the server '
            'returns out_is_complete=true',
      );
      expect(
        client.rpcNames,
        everyElement('backfill_rpg_v1'),
        reason: 'all RPC calls must target backfill_rpg_v1',
      );
    });
  });
}
