import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/radii.dart';
import '../../../l10n/app_localizations.dart';
import '../models/character_sheet_state.dart';
import '../models/vitality_state.dart';
import '../providers/character_sheet_provider.dart';
import 'widgets/active_title_pill.dart';
import 'widgets/body_part_rank_row.dart';
import 'widgets/class_badge.dart';
import 'widgets/codex_nav_row.dart';
import 'widgets/dormant_cardio_row.dart';
import 'widgets/rune_halo.dart';
import 'widgets/vitality_radar.dart';

/// `/profile` (the "Saga" tab) character sheet.
///
/// Replaces the legacy profile screen with the v1 RPG identity surface per
/// spec §13.1. Account/preferences settings move to `/profile/settings`,
/// reachable via the gear icon in the app bar.
///
/// **Composition (top-down):**
///   1. AppBar — "Saga" title + gear icon → `/profile/settings`.
///   2. Header — [RuneHalo] + Lvl numeral + [ClassBadge] + [ActiveTitlePill].
///   3. Onboarding hint — [firstSetAwakensCopy] banner when `lifetimeXp == 0`.
///   4. [VitalityRadar] — 320 dp hex radar.
///   5. Six [BodyPartRankRow]s — asymmetric (expanded for trained,
///      compressed for untrained).
///   6. [DormantCardioRow] — single distinct row.
///   7. Three [CodexNavRow]s — Stats / Titles / History.
///
/// AsyncValue handling:
///   * loading → runic skeleton (placeholder rows).
///   * error   → "abyss" empty state with retry.
///   * data    → full layout.
class CharacterSheetScreen extends ConsumerWidget {
  const CharacterSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sheetAsync = ref.watch(characterSheetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sagaTabLabel),
        actions: [
          Semantics(
            container: true,
            identifier: 'saga-settings-btn',
            button: true,
            label: l10n.settingsLabel,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settingsLabel,
              onPressed: () => context.push('/profile/settings'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: sheetAsync.when(
          data: (sheet) => _CharacterSheetBody(sheet: sheet),
          loading: () => const _CharacterSheetSkeleton(),
          error: (err, _) => _CharacterSheetError(
            onRetry: () => ref.invalidate(characterSheetProvider),
          ),
        ),
      ),
    );
  }
}

class _CharacterSheetBody extends StatelessWidget {
  const _CharacterSheetBody({required this.sheet});

  final CharacterSheetState sheet;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Semantics(
        container: true,
        identifier: 'character-sheet',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _SheetHeader(sheet: sheet),
            const SizedBox(height: 16),
            if (sheet.isZeroHistory) ...[
              const _FirstSetAwakensBanner(),
              const SizedBox(height: 8),
            ],
            Center(
              child: Semantics(
                container: true,
                identifier: 'vitality-radar',
                child: VitalityRadar(entries: sheet.bodyPartProgress),
              ),
            ),
            const SizedBox(height: 24),
            _BodyPartRows(entries: sheet.bodyPartProgress),
            const SizedBox(height: 16),
            Semantics(
              container: true,
              identifier: 'dormant-cardio-row',
              child: const DormantCardioRow(),
            ),
            const SizedBox(height: 24),
            const _CodexNavSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.sheet});

  final CharacterSheetState sheet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Semantics(
            container: true,
            identifier: 'rune-halo',
            child: RuneHalo(state: sheet.haloState),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            identifier: 'character-level',
            child: Text(
              'Lvl ${sheet.characterLevel}',
              style: GoogleFonts.rajdhani(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: AppColors.textCream,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            identifier: 'class-badge',
            child: ClassBadge(className: sheet.className),
          ),
          if (sheet.activeTitle != null && sheet.activeTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              container: true,
              identifier: 'active-title-pill',
              child: ActiveTitlePill(title: sheet.activeTitle),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirstSetAwakensBanner extends StatelessWidget {
  const _FirstSetAwakensBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: AppColors.primaryViolet.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Semantics(
          container: true,
          identifier: 'first-set-awakens-banner',
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.hotViolet,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.firstSetAwakensCopy,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textCream,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyPartRows extends StatelessWidget {
  const _BodyPartRows({required this.entries});

  final List<BodyPartSheetEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in entries)
          Semantics(
            container: true,
            identifier: 'body-part-row-${entry.bodyPart.dbValue}',
            child: BodyPartRankRow(entry: entry),
          ),
      ],
    );
  }
}

class _CodexNavSection extends StatelessWidget {
  const _CodexNavSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          CodexNavRow(
            label: l10n.statsDeepDiveLabel,
            semanticIdentifier: 'codex-nav-stats',
            onTap: () => context.push('/saga/stats'),
          ),
          const SizedBox(height: 8),
          CodexNavRow(
            label: l10n.titlesLabel,
            semanticIdentifier: 'codex-nav-titles',
            onTap: () => context.push('/saga/titles'),
          ),
          const SizedBox(height: 8),
          CodexNavRow(
            label: l10n.historyLabel,
            semanticIdentifier: 'codex-nav-history',
            onTap: () => context.push('/home/history'),
          ),
        ],
      ),
    );
  }
}

class _CharacterSheetSkeleton extends StatelessWidget {
  const _CharacterSheetSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Halo placeholder.
            Container(
              width: 156,
              height: 156,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface2,
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 4; i++) ...[
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CharacterSheetError extends StatelessWidget {
  const _CharacterSheetError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.textDim, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.error,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Use VitalityState.dormant border just to stay on-palette.
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: VitalityState.active.borderColor,
              ),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
