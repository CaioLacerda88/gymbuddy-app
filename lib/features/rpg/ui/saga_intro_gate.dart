import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/local_storage/hive_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/rpg_progress_provider.dart';
import 'saga_intro_overlay.dart';

/// First-launch gate that wraps the authenticated shell and, per user:
///
///   1. Triggers the retroactive RPG backfill exactly once
///      (`backfill_rpg_v1`, idempotent on the server; the Hive flag avoids
///      the round-trip on subsequent launches).
///   2. Renders [SagaIntroOverlay] over [child] when the backfill has
///      completed and the user has not yet dismissed the intro.
///   3. Records dismissal to Hive so the overlay never re-appears.
///
/// The child renders immediately — retro runs asynchronously and the overlay
/// only paints once `rpgProgressProvider` resolves to real data. A per-session
/// guard prevents the overlay from re-mounting after dismissal in the same
/// session (the Hive write is asynchronous; the in-memory flag closes the
/// race).
///
/// **Phase 18-followups rewire (2026-04-29):** the gate previously read
/// from the legacy gamification `xpProvider` and kicked
/// `XpRepository.runRetroBackfill`. Both pointed at the same server-side
/// `backfill_rpg_v1` procedure as `RpgRepository.runBackfill`, so this is
/// a pure consumer-side rewire — the canonical RPG signal
/// (`character_state` view) drives gating + step-3 preview, the gamification
/// dir is gone.
class SagaIntroGate extends ConsumerStatefulWidget {
  const SagaIntroGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SagaIntroGate> createState() => _SagaIntroGateState();
}

class _SagaIntroGateState extends ConsumerState<SagaIntroGate> {
  bool _retroKicked = false;
  bool _dismissedThisSession = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return widget.child;

    _maybeKickRetro(userId);

    final snapshotAsync = ref.watch(rpgProgressProvider);
    final retroDone = hasRunRetroForUser(userId);
    final alreadySeen = hasSeenSagaIntroForUser(userId);

    final shouldShow =
        !_dismissedThisSession &&
        !alreadySeen &&
        retroDone &&
        snapshotAsync is AsyncData;

    if (!shouldShow) return widget.child;

    final l10n = AppLocalizations.of(context);
    final snapshot = snapshotAsync.value!;
    final level = snapshot.characterState.characterLevel;
    final rankSlug = rankSlugFromLifetimeXp(snapshot.characterState.lifetimeXp);
    final rankLabel = _localizeRankSlug(l10n, rankSlug);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        SagaIntroOverlay(
          startingLevel: level,
          rankLabel: rankLabel,
          onDismiss: () => _dismiss(userId),
        ),
      ],
    );
  }

  void _maybeKickRetro(String userId) {
    if (_retroKicked) return;
    if (hasRunRetroForUser(userId)) {
      _retroKicked = true;
      return;
    }
    _retroKicked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Retro is safe to retry next launch (server is idempotent); swallow
      // errors to avoid blocking the home render on a transient network
      // failure.
      _runBackfill(userId).catchError((Object _) {});
    });
  }

  Future<void> _runBackfill(String userId) async {
    await ref.read(rpgRepositoryProvider).runBackfill();
    await markRetroCompleteForUser(userId);
    ref.invalidate(rpgProgressProvider);
  }

  void _dismiss(String userId) {
    // In-memory flag closes the race so the overlay can't re-mount while
    // the Hive write is in flight; the unawaited persist is durable once
    // flush() lands in markSagaIntroSeenForUser.
    setState(() => _dismissedThisSession = true);
    unawaited(markSagaIntroSeenForUser(userId));
  }
}

// ---------------------------------------------------------------------------
// Local-only "has retro run?" + "has seen intro?" flags
// ---------------------------------------------------------------------------
//
// Used by the gate to drive `backfill_rpg_v1` once per user per device.
// `backfill_rpg_v1` is a chunked function looped from
// `RpgRepository.runBackfill` until `out_is_complete=true`. The server-side
// `backfill_progress.completed_at` checkpoint is the source of truth for
// correctness (a re-run on a completed user is a no-op); these flags exist
// only to avoid the cold-start round-trip and to remember dismissal across
// launches.
//
// **Key prefixes preserved from the legacy gamification feature** so
// existing users who already saw the intro pre-rewire don't see it again
// after the deletion.

const String _kRetroKeyPrefix = 'saga_retro_run:';
const String _kSagaIntroSeenPrefix = 'saga_intro_seen:';

/// Whether the retroactive backfill has already been triggered for [userId]
/// from this device.
bool hasRunRetroForUser(String userId) {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  return (box.get('$_kRetroKeyPrefix$userId') as bool?) ?? false;
}

