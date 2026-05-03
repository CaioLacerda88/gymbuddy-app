import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/radii.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cross_build_title_evaluator.dart';
import '../models/body_part.dart';
import '../models/title.dart' as rpg;
import '../providers/earned_titles_provider.dart';
import '../providers/rpg_progress_provider.dart';
import 'widgets/body_part_localization.dart';
import 'widgets/title_localization.dart';

/// `/saga/titles` — title library screen (Phase 18c, stage 8; Phase 18e
/// extended with character-level + cross-build sections).
///
/// Replaces the [SagaStubScreen] previously routed at this path. Renders the
/// full title catalog (90 entries v1: 78 per-body-part + 7 character-level +
/// 5 cross-build) grouped into:
///   * One section per body part for [BodyPartTitle] (sorted by rank threshold).
///   * One "CHARACTER LEVEL" section for [CharacterLevelTitle] (sorted by
///     level threshold).
///   * One "DISTINCTION" section for [CrossBuildTitle] (catalog order).
///
/// Each row indicates earned/locked state and supports tap-to-equip on
/// earned rows regardless of variant.
///
/// **Architecture decisions:**
///   * **Pure consumer widget** — no notifier of its own. The screen reads
///     [titleCatalogProvider] (asset-backed catalog) + [earnedTitlesProvider]
///     (per-user earned rows). Equip writes go straight through
///     [TitlesRepository.equipTitle] and invalidate the providers downstream
///     so a single notifier is unnecessary.
///   * **Earned/locked overlay** — the catalog is the master list; earned
///     rows are derived by zipping against [earnedTitlesProvider]. Locked
///     rows render as a roadmap, which doubles as motivation: the user sees
///     "Plate-Bearer" greyed out at Rank 10 and knows what to chase.
///   * **Equip path:** tapping an earned but unequipped row calls
///     [TitlesRepository.equipTitle]. Optimistic UI is *not* used here — the
///     screen waits for the round-trip to complete and refreshes via
///     `ref.invalidate(earnedTitlesProvider)`. This is the rare slow-loop
///     screen where correctness matters more than snappiness; equipping a
///     title is a once-a-week interaction.
///   * **Active row taps are no-ops:** tapping the already-equipped row does
///     nothing. We don't unequip from this surface — that's reserved for the
///     character sheet's title pill long-press in a future phase, and avoids
///     accidental "tap the wrong row to peek at flavor" → user lost their
///     title.
///   * **Locked row taps are also no-ops:** there's no flavor-preview UX in
///     v1 — the rank-threshold breadcrumb is enough hint. Phase 18d may add
///     a long-press preview sheet.
///
/// **Loading + error states:**
///   * Catalog and earned-titles use AsyncValue. While either is loading we
///     render a centered progress indicator. On error we show a centered
///     localized error string — the screen is recoverable via re-entry, so a
///     dedicated retry button is overkill.
///   * Empty state (no earned titles) renders the localized
///     [titlesEmptyState] copy at the top of the body, *above* the catalog.
///     Showing the locked-row roadmap below the empty state turns "you have
///     nothing" into "here's what's coming."
class TitlesScreen extends ConsumerStatefulWidget {
  const TitlesScreen({super.key});

  @override
  ConsumerState<TitlesScreen> createState() => _TitlesScreenState();
}

class _TitlesScreenState extends ConsumerState<TitlesScreen> {
  /// Slug of the most recently tapped row that's currently being persisted.
  /// Locks the row visually so a double-tap doesn't fire two `equipTitle`
  /// calls; cleared in `finally`. We keep this in widget state (not a
  /// provider) because it's purely transient UI feedback.
  String? _equippingSlug;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogAsync = ref.watch(titleCatalogProvider);
    final earnedAsync = ref.watch(earnedTitlesProvider);
    // BUG-014: cross-build locked rows render structured stat chips
    // computed from the user's current rank distribution. Reading the
    // RPG snapshot here keeps the row widget pure (no Riverpod inside
    // the row); we pass a `Map<BodyPart, int>` down.
    final snapshotAsync = ref.watch(rpgProgressProvider);

