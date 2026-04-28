/// Unit tests for [TitlesRepository] — focused on the asset-loading +
/// catalog-shape contract. The Supabase plumbing (earned_titles SELECT/UPDATE)
/// mirrors patterns already covered by analytics/profile repository tests
/// and is exercised end-to-end in the Phase 18c E2E suite (rank-up
/// celebration spec). Re-faking it here would only test the fake.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/data/titles_repository.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._payload);
  final String _payload;
  int loadStringCalls = 0;

  @override
  Future<ByteData> load(String key) async {
    throw UnimplementedError('not used by these tests');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadStringCalls += 1;
    return _payload;
  }
}

/// Minimal fake — TitlesRepository extends BaseRepository, so the constructor
/// must accept a SupabaseClient. The catalog tests never invoke any client
/// method, so the fake only needs to exist (not respond).
class _UnusedClient extends Fake implements supabase.SupabaseClient {}

String _validCatalog() {
  return jsonEncode({
    'version': 1,
    'titles': [
      {'slug': 'chest_r5_initiate', 'body_part': 'chest', 'rank_threshold': 5},
      {'slug': 'chest_r10_plate', 'body_part': 'chest', 'rank_threshold': 10},
      {'slug': 'legs_r5_walker', 'body_part': 'legs', 'rank_threshold': 5},
      {'slug': 'back_r5_lattice', 'body_part': 'back', 'rank_threshold': 5},
    ],
  });
}

void main() {
  setUp(() {
    // The static catalog cache leaks across tests by design (it's an
    // app-lifetime cache in production). Reset between tests so each
    // assertion sees a fresh load.
    TitlesRepository.debugResetCatalogCache();
  });

  group('TitlesRepository.loadCatalog', () {
    test('parses every entry with body_part and rank_threshold', () async {
      final bundle = _FakeBundle(_validCatalog());
      final repo = TitlesRepository(_UnusedClient(), bundle: bundle);

      final catalog = await repo.loadCatalog();

      expect(catalog, hasLength(4));
      expect(catalog.first.slug, 'chest_r5_initiate');
      expect(catalog.first.bodyPart, BodyPart.chest);
      expect(catalog.first.rankThreshold, 5);
    });

    test('caches the parsed catalog (second call reuses load)', () async {
      final bundle = _FakeBundle(_validCatalog());
      final repo = TitlesRepository(_UnusedClient(), bundle: bundle);

      await repo.loadCatalog();
      await repo.loadCatalog();

      // The static cache short-circuits the second call.
      expect(bundle.loadStringCalls, 1);
    });
  });

  group('TitlesRepository.lookupBySlug', () {
    test('returns the matching catalog entry', () async {
      final repo = TitlesRepository(
        _UnusedClient(),
        bundle: _FakeBundle(_validCatalog()),
      );

      final title = await repo.lookupBySlug('chest_r10_plate');
      expect(title, isNotNull);
      expect(title!.bodyPart, BodyPart.chest);
      expect(title.rankThreshold, 10);
    });

    test('returns null for an unknown slug', () async {
      final repo = TitlesRepository(
        _UnusedClient(),
        bundle: _FakeBundle(_validCatalog()),
      );

      expect(await repo.lookupBySlug('totally_made_up_slug'), isNull);
    });
  });

  group('TitlesRepository.forBodyPart', () {
    test(
      'returns only entries for the requested body part, ascending',
      () async {
        final repo = TitlesRepository(
          _UnusedClient(),
          bundle: _FakeBundle(_validCatalog()),
        );

        final chest = await repo.forBodyPart(BodyPart.chest);
        expect(chest.map((t) => t.rankThreshold), [5, 10]);

        final legs = await repo.forBodyPart(BodyPart.legs);
        expect(legs.map((t) => t.slug), ['legs_r5_walker']);
      },
    );

    test(
      'returns empty list for a body part absent from the catalog',
      () async {
        final repo = TitlesRepository(
          _UnusedClient(),
          bundle: _FakeBundle(_validCatalog()),
        );

        // Cardio has no entries in v1.
        expect(await repo.forBodyPart(BodyPart.cardio), isEmpty);
      },
    );
  });

  group('Shipped titles_v1.json (integration with rootBundle)', () {
    test('loads, parses, and contains all 78 v1 entries', () async {
      // This locks the shipped asset against accidental edits — slug count
      // is a structural invariant of the v1 contract.
      TestWidgetsFlutterBinding.ensureInitialized();
      // We're not faking here; we read the actual asset registered in
      // pubspec.yaml. If the asset is missing or malformed, this fails.
      final repo = TitlesRepository(_UnusedClient());
      final catalog = await repo.loadCatalog();
      expect(catalog, hasLength(78));

      // Six body parts × 13 thresholds (5,10,15,20,25,30,40,50,60,70,80,90,99).
      final perBodyPart = <BodyPart, int>{};
      for (final t in catalog) {
        perBodyPart[t.bodyPart] = (perBodyPart[t.bodyPart] ?? 0) + 1;
      }
      expect(perBodyPart[BodyPart.chest], 13);
      expect(perBodyPart[BodyPart.back], 13);
      expect(perBodyPart[BodyPart.legs], 13);
      expect(perBodyPart[BodyPart.shoulders], 13);
      expect(perBodyPart[BodyPart.arms], 13);
      expect(perBodyPart[BodyPart.core], 13);

      // Terminal Rank 99 entry exists for every body part.
      for (final bp in [
        BodyPart.chest,
        BodyPart.back,
        BodyPart.legs,
        BodyPart.shoulders,
        BodyPart.arms,
        BodyPart.core,
      ]) {
        final terminal = catalog.where(
          (t) => t.bodyPart == bp && t.rankThreshold == 99,
        );
        expect(terminal, hasLength(1), reason: '${bp.dbValue} R99 missing');
      }
    });
  });
}
