import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/celebration_queue.dart';
import '../models/celebration_event.dart';
import '../models/title.dart' as rpg;
import 'overlays/celebration_overflow_card.dart';
import 'overlays/first_awakening_overlay.dart';
import 'overlays/level_up_overlay.dart';
import 'overlays/rank_up_overlay.dart';
import 'overlays/title_unlock_sheet.dart';

/// Sequential player for the post-workout celebration queue (Phase 18c).
///
/// **Why a separate helper instead of inlining in the active-workout screen:**
/// the screen orchestrates a lot of post-finish work already (PR navigation,
/// plan-prompt, history invalidation). Pulling celebration playback into a
/// stand-alone `Future<void>` keeps both responsibilities legible and lets
/// the title-screen Equip flow re-use the half-sheet without re-implementing
/// the sheet barrier + Navigator handshake.
///
/// **Timing contract (locked, spec §13.2):**
///   * Each non-title overlay holds the screen for **1.1s**, then the player
///     pops and waits **200ms** before the next event begins. Total pacing
///     for a 3-event queue: ~3.5s + the title sheet which is user-dismissed.
///   * The [TitleUnlockSheet] is shown via [showModalBottomSheet] after all
///     overlays have played; the player awaits its dismissal so the caller
///     navigates only after the user has seen the title. The sheet is
///     **barrier-dismissable** (tap outside) — users who skip the inline
///     equip can re-equip from the Titles screen. Drag-to-dismiss stays
///     **disabled** so the fixed 0.45 height isn't compromised by a stray
///     swipe.
///   * The overflow card (when present) is shown *after* the title sheet
///     and is **awaited** — the player blocks on a [Completer] that resolves
///     on the first of either user tap or the 4s auto-dismiss timer. The
///     completer carries a `bool`: `true` when the user explicitly tapped
///     the card (caller should route to `/profile`), `false` on auto-
///     dismiss (caller follows its default post-finish flow). Once the
///     completer fires, the [OverlayEntry] is removed and the player
///     returns so the screen can navigate. This guarantees the user
///     actually sees the card on real devices (without the await, the
///     post-frame navigation tore down the overlay before paint).
///
/// **Why the title sheet always comes last:** spec §13.2 reads "rank-ups →
/// level-up → title is the crown." Having the sheet block navigation lets
/// the user equip the title before leaving the workout context — equipping
/// from the saga screen is the fallback, but the immediate-equip moment is
/// the highest-conversion window.
///
/// **Failure handling:** any overlay dismiss races (user backgrounds the
/// app, rapid pop) are absorbed by [Navigator.maybePop] guards. The player
/// never throws — celebration playback is non-essential UI polish.
///
/// **Return value contract:** [CelebrationPlayer.play] returns a
/// [CelebrationPlayResult]. Callers that need to react to the user's choice
/// at the overflow card (e.g., route them to `/profile` instead of `/home`)
/// inspect [CelebrationPlayResult.userTappedOverflow]. Empty queues, no-
/// overflow flows, and auto-dismissed overflow cards all return
/// `userTappedOverflow == false` — the caller's default flow stays correct
/// without explicit branching.

/// Result value for [CelebrationPlayer.play].
///
/// Callers consume this to decide post-celebration navigation. The bool is
/// the only field today; the class shape leaves room for future signals
/// (e.g., title equipped during sheet, overflow body parts list) without
/// breaking the call site.
class CelebrationPlayResult {
  const CelebrationPlayResult({required this.userTappedOverflow});

  /// True when the user explicitly tapped the overflow card during this
  /// playback. Caller convention: route to `/profile` (Saga) so the user
  /// can see the rank-ups that didn't fit in the cap-at-3 queue. False on
  /// auto-dismiss, no-overflow runs, and empty queues.
  final bool userTappedOverflow;

  static const CelebrationPlayResult notTapped = CelebrationPlayResult(
    userTappedOverflow: false,
  );

  static const CelebrationPlayResult tapped = CelebrationPlayResult(
    userTappedOverflow: true,
  );
}

class CelebrationPlayer {
  const CelebrationPlayer._();

  /// Default per-overlay hold time (matches the longest internal animation
  /// of [RankUpOverlay] — 1100ms — so all built-in choreography completes
  /// before the player advances).
  @visibleForTesting
  static const Duration overlayHold = Duration(milliseconds: 1100);

  /// Inter-event gap. Spec §13.2 — 200ms reads as "beat" rather than
  /// abrupt transition.
  @visibleForTesting
  static const Duration interEventGap = Duration(milliseconds: 200);