    return Semantics(
      // `container: true` forces Flutter to emit a flt-semantics node for this
      // identifier even when no descendant Semantics carries label/role/action.
      // Without it, Flutter web's AOM elides identifier-only wrappers from the
      // accessibility tree on rebuild, breaking E2E selectors. Same pattern as
      // 'character-sheet', 'saga-stats-screen' (via container), 'volume-peak-table',
      // and every other identifier wrapper in the codebase that needs to survive
      // rebuilds regardless of child semantic content.
      container: true,
      identifier: 'titles-screen',
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.titlesScreenTitle)),
        body: _buildBody(catalogAsync, earnedAsync, snapshotAsync),
      ),
    );
  }

  /// BUG-027: combine the catalog + earned async branches into a single
  /// loading/error/data switch. The previous implementation rendered a
  /// `CircularProgressIndicator` once for the catalog and again for the
  /// earned list — two stacked spinners that flashed in sequence on cold
  /// open. Here we treat both providers as a unit: while either is loading
  /// we show the branded [_TitlesSkeleton] (mirrors `_CharacterSheetSkeleton`),
  /// and only enter the data branch once both have resolved.
  Widget _buildBody(
    AsyncValue<List<rpg.Title>> catalogAsync,
    AsyncValue<List<EarnedTitleEntry>> earnedAsync,
    AsyncValue<RpgProgressSnapshot> snapshotAsync,
  ) {
    if (catalogAsync.hasError) {
      return _ErrorState(message: '${catalogAsync.error}');
    }
    if (earnedAsync.hasError) {
      return _ErrorState(message: '${earnedAsync.error}');
    }
    if (catalogAsync.isLoading || earnedAsync.isLoading) {
      return const _TitlesSkeleton();
    }
    // RPG snapshot is allowed to be loading/missing — the chip falls
    // back to a default-row distribution (every track at 1) which still
    // renders the floors correctly. This avoids a third loading branch
    // for what's purely additional stat data.
    final ranks = <BodyPart, int>{
      for (final bp in activeBodyParts)
        bp: snapshotAsync.value?.byBodyPart[bp]?.rank ?? 1,
    };
    return _Body(
      catalog: catalogAsync.requireValue,
      earned: earnedAsync.requireValue,
      ranks: ranks,
      onTapEarned: _equip,
    );
  }

  Future<void> _equip(rpg.Title title) async {
    if (_equippingSlug != null) return; // re-entrancy guard.
    setState(() => _equippingSlug = title.slug);
    try {
      final repo = ref.read(titlesRepositoryProvider);
      await repo.equipTitle(title.slug);
      // Invalidate so the screen reflects the new is_active row, and so the
      // character sheet's title pill picks up the change on next visit.
      ref.invalidate(earnedTitlesProvider);
      ref.invalidate(equippedTitleSlugProvider);
    } finally {
      if (mounted) setState(() => _equippingSlug = null);
    }
  }
}

/// Maps catalog → earned-by-slug for O(1) lookup, then renders a single
/// scroll view with one section per body part. Pulled out as a separate
/// widget so the loading/error branches stay legible in the parent.
class _Body extends StatelessWidget {
  const _Body({
    required this.catalog,
    required this.earned,
    required this.ranks,
    required this.onTapEarned,
  });

  final List<rpg.Title> catalog;
  final List<EarnedTitleEntry> earned;

  /// Current rank distribution for the user. Drives the BUG-014
  /// structured-stat chip on locked cross-build rows. Always populated
  /// for every active body part (defaults to rank 1 when the snapshot
  /// has no row).
  final Map<BodyPart, int> ranks;

  final void Function(rpg.Title) onTapEarned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final earnedBySlug = <String, EarnedTitleEntry>{
      for (final e in earned) e.title.slug: e,
    };
    final activeSlug = earned
        .where((e) => e.isActive)
        .map((e) => e.title.slug)
        .firstOrNull;

    // Group by body part for [BodyPartTitle] entries, preserving the
    // canonical [activeBodyParts] order. Other variants are bucketed by
    // their kind for the trailing two sections.
    final byBodyPart = <BodyPart, List<rpg.BodyPartTitle>>{};
    final characterLevelTitles = <rpg.CharacterLevelTitle>[];
    final crossBuildTitles = <rpg.CrossBuildTitle>[];
    for (final t in catalog) {
      switch (t) {
        case rpg.BodyPartTitle(:final bodyPart):
          byBodyPart.putIfAbsent(bodyPart, () => []).add(t);
        case rpg.CharacterLevelTitle():
          characterLevelTitles.add(t);
        case rpg.CrossBuildTitle():
          crossBuildTitles.add(t);
      }
    }
    for (final list in byBodyPart.values) {
      list.sort((a, b) => a.rankThreshold.compareTo(b.rankThreshold));
    }
    characterLevelTitles.sort(
      (a, b) => a.levelThreshold.compareTo(b.levelThreshold),
    );

    final orderedBodyParts = activeBodyParts
        .where((bp) => byBodyPart.containsKey(bp))
        .toList(growable: false);

