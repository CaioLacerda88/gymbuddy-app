import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../models/body_part.dart';
import '../models/title.dart';

/// Catalog asset path. Loaded once on first use and cached for the app
/// lifetime — the catalog is immutable v1 data and lives entirely in the
/// shipped bundle (no remote fetch).
const String kTitlesCatalogAsset = 'assets/rpg/titles_v1.json';

/// Read-shape returned by `earned_titles` SELECT. Lightweight value class
/// (not Freezed) — the table only ever produces this exact shape and the UI
/// consumes [Title] for display, not this row directly.
class EarnedTitleRow {
  const EarnedTitleRow({
    required this.userId,
    required this.titleId,
    required this.earnedAt,
    required this.isActive,
  });

  factory EarnedTitleRow.fromJson(Map<String, dynamic> json) {
    return EarnedTitleRow(
      userId: json['user_id'] as String,
      titleId: json['title_id'] as String,
      earnedAt: DateTime.parse(json['earned_at'] as String),
      isActive: (json['is_active'] as bool?) ?? false,
    );
  }

  final String userId;
  final String titleId;
  final DateTime earnedAt;
  final bool isActive;
}

/// Repository for the title catalog (asset) and the user's earned titles
/// (`earned_titles` table).
///
/// **Catalog vs earned-titles split:**
///   * The catalog is immutable shipped JSON — slug + body part + rank
///     threshold per entry. Display copy lives in `app_*.arb` keyed by slug.
///     Loaded lazily and cached in-process.
///   * Earned-titles are per-user rows persisted in Postgres. The
///     `record_set_xp` RPC inserts rows server-side when a rank threshold
///     is crossed (Phase 18a wiring). The client SELECTs them; equip toggle
///     UPDATEs `is_active` (UNIQUE INDEX `earned_titles_one_active` enforces
///     the at-most-one invariant).
///
/// **Why no `insertEarnedTitle` here:** v1 wires title persistence
/// server-side inside `record_set_xp`. Exposing a client INSERT path would
/// invite double-awarding on retried saves. The detector's purpose is to
/// drive the *celebration overlay* — the durable record was already written
/// by the time `record_set_xp` returned its deltas.
class TitlesRepository extends BaseRepository {
  TitlesRepository(this._client, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final supabase.SupabaseClient _client;
  final AssetBundle _bundle;

  /// In-process cache. Populated on first [loadCatalog] call and reused for
  /// the rest of the app lifetime — the catalog never mutates at runtime.
  static List<Title>? _catalogCache;

  /// Visible-for-test reset hook. Production code never calls this.
  static void debugResetCatalogCache() {
    _catalogCache = null;
  }

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  /// Load the v1 title catalog from the shipped asset. Cached after the
  /// first call. Throws [FlutterError] from `rootBundle` if the asset is
  /// missing — that would be a build-time bug (catalog not in pubspec.yaml).
  Future<List<Title>> loadCatalog() async {
    final cached = _catalogCache;
    if (cached != null) return cached;

    final raw = await _bundle.loadString(kTitlesCatalogAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (json['titles'] as List)
        .cast<Map<String, dynamic>>()
        .map(Title.fromJson)
        .toList(growable: false);

    _catalogCache = entries;
    return entries;
  }

  /// Lookup a single catalog entry by slug. Returns null if the slug is
  /// unknown — the caller decides whether that's a data-integrity error
  /// (server returned a slug we don't ship) or a graceful fallback (UI
  /// reading a row from a future catalog version).
  Future<Title?> lookupBySlug(String slug) async {
    final catalog = await loadCatalog();
    for (final t in catalog) {
      if (t.slug == slug) return t;
    }
    return null;
  }

  /// All catalog entries for a body part, ascending by `rankThreshold`. The
  /// titles screen renders one section per body part using this.
  Future<List<Title>> forBodyPart(BodyPart bodyPart) async {
    final catalog = await loadCatalog();
    final filtered = catalog.where((t) => t.bodyPart == bodyPart).toList()
      ..sort((a, b) => a.rankThreshold.compareTo(b.rankThreshold));
    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Earned titles (Postgres)
  // ---------------------------------------------------------------------------

  /// All earned-title rows for the current user. Ordered by `earned_at`
  /// ascending so the titles screen can render in unlock chronology.
  /// Returns an empty list for an unauthenticated session.
  Future<List<EarnedTitleRow>> getEarnedTitles() {
    return mapException(() async {
      final user = _client.auth.currentUser;
      if (user == null) return const <EarnedTitleRow>[];

      final rows = await _client
          .from('earned_titles')
          .select()
          .order('earned_at');

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(EarnedTitleRow.fromJson)
          .toList(growable: false);
    });
  }

  /// Currently equipped title slug, or null if none equipped. Read off the
  /// UNIQUE INDEX-protected `is_active = true` row.
  Future<String?> getActiveTitleSlug() {
    return mapException(() async {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final row = await _client
          .from('earned_titles')
          .select('title_id')
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) return null;
      return row['title_id'] as String;
    });
  }

  /// Equip a title. Atomically clears the prior `is_active = true` row and
  /// sets the new one — the UNIQUE INDEX `earned_titles_one_active` would
  /// otherwise reject the second UPDATE.
  ///
  /// **Phase 18c v1 implementation:** two sequential UPDATEs. Race with a
  /// concurrent equip from another device would surface a `23505` from the
  /// second statement, which `mapException` translates to
  /// [DatabaseException]. Phase 18d may swap this for a server-side
  /// `equip_title(title_id)` RPC for atomicity, but the UNIQUE INDEX is the
  /// real safety net either way.
  Future<void> equipTitle(String slug) {
    return mapException(() async {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Clear any current active flag (no-op if there isn't one).
      await _client
          .from('earned_titles')
          .update({'is_active': false})
          .eq('user_id', user.id)
          .eq('is_active', true);

      // Set the new active row.
      await _client
          .from('earned_titles')
          .update({'is_active': true})
          .eq('user_id', user.id)
          .eq('title_id', slug);
    });
  }

  /// Unequip the currently active title (if any). Used by the character
  /// sheet's "remove title" affordance — keeps the lifetime unlock log
  /// intact while clearing the equipped state.
  Future<void> unequipActiveTitle() {
    return mapException(() async {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('earned_titles')
          .update({'is_active': false})
          .eq('user_id', user.id)
          .eq('is_active', true);
    });
  }
}
