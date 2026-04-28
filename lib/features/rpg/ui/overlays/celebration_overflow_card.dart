import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Condensed overflow card surfaced after the cap-at-3 rule trims rank-ups
/// (Phase 18c, spec §13).
///
/// **Why this exists:** A user finishing six body-part rank-ups + a level-up
/// + a title unlock would otherwise sit through ~10 seconds of overlays. The
/// celebration queue caps at 3 and routes the remainder to this non-modal
/// card: "N more rank-ups — open Saga".
///
/// **Contract:**
///   * The card is non-modal — it does NOT capture pointer events outside
///     its own hit region (the parent inserts it into a [Stack] without
///     [Positioned.fill]).
///   * Auto-dismisses after [autoDismissDelay] (4 seconds by default) via
///     [onAutoDismiss]. The timer is cancelled on dispose so a remount-
///     before-fire does not leak the callback.
///   * Tap anywhere on the card invokes [onTap] — the entire surface is the
///     hit target via [InkWell] with a visible ripple. A muted "tap to
///     continue" hint sits under the overflow copy so the dismiss action is
///     discoverable. Spec §13.2: post-workout hands struggle with precision
///     targets, so we offer the whole card rather than an X icon.
///   * The card uses [AppColors.surface2] background with a [AppColors.hair]
///     border. NO `heroGold` pixels — this is a calm "go look at the rest
///     of your rewards" affordance, not a peak celebration. The peak
///     celebrations already played; this is the receipt.
///
/// **Pluralization** runs through `l10n.celebrationOverflowLabel(count)`
/// which carries `{count, plural, one{...} other{...}}` ICU semantics.
class CelebrationOverflowCard extends StatefulWidget {
  const CelebrationOverflowCard({
    super.key,
    required this.overflowCount,
    required this.onTap,
    required this.onAutoDismiss,
    this.autoDismissDelay = const Duration(seconds: 4),
  });

  /// Number of rank-ups that did NOT make the cap-at-3 cut.
  final int overflowCount;

  /// Invoked when the user taps the card. Parent dismisses the card.
  final VoidCallback onTap;

  /// Invoked exactly once after [autoDismissDelay] elapses, IF the widget
  /// is still mounted. Parent dismisses the card from the celebration queue.
  final VoidCallback onAutoDismiss;

  /// Time after which the card auto-dismisses if untouched. Defaults to 4s
  /// per spec — long enough for a post-workout user to read the count and
  /// decide whether to open Saga; the constructor exposes this knob for
  /// test injection.
  final Duration autoDismissDelay;

  @override
  State<CelebrationOverflowCard> createState() =>
      _CelebrationOverflowCardState();
}

class _CelebrationOverflowCardState extends State<CelebrationOverflowCard> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    // The timer is structurally one-fire — it's started in initState and
    // cancelled in dispose. A widget cannot fire onAutoDismiss twice without
    // a remount.
    _autoDismissTimer = Timer(widget.autoDismissDelay, () {
      if (mounted) widget.onAutoDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.celebrationOverflowLabel(widget.overflowCount);
    // Semantics(button + onTap) is the AOM-dispatched tap path that DOM clicks
    // (e.g. Playwright `force:true` clicks) travel through on Flutter web.
    // Without an explicit `onTap` on the Semantics widget itself, a tap on
    // [flt-semantics-identifier="celebration-overflow-card"] never reaches
    // the InkWell — the inner InkWell creates its own descendant semantics
    // node that the outer identifier wrapper does not own. `container: true`
    // collapses the subtree into a single AOM node so the assistive-tech
    // (and Playwright AOM) tap target lines up with the visual hit region.
    // `widget.onTap` is wired to BOTH the Semantics and the InkWell so
    // Flutter-native gestures (`tester.tap` in widget tests, real-device
    // touches) keep the visual ripple while AOM dispatch still resolves
    // the same callback.
    return Semantics(
      identifier: 'celebration-overflow-card',
      container: true,
      button: true,
      label: label,
      onTap: widget.onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          // Keep the ripple inside the rounded border — without this, the
          // splash bleeds past the corner radius on Material 3.
          splashColor: AppColors.hotViolet.withValues(alpha: 0.16),
          highlightColor: AppColors.hotViolet.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hair, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.celebrationOverflowLabel(widget.overflowCount),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: AppColors.textCream,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.celebrationOverflowTapHint,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: AppColors.textDim,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
