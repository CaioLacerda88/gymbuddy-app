/// Shared fake Supabase infrastructure for unit tests.
///
/// Provides lightweight fakes that record method calls and return preset data,
/// matching the pattern used across all repository tests in this project.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// A fake SupabaseClient that routes `from(table)` to a single builder.
class FakeSupabaseClient extends Fake implements supabase.SupabaseClient {
  FakeSupabaseClient(this.fakeBuilder);

  final FakeQueryBuilder fakeBuilder;

  @override
  supabase.SupabaseQueryBuilder from(String table) => fakeBuilder;
}

/// A fake client that routes `from(table)` to different builders per table.
class FakeRoutingSupabaseClient extends Fake
    implements supabase.SupabaseClient {
  FakeRoutingSupabaseClient(this.builders);

  final Map<String, FakeQueryBuilder> builders;

  @override
  supabase.SupabaseQueryBuilder from(String table) =>
      builders[table] ?? (throw StateError('Unexpected table: $table'));
}

/// Records chained query calls and returns preset data or error.
class FakeQueryBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  FakeQueryBuilder({this.data = const [], this.error});

  final List<Map<String, dynamic>> data;
  final Exception? error;
  final List<String> calledMethods = [];

  @override
  FakeFilterBuilder select([String columns = '*']) {
    calledMethods.add('select');
    return FakeFilterBuilder(this);
  }

  @override
  FakeFilterBuilder insert(dynamic values, {bool defaultToNull = true}) {
    calledMethods.add('insert');
    return FakeFilterBuilder(this);
  }

  @override
  FakeFilterBuilder update(Map values) {
    calledMethods.add('update');
    return FakeFilterBuilder(this);
  }

  @override
  FakeFilterBuilder delete() {
    calledMethods.add('delete');
    return FakeFilterBuilder(this);
  }
}

class FakeFilterBuilder extends Fake
    implements supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  FakeFilterBuilder(this._parent);

  final FakeQueryBuilder _parent;

  @override
  FakeFilterBuilder isFilter(String column, Object? value) {
    _parent.calledMethods.add('isFilter:$column');
    return this;
  }

  @override
  FakeFilterBuilder eq(String column, Object value) {
    _parent.calledMethods.add('eq:$column=$value');
    return this;
  }

  @override
  FakeFilterBuilder ilike(String column, Object value) {
    _parent.calledMethods.add('ilike:$column=$value');
    return this;
  }

  @override
  FakeFilterBuilder or(String filter, {String? referencedTable}) {
    _parent.calledMethods.add('or:$filter');
    return this;
  }

  @override
  FakeFilterBuilder inFilter(String column, List values) {
    _parent.calledMethods.add('inFilter:$column');
    return this;
  }

  @override
  FakeFilterBuilder not(String column, String operator, Object? value) {
    _parent.calledMethods.add('not:$column.$operator=$value');
    return this;
  }

  @override
  FakeFilterBuilder select([String columns = '*']) {
    _parent.calledMethods.add('chainSelect');
    return this;
  }

  @override
  FakeTransformBuilder<Map<String, dynamic>> single() {
    _parent.calledMethods.add('single');
    return FakeTransformBuilder<Map<String, dynamic>>(
      _parent,
      _parent.data.isEmpty ? <String, dynamic>{} : _parent.data.first,
    );
  }

  @override
  FakeTransformBuilder<List<Map<String, dynamic>>> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    _parent.calledMethods.add('order:$column');
    return FakeTransformBuilder<List<Map<String, dynamic>>>(
      _parent,
      _parent.data,
    );
  }

  @override
  Future<S> then<S>(
    FutureOr<S> Function(List<Map<String, dynamic>>) onValue, {
    Function? onError,
  }) {
    if (_parent.error != null) {
      return Future<List<Map<String, dynamic>>>.error(
        _parent.error!,
      ).then<S>(onValue, onError: onError);
    }
    return Future.value(onValue(_parent.data));
  }
}

class FakeTransformBuilder<T> extends Fake
    implements supabase.PostgrestTransformBuilder<T> {
  FakeTransformBuilder(this._parent, this._result);

  final FakeQueryBuilder _parent;
  final T _result;

  @override
  FakeFilterBuilder select([String columns = '*']) =>
      FakeFilterBuilder(_parent);

  @override
  FakeTransformBuilder<T> limit(int count, {String? referencedTable}) {
    _parent.calledMethods.add('limit:$count');
    return this;
  }

  @override
  FakeTransformBuilder<T> range(int from, int to, {String? referencedTable}) {
    _parent.calledMethods.add('range:$from-$to');
    return this;
  }

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) {
    if (_parent.error != null) {
      return Future<T>.error(_parent.error!).then<S>(onValue, onError: onError);
    }
    return Future.value(onValue(_result));
  }
}
