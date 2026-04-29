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
    final rankLabel = _rankLabelFromLifetimeXp(
      l10n,
      snapshot.characterState.lifetimeXp,
    );

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
    markRetroCompleteForUser(userId);
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
void markRetroCompleteForUser(String userId) {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  box.put('$_kRetroKeyPrefix$userId', true);
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
// Lifetime XP → rank label
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
//   * 0          → ROOKIE
//   * 2_500      → IRON
//   * 10_000     → COPPER
//   * 25_000     → SILVER
//   * 60_000     → GOLD
//   * 125_000    → PLATINUM
//   * 250_000    → DIAMOND

const Map<String, double> _kIntroRankThresholds = {
  'rookie': 0,
  'iron': 2500,
  'copper': 10000,
  'silver': 25000,
  'gold': 60000,
  'platinum': 125000,
  'diamond': 250000,
};

/// Resolve a localized rank label from `character_state.lifetime_xp`.
///
/// Returns the localized label for the highest threshold the lifter has
/// crossed. Used by the intro overlay's step-3 "LVL N — RANK" preview.
String _rankLabelFromLifetimeXp(AppLocalizations l10n, double lifetimeXp) {
  String slug = 'rookie';
  // Walk thresholds top-down so the first match wins.
  for (final entry in _kIntroRankThresholds.entries.toList().reversed) {
    if (lifetimeXp >= entry.value) {
      slug = entry.key;
      break;
    }
  }
  return switch (slug) {
    'iron' => l10n.sagaRankIron,
    'copper' => l10n.sagaRankCopper,
    'silver' => l10n.sagaRankSilver,
    'gold' => l10n.sagaRankGold,
    'platinum' => l10n.sagaRankPlatinum,
    'diamond' => l10n.sagaRankDiamond,
    _ => l10n.sagaRankRookie,
  };
}
