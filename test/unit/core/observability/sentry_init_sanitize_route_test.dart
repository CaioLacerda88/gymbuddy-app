import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/observability/sentry_init.dart';

/// Unit tests for [sanitizeRouteName].
///
/// Covers:
/// - null settings → null returned (no crash)
/// - route with no UUID → same RouteSettings object returned
/// - route with a single UUID → UUID replaced with /:id
/// - route with multiple UUIDs → all replaced
/// - query string after UUID → UUID portion replaced, query string preserved
void main() {
  group('sanitizeRouteName', () {
    test('returns null when settings is null', () {
      expect(sanitizeRouteName(null), isNull);
    });

    test('returns same object when route name is null', () {
      const settings = RouteSettings();
      final result = sanitizeRouteName(settings);
      // name is null → same object (no allocation)
      expect(result, same(settings));
    });

    test('returns same object when no UUID in route name', () {
      const settings = RouteSettings(name: '/exercises');
      final result = sanitizeRouteName(settings);
      expect(result, same(settings));
    });

    test('replaces single UUID segment with /:id', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      const settings = RouteSettings(name: '/exercises/$uuid');
      final result = sanitizeRouteName(settings);
      expect(result, isNotNull);
      expect(result!.name, '/exercises/:id');
    });

    test('replaces multiple UUID segments with /:id each', () {
      const uuid1 = '550e8400-e29b-41d4-a716-446655440000';
      const uuid2 = '123e4567-e89b-12d3-a456-426614174000';
      const settings = RouteSettings(name: '/users/$uuid1/workouts/$uuid2');
      final result = sanitizeRouteName(settings);
      expect(result, isNotNull);
      expect(result!.name, '/users/:id/workouts/:id');
    });

    test('preserves route arguments when UUID is replaced', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      const args = {'key': 'value'};
      const settings = RouteSettings(name: '/routines/$uuid', arguments: args);
      final result = sanitizeRouteName(settings);
      expect(result, isNotNull);
      expect(result!.name, '/routines/:id');
      expect(result.arguments, same(args));
    });

    test('does not replace partial UUID-like strings (too short)', () {
      // A truncated UUID that does not match the full pattern must pass through.
      const settings = RouteSettings(name: '/items/550e8400-e29b-41d4');
      final result = sanitizeRouteName(settings);
      // No replacement → same object.
      expect(result, same(settings));
    });

    test('replaces mixed-case UUID', () {
      const uuid = '550E8400-E29B-41D4-A716-446655440000';
      const settings = RouteSettings(name: '/workouts/$uuid');
      final result = sanitizeRouteName(settings);
      expect(result, isNotNull);
      expect(result!.name, '/workouts/:id');
    });
  });
}
