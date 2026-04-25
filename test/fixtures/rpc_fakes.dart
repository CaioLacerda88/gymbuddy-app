/// Fake Supabase client for RPC-based repository tests.
///
/// Phase 15f Stage 6: exercise content lives behind locale-aware RPCs
/// (`fn_exercises_localized`, `fn_search_exercises_localized`,
/// `fn_insert_user_exercise`, `fn_update_user_exercise`). Repositories must
/// be tested without hitting Supabase, so this file provides a configurable
/// fake that:
///
///   * Records every `rpc()` call (name, params, count) for assertion.
///   * Dispatches each named RPC to a registered handler function — handlers
///     can return `List<Map<String, dynamic>>` (RPC table results), throw
///     [supabase.PostgrestException] (auth/SQL errors), or throw any other
///     exception. Per-call counters per RPC name help assert N+1 protection.
///   * Optionally routes `from(table)` to a [FakeQueryBuilder] for endpoints
///     that haven't been migrated to RPCs (e.g. softDeleteExercise still uses
///     direct table updates).
///
/// Pattern reference: `test/unit/features/gamification/xp_repository_test.dart`
/// (lines 35-70) — same fake-RPC structure, generalized here for reuse across
/// exercise/workout/PR/routine repository tests.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../unit/_helpers/fake_supabase.dart';

/// Signature for an RPC handler.
///
/// Receives the params map (may be null) and returns the rows the RPC would
/// return. Handlers may also throw to simulate backend errors. Most
/// repository code awaits `rpc()` and unwraps the result as a `List`, so
/// returning `List<Map<String, dynamic>>` matches the wire shape.
typedef RpcHandler =
    FutureOr<List<Map<String, dynamic>>> Function(Map<String, dynamic>? params);

/// Records of a single rpc() invocation. Useful for asserting call order,
/// param contents, and repeat counts.
class RpcCall {
  RpcCall(this.name, this.params);
  final String name;
  final Map<String, dynamic>? params;

  @override
  String toString() => 'RpcCall($name, $params)';
}

/// A configurable fake [supabase.SupabaseClient] for RPC-based tests.
///
/// Register handlers up front via [registerRpc]. Unhandled RPC names raise
/// [StateError] so missing setup is loud.
class FakeRpcClient extends Fake implements supabase.SupabaseClient {
  FakeRpcClient({this.tableBuilders = const {}});

  /// Optional `from(table)` routing for non-RPC paths
  /// (softDeleteExercise, raw `from('workouts')`, etc.).
  final Map<String, FakeQueryBuilder> tableBuilders;

  /// Registered RPC handlers, keyed by RPC name.
  final Map<String, RpcHandler> _handlers = {};

  /// Every rpc() call in order. Index 0 is the first call.
  final List<RpcCall> calls = [];

  /// Register a handler for [rpcName]. Replaces any existing handler.
  void registerRpc(String rpcName, RpcHandler handler) {
    _handlers[rpcName] = handler;
  }

  /// Number of times [rpcName] has been called.
  int callCountFor(String rpcName) =>
      calls.where((c) => c.name == rpcName).length;

  /// Total number of rpc() invocations across all RPC names.
  int get rpcCallCount => calls.length;

  /// Most recent rpc() name, or null if none called yet.
  String? get lastRpcName => calls.isEmpty ? null : calls.last.name;

  /// Most recent rpc() params, or null.
  Map<String, dynamic>? get lastRpcParams =>
      calls.isEmpty ? null : calls.last.params;

  @override
  supabase.SupabaseQueryBuilder from(String table) {
    final builder = tableBuilders[table];
    if (builder == null) {
      throw StateError(
        'FakeRpcClient: no FakeQueryBuilder registered for table "$table". '
        'Pass tableBuilders: {"$table": FakeQueryBuilder(...)} to the '
        'constructor if this test exercises a non-RPC code path.',
      );
    }
    return builder;
  }

  @override
  supabase.PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    calls.add(
      RpcCall(fn, params == null ? null : Map<String, dynamic>.from(params)),
    );

    final handler = _handlers[fn];
    if (handler == null) {
      throw StateError(
        'FakeRpcClient: no handler registered for RPC "$fn". '
        'Call client.registerRpc("$fn", (params) => [...]) before invoking '
        'the repository method.',
      );
    }

    return _FakeRpcResultBuilder<T>(() async => handler(params))
        as supabase.PostgrestFilterBuilder<T>;
  }
}

/// Terminal future for rpc() chains. Awaits the handler and casts the
/// resulting list to whatever type the repository expects (typically
/// `List<dynamic>` or `List<Map<String, dynamic>>`). If the handler throws,
/// the error propagates through `then` — matching real Supabase behavior.
class _FakeRpcResultBuilder<T> extends Fake
    implements supabase.PostgrestFilterBuilder<T> {
  _FakeRpcResultBuilder(this._produce);

  final FutureOr<List<Map<String, dynamic>>> Function() _produce;

  Future<T> _resolve() async {
    final result = await _produce();
    return result as T;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    return _resolve().then<S>(onValue, onError: onError);
  }
}
