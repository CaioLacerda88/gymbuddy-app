import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/celebration_queue.dart';
import '../models/body_part.dart';
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
///     navigates only after the user has seen the title.
///   * The overflow card (when present) is shown *after* the title sheet,
///     fire-and-forget — the card auto-dismisses at 3s and the player
///     returns immediately so the screen can navigate.
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
  static Future<void> play(
    BuildContext context, {
    required CelebrationQueueResult result,
    required List<rpg.Title> catalog,
    required bool hasPriorEarnedTitles,
    required Future<void> Function(rpg.Title title) onEquipTitle,
  }) async {
    if (result.queue.isEmpty && result.overflow == null) return;

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
      if (!context.mounted) return;
      await _playOverlay(context, event: overlayEvents[i]);
      if (i < overlayEvents.length - 1) {
        await Future<void>.delayed(interEventGap);
      }
    }

    // 2) Title-unlock half-sheets — one at a time. First-ever flag is
    //    true for the very first earned title (the screen passes
    //    `hasPriorEarnedTitles` based on the pre-finish snapshot).
    for (var i = 0; i < titles.length; i++) {
      if (!context.mounted) return;
      final event = titles[i];
      final entry = _resolveCatalog(
        catalog,
        event.slug,
        event.bodyPart,
        event.rankThreshold,
      );
      final isFirstEver = !hasPriorEarnedTitles && i == 0;
      await _showTitleSheet(
        context,
        title: entry,
        isFirstEver: isFirstEver,
        onEquip: onEquipTitle,
      );
    }

    // 3) Overflow card — fire-and-forget, auto-dismisses at 3s. The player
    //    does NOT await this so the caller can navigate immediately after
    //    the title sheet closes.
    final overflow = result.overflow;
    if (overflow != null && context.mounted) {
      _showOverflowCard(context, remainingRankUps: overflow.remainingRankUps);
    }
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
            await onEquip(title);
            if (sheetContext.mounted) Navigator.of(sheetContext).maybePop();
          },
        ),
      ),
    );
  }

  static void _showOverflowCard(
    BuildContext context, {
    required int remainingRankUps,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
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
              onTap: () {
                entry.remove();
              },
              onAutoDismiss: () {
                if (entry.mounted) entry.remove();
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  static rpg.Title _resolveCatalog(
    List<rpg.Title> catalog,
    String slug,
    BodyPart bodyPart,
    int rankThreshold,
  ) {
    for (final t in catalog) {
      if (t.slug == slug) return t;
    }
    // Defensive: server returned a slug we don't ship. Fall back to a
    // synthetic entry so the sheet still renders the rank label even if
    // the localized name lookup misses.
    return rpg.Title(
      slug: slug,
      bodyPart: bodyPart,
      rankThreshold: rankThreshold,
    );
  }
}