/// Mark the retro backfill as completed for [userId]. The server is
/// idempotent regardless; this flag is purely a cold-start latency
/// optimization.
///
/// `box.flush()` mirrors [markSagaIntroSeenForUser] for IndexedDB durability
/// on Flutter Web. The server is idempotent so a missed flush is recoverable
/// (re-running `backfill_rpg_v1` is a no-op), but the parity keeps the two
/// per-user gate writes structurally identical and avoids a misleading
/// inconsistency for future maintainers.
Future<void> markRetroCompleteForUser(String userId) async {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  await box.put('$_kRetroKeyPrefix$userId', true);
  await box.flush();
}

/// Whether the first-run [SagaIntroOverlay] has been dismissed for [userId].
bool hasSeenSagaIntroForUser(String userId) {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  return (box.get('$_kSagaIntroSeenPrefix$userId') as bool?) ?? false;
}

/// Persist that [userId] has dismissed the saga intro overlay.
///
/// `box.put` awaits the IndexedDB write (on Flutter Web) but the browser
/// can race a page-reload against the transaction. `box.flush()` forces the
/// write to complete before returning, ensuring the flag survives an
/// immediate restart (e.g., explicit page.reload in E2E tests or a rapid
/// app restart on mobile after tapping BEGIN).
Future<void> markSagaIntroSeenForUser(String userId) async {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  await box.put('$_kSagaIntroSeenPrefix$userId', true);
  await box.flush();
}

// ---------------------------------------------------------------------------
// Lifetime XP → rank slug + localized label
// ---------------------------------------------------------------------------
//
// The Phase 17b coarse rank ladder (rookie → diamond) is a UI-only
// progression signal separate from the per-body-part rank curve. It exists
// so the saga intro overlay's "LVL N — RANK" preview reflects the lifter's
// current state rather than always rendering "LVL 1 — ROOKIE" for users with
// real history. After deleting the gamification feature, the thresholds and
// localization keys live here — the only consumer is the intro overlay.
//
// Threshold table (locked, mirrors PLAN.md §17b):
//   * 250_000    → DIAMOND
//   * 125_000    → PLATINUM
//   *  60_000    → GOLD
//   *  25_000    → SILVER
//   *  10_000    → COPPER
//   *   2_500    → IRON
//   *       0    → ROOKIE
//
// The ladder is stored as a `List` of `(minXp, slug)` records sorted
// **descending by `minXp`** so a single forward walk finds the first match.
// Earlier revisions used a `Map<String, double>` and called
// `.entries.toList().reversed` per lookup — correct, but it allocated a
// throwaway list on every overlay rebuild and obscured intent. The list
// shape makes ordering structural (not derived) and the lookup zero-alloc.

const List<({double minXp, String slug})> _rpgIntroRankLadder = [
  (minXp: 250000, slug: 'diamond'),
  (minXp: 125000, slug: 'platinum'),
  (minXp: 60000, slug: 'gold'),
  (minXp: 25000, slug: 'silver'),
  (minXp: 10000, slug: 'copper'),
  (minXp: 2500, slug: 'iron'),
  (minXp: 0, slug: 'rookie'),
];

/// Resolve a rank slug from `character_state.lifetime_xp` against the
/// Phase 17b coarse ladder.
///
/// Walks [_rpgIntroRankLadder] top-down (descending `minXp`) and returns the
/// first slug whose threshold the lifter has crossed. With a `0` floor entry
/// (`rookie`), every non-negative XP matches; the final-fallback return on
/// the last entry's slug guards against an empty ladder + negative XP and
/// keeps the function total.
///
/// Public + `@visibleForTesting` so the unit suite can pin threshold edges
/// without spinning up a localized widget tree.
@visibleForTesting
String rankSlugFromLifetimeXp(double lifetimeXp) {
  for (final entry in _rpgIntroRankLadder) {
    if (lifetimeXp >= entry.minXp) return entry.slug;
  }
  return _rpgIntroRankLadder.last.slug;
}

/// Map a rank [slug] (from [rankSlugFromLifetimeXp]) to its localized label
/// via the bundled `sagaRank*` ARB keys. Unknown slugs fall back to ROOKIE
/// — the ladder is closed, so this is defensive only.
String _localizeRankSlug(AppLocalizations l10n, String slug) {
  return switch (slug) {
    'diamond' => l10n.sagaRankDiamond,
    'platinum' => l10n.sagaRankPlatinum,
    'gold' => l10n.sagaRankGold,
    'silver' => l10n.sagaRankSilver,
    'copper' => l10n.sagaRankCopper,
    'iron' => l10n.sagaRankIron,
    'rookie' => l10n.sagaRankRookie,
    _ => l10n.sagaRankRookie,
  };
}
