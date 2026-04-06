import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/personal_records/data/pr_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ---------------------------------------------------------------------------
// Fake Supabase infrastructure for PRRepository.clearAllRecords
// ---------------------------------------------------------------------------

class FakeSupabaseClient extends Fake implements supabase.SupabaseClient {
  FakeSupabaseClient(this.fakeBuilder);
  final FakeQueryBuilder fakeBuilder;

  @override
  supabase.SupabaseQueryBuilder from(String table) {
    fakeBuilder.queriedTable = table;
    return fakeBuilder;
  }
}

// ignore: must_be_immutable
class FakeQueryBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  FakeQueryBuilder({this.error});

  final Exception? error;
  String? queriedTable;
  final List<String> calledMethods = [];

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
  FakeFilterBuilder eq(String column, Object value) {
    _parent.calledMethods.add('eq:$column=$value');
    return this;
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
    return Future.value(onValue(const []));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PRRepository.clearAllRecords', () {
    test('deletes all personal records for a user', () async {
      final fakeBuilder = FakeQueryBuilder();
      final repo = PRRepository(FakeSupabaseClient(fakeBuilder));

      await repo.clearAllRecords('user-001');

      expect(fakeBuilder.queriedTable, 'personal_records');
      expect(fakeBuilder.calledMethods, contains('delete'));
      expect(fakeBuilder.calledMethods, contains('eq:user_id=user-001'));
    });

    test('uses mapException pattern', () async {
      final fakeBuilder = FakeQueryBuilder(
        error: Exception('Connection failed'),
      );
      final repo = PRRepository(FakeSupabaseClient(fakeBuilder));

      expect(() => repo.clearAllRecords('user-001'), throwsA(isA<Exception>()));
    });
  });
}
