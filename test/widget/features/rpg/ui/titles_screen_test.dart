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
import 'package:repsaga/features/rpg/data/rpg_repository.dart';
import 'package:repsaga/features/rpg/data/titles_repository.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/body_part_progress.dart';
import 'package:repsaga/features/rpg/models/title.dart' as rpg;
import 'package:repsaga/features/rpg/providers/earned_titles_provider.dart';
import 'package:repsaga/features/rpg/providers/rpg_progress_provider.dart';
import 'package:repsaga/features/rpg/ui/titles_screen.dart';
import 'package:repsaga/l10n/app_localizations.dart';

class _MockTitlesRepository extends Mock implements TitlesRepository {}

const _r5Slug = 'chest_r5_initiate_of_the_forge';
const _r10Slug = 'chest_r10_plate_bearer';
const _backR5Slug = 'back_r5_lattice_touched';

rpg.Title _title(String slug, BodyPart bp, int rank) =>
    rpg.Title.bodyPart(slug: slug, bodyPart: bp, rankThreshold: rank);

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

  // ---------------------------------------------------------------------------
  // BUG-014 (Cluster 3) — locked cross-build rendering + structured chip
  // ---------------------------------------------------------------------------
  group('TitlesScreen — locked cross-build (BUG-014)', () {
    testWidgets(
      'locked cross-build row renders structured stat chip and NO padlock',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _MockTitlesRepository();
        // Pre-Cluster-3 snapshot: chest 50, back 40, legs 58 — close to
        // iron_bound (60/60/60) but not yet there. The chip should
        // render "CHEST 50/60 · BACK 40/60 · LEGS 58/60".
        final snapshot = RpgProgressSnapshot(
          byBodyPart: {
            BodyPart.chest: BodyPartProgress(
              userId: 'u',
              bodyPart: BodyPart.chest,
              totalXp: 1,
              rank: 50,
              vitalityEwma: 0,
              vitalityPeak: 0,
              lastEventAt: null,
              updatedAt: DateTime.utc(2026, 5, 2),
            ),
            BodyPart.back: BodyPartProgress(
              userId: 'u',
              bodyPart: BodyPart.back,
              totalXp: 1,
              rank: 40,
              vitalityEwma: 0,
              vitalityPeak: 0,
              lastEventAt: null,
              updatedAt: DateTime.utc(2026, 5, 2),
            ),
            BodyPart.legs: BodyPartProgress(
              userId: 'u',
              bodyPart: BodyPart.legs,
              totalXp: 1,
              rank: 58,
              vitalityEwma: 0,
              vitalityPeak: 0,
              lastEventAt: null,
              updatedAt: DateTime.utc(2026, 5, 2),
            ),
          },
          characterState: CharacterState.empty,
        );

        const ironBoundSlug = 'iron_bound';
        final catalog = <rpg.Title>[
          ..._trimmedCatalog,
          const rpg.Title.crossBuild(
            slug: ironBoundSlug,
            triggerId: rpg.CrossBuildTriggerId.ironBound,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              titlesRepositoryProvider.overrideWithValue(repo),
              titleCatalogProvider.overrideWith((_) async => catalog),
              earnedTitlesProvider.overrideWith((_) async => const []),
              rpgProgressProvider.overrideWith(
                () => _StubRpgProgressNotifier(snapshot),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TitlesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The structured chip is wrapped in
        // `Semantics(identifier: 'cross-build-stat-chip-iron_bound')`.
        expect(
          find.bySemanticsIdentifier('cross-build-stat-chip-iron_bound'),
          findsOneWidget,
        );

        // The chip text contains the stat tuples. The Text.rich widget
        // collapses them into a single line; assert against substrings.
        // Body-part names render uppercased; en locale: CHEST/BACK/LEGS.
        final chipFinder = find.bySemanticsIdentifier(
          'cross-build-stat-chip-iron_bound',
        );
        final chip = tester.widget<Semantics>(chipFinder);
        // Walk the chip subtree for the inner Text.
        final chipText = find.descendant(
          of: chipFinder,
          matching: find.byType(Text),
        );
        expect(chipText, findsOneWidget);
        final txt = tester.widget<Text>(chipText);
        // Text.rich uses textSpan, not data — recompose the displayed
        // string by walking the spans.
        final spans = (txt.textSpan! as TextSpan).children!;
        final composed = spans
            .whereType<TextSpan>()
            .map((s) => s.text ?? '')
            .join();
        expect(composed, contains('CHEST 50/60'));
        expect(composed, contains('BACK 40/60'));
        expect(composed, contains('LEGS 58/60'));

        // Padlock must NOT appear on the cross-build row.
        final ironBoundRow = find.bySemanticsIdentifier(
          'title-row-$ironBoundSlug',
        );
        expect(
          find.descendant(
            of: ironBoundRow,
            matching: find.byIcon(Icons.lock_outline),
          ),
          findsNothing,
          reason:
              'BUG-014: cross-build locked rows must not show the padlock '
              '(opacity says "not yet"; padlock connotes "unavailable forever").',
        );
        // Sanity: a body-part locked row (Plate-Bearer at R10) DOES still
        // show the padlock — pin the asymmetry.
        final lockedBodyPartRow = find.bySemanticsIdentifier(
          'title-row-$_r10Slug',
        );
        expect(
          find.descendant(
            of: lockedBodyPartRow,
            matching: find.byIcon(Icons.lock_outline),
          ),
          findsOneWidget,
        );

        // chip variable kept for the spans walk above; quiet the
        // unused-warning by using its semantics identifier defensively.
        expect(chip.properties.identifier, 'cross-build-stat-chip-iron_bound');
      },
    );

    testWidgets('locked cross-build row fades to 0.5 opacity (BUG-014)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _MockTitlesRepository();
      const slug = 'pillar_walker';
      final catalog = <rpg.Title>[
        ..._trimmedCatalog,
        const rpg.Title.crossBuild(
          slug: slug,
          triggerId: rpg.CrossBuildTriggerId.pillarWalker,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            titlesRepositoryProvider.overrideWithValue(repo),
            titleCatalogProvider.overrideWith((_) async => catalog),
            earnedTitlesProvider.overrideWith((_) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TitlesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the row + the Opacity ancestor inside it.
      final rowFinder = find.bySemanticsIdentifier('title-row-$slug');
      final opacityFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(Opacity),
      );
      // The row Opacity is the FIRST descendant Opacity (the row wraps
      // the entire content). The icon renders an inner Opacity for the
      // dim treatment, so we grab the row's wrapper specifically.
      final opacities = tester.widgetList<Opacity>(opacityFinder).toList();
      expect(opacities, isNotEmpty);
      expect(opacities.first.opacity, 0.5);
    });
  });
}

/// Minimal AsyncNotifier stub so [TitlesScreen] can read a
/// [RpgProgressSnapshot] without standing up a Supabase client. Production
/// notifier reads from `RpgRepository` which depends on `Supabase.instance`.
class _StubRpgProgressNotifier extends RpgProgressNotifier {
  _StubRpgProgressNotifier(this._snapshot);
  final RpgProgressSnapshot _snapshot;

  @override
  Future<RpgProgressSnapshot> build() async => _snapshot;
}