  /// Play the celebration queue against [context]. Returns when the user
  /// has dismissed the final surface (or the queue is empty).
  ///
  /// [hasPriorEarnedTitles] determines whether title unlocks render with
  /// [TitleUnlockSheet.isFirstEver] true (heroGold name) or false
  /// (textCream name) — passed by the caller (not derived inside the
  /// player) so the test surface stays explicit.
  ///
  /// [onEquipTitle] is the equip callback wired into the title sheet. The
  /// player does not invoke it directly — [TitleUnlockSheet] does, on tap.
  static Future<CelebrationPlayResult> play(
    BuildContext context, {
    required CelebrationQueueResult result,
    required List<rpg.Title> catalog,
    required bool hasPriorEarnedTitles,
    required Future<void> Function(rpg.Title title) onEquipTitle,
  }) async {
    if (result.queue.isEmpty && result.overflow == null) {
      return CelebrationPlayResult.notTapped;
    }

    // Split the queue: non-title overlays play sequentially via showDialog;
    // title unlocks accumulate and render as bottom sheets at the end.
    final titles = <TitleUnlockEvent>[];
    final overlayEvents = <CelebrationEvent>[];
    for (final e in result.queue) {
      if (e is TitleUnlockEvent) {
        titles.add(e);
      } else {
        overlayEvents.add(e);
      }
    }

    // 1) Sequential overlay playback — one dialog at a time, 1.1s hold,
    //    200ms gap. Auto-pop via [Future.delayed] inside the showDialog
    //    completion handshake so the user cannot accidentally jam the
    //    sequence by tapping outside the barrier.
    for (var i = 0; i < overlayEvents.length; i++) {
      if (!context.mounted) return CelebrationPlayResult.notTapped;
      await _playOverlay(context, event: overlayEvents[i]);
      if (i < overlayEvents.length - 1) {
        await Future<void>.delayed(interEventGap);
      }
    }

    // 2) Title-unlock half-sheets — one at a time. First-ever flag is
    //    true for the very first earned title (the screen passes
    //    `hasPriorEarnedTitles` based on the pre-finish snapshot).
    //    Sheet is barrier-dismissable; users who skip equip can re-equip
    //    from the Titles screen.
    //
    //    Slugs that aren't in the local catalog are skipped — that would be a
    //    server-vs-bundle mismatch (server returned a slug we don't ship)
    //    and rendering "(unknown title)" would be worse than silently
    //    omitting the sheet. The unlock is still persisted server-side; the
    //    user sees it on the next titles-screen visit.
    for (var i = 0; i < titles.length; i++) {
      if (!context.mounted) return CelebrationPlayResult.notTapped;
      final event = titles[i];
      final entry = _resolveCatalog(catalog, event.slug);
      if (entry == null) continue;
      final isFirstEver = !hasPriorEarnedTitles && i == 0;
      await _showTitleSheet(
        context,
        title: entry,
        isFirstEver: isFirstEver,
        onEquip: onEquipTitle,
      );
    }

    // 3) Overflow card — awaited until the user taps OR the 4s auto-dismiss
    //    timer fires, whichever comes first. The card runs on its own
    //    [OverlayEntry] above the active route; awaiting its lifetime keeps
    //    the active-workout route alive long enough for the user to
    //    actually read the card. The completer resolves to `true` when the
    //    user tapped (caller routes to /profile) and `false` on auto-
    //    dismiss (caller follows its default post-finish flow).
    final overflow = result.overflow;
    if (overflow != null && context.mounted) {
      final tapped = await _showOverflowCard(
        context,
        remainingRankUps: overflow.remainingRankUps,
      );
      return tapped
          ? CelebrationPlayResult.tapped
          : CelebrationPlayResult.notTapped;
    }
    return CelebrationPlayResult.notTapped;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static Future<void> _playOverlay(
    BuildContext context, {
    required CelebrationEvent event,
  }) async {
    final completer = Completer<void>();
    final navigator = Navigator.of(context, rootNavigator: true);

    // Schedule the auto-pop BEFORE showDialog returns — the timer drives
    // the close, not the dialog itself. Using `addPostFrameCallback` keeps
    // the timer aligned with the same frame the dialog mounts on so a
    // mock-time test can simulate the entire 1.1s + tear-down with one
    // pump.
    Timer? popTimer;

    void schedulePop() {
      popTimer = Timer(overlayHold, () {
        if (!completer.isCompleted) {
          if (navigator.canPop()) {
            navigator.pop();
          }
          // showDialog's then-handler completes the completer; nothing
          // else to do here.
        }
      });
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: switch (event) {
        // Spec §13: rank-up dims to abyss @ 0.72 for the gold-stamp moment.
        RankUpEvent() => AppColors.abyss.withValues(alpha: 0.72),
        // Level-up: NO dim — stacking dim layers would oppress the eye.
        LevelUpEvent() => Colors.transparent,
        // First-awakening: NO dim (800ms compressed window, recover eyes
        // immediately).
        FirstAwakeningEvent() => Colors.transparent,
        // Title unlocks render via showModalBottomSheet, not showDialog —
        // this branch is unreachable (filtered upstream) but kept for
        // exhaustiveness.
        TitleUnlockEvent() => Colors.transparent,
      },
      builder: (_) => switch (event) {
        RankUpEvent(:final bodyPart, :final newRank) => RankUpOverlay(
          bodyPart: bodyPart,
          newRank: newRank,
        ),
        LevelUpEvent(:final newLevel) => LevelUpOverlay(newLevel: newLevel),
        FirstAwakeningEvent(:final bodyPart) => FirstAwakeningOverlay(
          bodyPart: bodyPart,
        ),
        TitleUnlockEvent() => const SizedBox.shrink(),
      },
    ).then((_) {
      popTimer?.cancel();
      if (!completer.isCompleted) completer.complete();
    });

    schedulePop();
    return completer.future;
  }

  static Future<void> _showTitleSheet(
    BuildContext context, {
    required rpg.Title title,
    required bool isFirstEver,
    required Future<void> Function(rpg.Title title) onEquip,
  }) async {
    // Spec §13.2: tap outside or back gesture dismisses. Drag-to-dismiss
    // stays disabled so the fixed 0.45 height isn't compromised by an
    // accidental swipe. showModalBottomSheet completes with `null` when
    // the user dismisses via the barrier — the player handles that the
    // same as completion (the loop advances to the next title or the
    // overflow card).
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.abyss.withValues(alpha: 0.72),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.45,
        maxChildSize: 0.45,
        expand: false,
        builder: (_, _) => TitleUnlockSheet(
          title: title,
          isFirstEver: isFirstEver,
          onEquip: () async {
            try {
              await onEquip(title);
            } finally {
              // Always pop the modal regardless of whether onEquip succeeds
              // or throws — swallowed exceptions inside onEquip must not leave
              // the sheet permanently open. rootNavigator: true is required so
              // we pop from the root navigator (which pushed this modal) rather
              // than a nested ShellRoute navigator that has no route to pop.
              if (sheetContext.mounted) {
                final nav = Navigator.of(sheetContext, rootNavigator: true);
                if (nav.canPop()) nav.pop();
              }
            }
          },
        ),
      ),
    );
  }

  /// Insert the overflow card into the root [Overlay] and resolve once the
  /// user taps OR the card's auto-dismiss timer fires — whichever happens
  /// first. Returns `true` for an explicit tap (caller routes to /profile),
  /// `false` for auto-dismiss. The two paths share a single [Completer] so
  /// neither double-resolves and neither leaks the [OverlayEntry].
  static Future<bool> _showOverflowCard(
    BuildContext context, {
    required int remainingRankUps,
  }) {
    // Use the root Navigator's overlay directly. We can't use
    // `Overlay.maybeOf(context, rootOverlay: true)` here because the caller
    // typically passes the root-navigator's *own* context (via
    // `Navigator.of(context, rootNavigator: true).context`), and that
    // Navigator's context is *above* its Overlay child in the element tree —
    // `Overlay.maybeOf` walks ancestors and would return null.
    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return Future<bool>.value(false);

    final completer = Completer<bool>();
    late OverlayEntry entry;

    void resolve({required bool tapped}) {
      // Idempotent: tap and timer can race, but only the first wins. The
      // OverlayEntry is removed exactly once.
      if (completer.isCompleted) return;
      if (entry.mounted) entry.remove();
      completer.complete(tapped);
    }

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 16,
        right: 16,
        bottom: 32,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: CelebrationOverflowCard(
              overflowCount: remainingRankUps,
              onTap: () => resolve(tapped: true),
              onAutoDismiss: () => resolve(tapped: false),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }

  /// Linear scan of the catalog for [slug]. Returns null when the slug isn't
  /// in the bundle — the caller skips the sheet in that case (see [play]).
  /// O(catalog) on a 90-entry list is trivial; the catalog is loaded once
  /// per app lifetime so we don't bother indexing.
  static rpg.Title? _resolveCatalog(List<rpg.Title> catalog, String slug) {
    for (final t in catalog) {
      if (t.slug == slug) return t;
    }
    return null;
  }
}