    Widget rowFor(rpg.Title title) => _TitleRow(
      title: title,
      earned: earnedBySlug[title.slug],
      isActive: activeSlug == title.slug,
      ranks: ranks,
      onTap: earnedBySlug.containsKey(title.slug) && activeSlug != title.slug
          ? () => onTapEarned(title)
          : null,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (earned.isEmpty)
          _EmptyState(copy: l10n.titlesEmptyState)
        else
          _ProgressHeader(
            earnedCount: earned.length,
            totalCount: catalog.length,
          ),
        const SizedBox(height: 16),
        for (final bp in orderedBodyParts) ...[
          _SectionHeader(label: localizedBodyPartName(bp, l10n).toUpperCase()),
          const SizedBox(height: 8),
          for (final title in byBodyPart[bp]!) rowFor(title),
          const SizedBox(height: 24),
        ],
        if (characterLevelTitles.isNotEmpty) ...[
          _SectionHeader(label: l10n.titlesSectionCharacterLevel),
          const SizedBox(height: 8),
          for (final title in characterLevelTitles) rowFor(title),
          const SizedBox(height: 24),
        ],
        if (crossBuildTitles.isNotEmpty) ...[
          _SectionHeader(label: l10n.titlesSectionCrossBuild),
          const SizedBox(height: 8),
          for (final title in crossBuildTitles) rowFor(title),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.earnedCount, required this.totalCount});

  final int earnedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        l10n.titlesProgressLabel(earnedCount, totalCount),
        style: AppTextStyles.label.copyWith(
          fontSize: 13,
          color: AppColors.textDim,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.copy});

  final String copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Opacity(
            opacity: 0.4,
            child: AppIcons.render(
              AppIcons.hero,
              color: AppColors.textDim,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copy,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textDim,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          fontSize: 12,
          color: AppColors.hotViolet,
          letterSpacing: 0.12 * 12,
        ),
      ),
    );
  }
}

/// Single title row.
///
/// **Why a flat layout (not a Card):** the screen renders ~78 rows; the
/// Material Card chrome would dominate the visual budget and fight the
/// codex aesthetic. We use a `surface2`-tinted container with a hairline
/// divider only when active.
///
/// **BUG-014 (Cluster 3) — locked cross-build rendering:**
///   * Locked cross-build titles render at `textDim @ 0.5` opacity (vs
///     full textDim for locked body-part / character-level titles).
///   * NO padlock icon on cross-build rows — the padlock connotes
///     "unavailable forever" (per-rank gates), but cross-build titles
///     are pattern gates the user can choose to chase. Opacity says
///     "not yet" without the finality of the lock glyph.
///   * A structured stat-line chip below the name shows the gap math
///     ("PEITO 42/60 · COSTAS 60/60 · PERNAS 60/60" for `iron_bound`).
///     Per PO call: gym-bro audience scans numbers, doesn't read prose.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.earned,
    required this.isActive,
    required this.ranks,
    this.onTap,
  });

  final rpg.Title title;

  /// Null when locked; non-null when the user has earned this title.
  final EarnedTitleEntry? earned;

  final bool isActive;

  /// User's current rank distribution. Used by locked cross-build rows
  /// to render the BUG-014 structured stat chip. Always non-null —
  /// the parent fills missing tracks with rank 1.
  final Map<BodyPart, int> ranks;

  /// Null disables the tap target (locked rows + the already-equipped row).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = localizedTitleCopy(title.slug, l10n);
    final isEarned = earned != null;
    final isCrossBuild = title is rpg.CrossBuildTitle;

    // BUG-014: locked cross-build titles fade to 0.5 opacity (vs full
    // textDim for other locked rows). The opacity gates the WHOLE row
    // so the structured chip and name fade together.
    final lockedCrossBuildLocked = isCrossBuild && !isEarned;
    final rowOpacity = lockedCrossBuildLocked ? 0.5 : 1.0;
    final nameColor = isEarned ? AppColors.textCream : AppColors.textDim;

    return Semantics(
      container: true,
      identifier: 'title-row-${title.slug}',
      child: Opacity(
        opacity: rowOpacity,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.surface2
                  : AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(color: AppColors.hotViolet, width: 1)
                  : null,
            ),
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy?.name ?? title.slug,
                        style: AppTextStyles.headline.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nameColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Sub-label: rank/level threshold for body-part /
                      // character-level rows; "Distinction" for earned
                      // cross-build rows; structured stat chip for
                      // locked cross-build rows.
                      _Sublabel(
                        title: title,
                        isEarned: isEarned,
                        ranks: ranks,
                        l10n: l10n,
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Semantics(
                    container: true,
                    identifier: 'equipped-title-label',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hotViolet.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.equippedLabel,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 11,
                          color: AppColors.hotViolet,
                          letterSpacing: 0.12 * 11,
                        ),
                      ),
                    ),
                  )
                // BUG-014: NO padlock for cross-build titles. The
                // padlock stays for body-part / character-level rows
                // because those are grind gates ("you must clear rank
                // 30 to unlock"); cross-build titles are pattern gates
                // (the lifter chooses the predicate to chase).
                else if (!isEarned && !isCrossBuild)
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.textDim.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sub-label rendering policy:
///   * `BodyPartTitle` → "Rank {N}"
///   * `CharacterLevelTitle` → "Level {N}"
///   * `CrossBuildTitle` (earned) → "Distinction" (single localized word)
///   * `CrossBuildTitle` (locked) → structured stat chip
///     "PEITO 42/60 · COSTAS 60/60" via [_CrossBuildStatChip]
///
/// Pulled out of [_TitleRow] so the chip widget can stay a stateless
/// child without piping every prop through three layers.
class _Sublabel extends StatelessWidget {
  const _Sublabel({
    required this.title,
    required this.isEarned,
    required this.ranks,
    required this.l10n,
  });

