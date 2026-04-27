/// Widget tests for [TitlesScreen] (Phase 18c, stage 8).
///
/// The titles screen lives at `/saga/titles` and lets the user browse the
/// 78-entry per-body-part title catalog, see which titles they've earned,
/// and equip any earned title (atomically, via [TitlesRepository.equipTitle]).
///
/// **Locked behaviors:**
///   * AppBar title is the localized `titlesScreenTitle`.
///   * Empty state (no earned titles) renders the localized
///     `titlesEmptyState` copy and a hero-icon decoration. The catalog rows
///     still render below it (locked rows are useful as a roadmap for the
///     user — they show what's available to earn).
///   * Earned rows render the localized title name (via [localizedTitleCopy])
///     in textCream. The single equipped row renders an "EQUIPPED"
///     indicator and the row's body-part name.
///   * Locked rows render the localized title name dimmed (textDim) plus the
///     rank-threshold breadcrumb ("Rank N").
///   * Tapping an earned but unequipped row invokes
///     `TitlesRepository.equipTitle(slug)` exactly once. The provider
///     invalidation is verified by the orchestrator (not this widget test).
///
/// **Why we override providers directly:** the screen reads
/// [titleCatalogProvider], [earnedTitlesProvider], and
/// [titlesRepositoryProvider]. Mocking the repo lets us count `equipTitle`
/// calls without needing a Supabase client.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/rpg/data/titles_repository.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/title.dart' as rpg;
import 'package:repsaga/features/rpg/providers/earned_titles_provider.dart';
import 'package:repsaga/features/rpg/ui/titles_screen.dart';
import 'package:repsaga/l10n/app_localizations.dart';

class _MockTitlesRepository extends Mock implements TitlesRepository {}

const _r5Slug = 'chest_r5_initiate_of_the_forge';
const _r10Slug = 'chest_r10_plate_bearer';
const _backR5Slug = 'back_r5_lattice_touched';

rpg.Title _title(String slug, BodyPart bp, int rank) =>
    rpg.Title(slug: slug, bodyPart: bp, rankThreshold: rank);

/// A trimmed catalog (3 entries) — enough to verify section grouping and the
/// earned/locked split without dragging in all 78 arb keys.
final _trimmedCatalog = <rpg.Title>[
  _title(_r5Slug, BodyPart.chest, 5),
  _title(_r10Slug, BodyPart.chest, 10),
  _title(_backR5Slug, BodyPart.back, 5),
];

EarnedTitleEntry _earned(
  String slug,
  BodyPart bp,
  int rank, {
  bool active = false,
}) => EarnedTitleEntry(
  title: _title(slug, bp, rank),
  earnedAt: DateTime.utc(2026, 4, 26),
  isActive: active,
);

Widget _buildApp({
  required List<EarnedTitleEntry> earned,
  required _MockTitlesRepository repo,
}) {
  return ProviderScope(
    overrides: [
      titlesRepositoryProvider.overrideWithValue(repo),
      titleCatalogProvider.overrideWith((_) async => _trimmedCatalog),
      earnedTitlesProvider.overrideWith((_) async => earned),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TitlesScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    // mocktail's any() needs a fallback for non-primitives; equipTitle takes
    // a String which mocktail handles natively.
  });

  group('TitlesScreen', () {
    testWidgets('renders empty state when no earned titles', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _MockTitlesRepository();
      await tester.pumpWidget(_buildApp(earned: const [], repo: repo));
      await tester.pumpAndSettle();

      // AppBar title.
      expect(find.text('Titles'), findsOneWidget);

      // Empty-state copy.
      expect(
        find.text('Earn your first title by ranking up a body part.'),
        findsOneWidget,
      );

      // No EQUIPPED chip when nothing is equipped.
      expect(find.text('EQUIPPED'), findsNothing);
    });

    testWidgets(
      'renders earned + locked rows with EQUIPPED indicator on the active title',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _MockTitlesRepository();
        await tester.pumpWidget(
          _buildApp(
            earned: [
              _earned(_r5Slug, BodyPart.chest, 5, active: true),
              _earned(_backR5Slug, BodyPart.back, 5),
            ],
            repo: repo,
          ),
        );
        await tester.pumpAndSettle();

        // Earned + active row shows EQUIPPED.
        expect(find.text('EQUIPPED'), findsOneWidget);

        // Both earned title names render.
        expect(find.text('Initiate of the Forge'), findsOneWidget);
        expect(find.text('Lattice-Touched'), findsOneWidget);

        // The locked R10 row is also listed (chest section continues).
        expect(find.text('Plate-Bearer'), findsOneWidget);
      },
    );

    testWidgets('tapping an earned row invokes equipTitle once with the slug', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _MockTitlesRepository();
      when(() => repo.equipTitle(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildApp(
          earned: [
            _earned(_r5Slug, BodyPart.chest, 5, active: true),
            _earned(_backR5Slug, BodyPart.back, 5),
          ],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the back R5 (earned, unequipped) row by name.
      await tester.tap(find.text('Lattice-Touched'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.equipTitle(_backR5Slug)).called(1);
    });

    testWidgets('tapping a locked row does NOT invoke equipTitle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _MockTitlesRepository();

      await tester.pumpWidget(
        _buildApp(
          earned: [_earned(_r5Slug, BodyPart.chest, 5, active: true)],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // R10 is locked (not in earned list). Tap it — must be a no-op.
      await tester.tap(find.text('Plate-Bearer'));
      await tester.pump();

      verifyNever(() => repo.equipTitle(any()));
    });

    testWidgets('tapping the already-equipped row does NOT invoke equipTitle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _MockTitlesRepository();

      await tester.pumpWidget(
        _buildApp(
          earned: [_earned(_r5Slug, BodyPart.chest, 5, active: true)],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the already-equipped row — UI should treat this as a no-op
      // (defensive: avoid hitting the Supabase round-trip for the same slug).
      await tester.tap(find.text('Initiate of the Forge'));
      await tester.pump();

      verifyNever(() => repo.equipTitle(any()));
    });
  });
}