  final rpg.Title title;
  final bool isEarned;
  final Map<BodyPart, int> ranks;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = title;
    if (t is rpg.BodyPartTitle) {
      return _plainLabel(l10n.titlesRowRankThreshold(t.rankThreshold));
    }
    if (t is rpg.CharacterLevelTitle) {
      return _plainLabel(l10n.titlesRowCharacterLevel(t.levelThreshold));
    }
    if (t is rpg.CrossBuildTitle) {
      if (isEarned) {
        return _plainLabel(l10n.titlesRowCrossBuild);
      }
      return _CrossBuildStatChip(slug: t.slug, ranks: ranks, l10n: l10n);
    }
    return const SizedBox.shrink();
  }

  Widget _plainLabel(String text) => Text(
    text,
    style: AppTextStyles.label.copyWith(
      fontSize: 11,
      color: AppColors.textDim,
      letterSpacing: 0.08 * 11,
    ),
  );
}

/// BUG-014 structured stat chip — renders a row of "BODYPART current/floor"
/// tuples separated by middle dots. Cleared stats render at full textDim;
/// gapped stats render slightly dimmer so the eye lands on the cleared
/// progress (the "you've made it this far" affordance).
///
/// Tabular figures via the Rajdhani `numeric` tokens keep the stat columns
/// from jiggling between 1-digit and 2-digit ranks.
class _CrossBuildStatChip extends StatelessWidget {
  const _CrossBuildStatChip({
    required this.slug,
    required this.ranks,
    required this.l10n,
  });

  final String slug;
  final Map<BodyPart, int> ranks;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final stats = crossBuildStatsFor(slug, ranks);
    if (stats.isEmpty) {
      // Unknown cross-build slug — fall back to the localized
      // "Distinction" label. Defensive only; the catalog shouldn't ship
      // unknown trigger ids.
      return Text(
        l10n.titlesRowCrossBuild,
        style: AppTextStyles.label.copyWith(
          fontSize: 11,
          color: AppColors.textDim,
          letterSpacing: 0.08 * 11,
        ),
      );
    }
    final pieces = <InlineSpan>[];
    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      if (i > 0) {
        pieces.add(
          const TextSpan(
            text: '  ·  ',
            style: TextStyle(color: AppColors.textDim),
          ),
        );
      }
      final body = localizedBodyPartName(s.bodyPart, l10n).toUpperCase();
      pieces.add(
        TextSpan(
          text: '$body ${s.current}/${s.floor}',
          style: TextStyle(
            color: AppColors.textDim.withValues(alpha: s.isCleared ? 1.0 : 0.7),
          ),
        ),
      );
    }
    return Semantics(
      identifier: 'cross-build-stat-chip-$slug',
      container: true,
      child: Text.rich(
        TextSpan(
          children: pieces,
          style: AppTextStyles.label.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08 * 11,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.textDim),
        ),
      ),
    );
  }
}

/// BUG-027: branded skeleton shown while the catalog and/or earned-titles
/// providers are loading. Mirrors the `_CharacterSheetSkeleton` pattern: a
/// progress-header placeholder followed by three sections of placeholder
/// rows so the layout doesn't shift when real data lands.
class _TitlesSkeleton extends StatelessWidget {
  const _TitlesSkeleton();

  // Hoisted out of `build` (post-review) so each rebuild doesn't reallocate
  // the placeholder closures. Both placeholders are stateless and capture
  // nothing, so static methods are the cheapest scoping option.
  static Widget _rowPlaceholder() => Container(
    height: 56,
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(kRadiusSm),
    ),
  );

  static Widget _sectionHeaderPlaceholder() => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Container(
      height: 14,
      width: 120,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Progress header placeholder.
        Container(
          height: 16,
          width: 160,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
        ),
        const SizedBox(height: 16),
        for (var section = 0; section < 3; section++) ...[
          _sectionHeaderPlaceholder(),
          for (var i = 0; i < 3; i++) _rowPlaceholder(),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
