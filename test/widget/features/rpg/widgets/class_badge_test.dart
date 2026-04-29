/// Widget tests for [ClassBadge] (Phase 18b stub → Phase 18e real classes
/// → 18e UX-critic pass).
///
/// The kickoff lock requires the slot to ALWAYS render — even when the
/// upstream provider is loading and no class has been derived yet. The badge
/// transitions from the day-1 placeholder copy ("The iron will name you.")
/// to the real localized class label as soon as data arrives.
///
/// Tests:
///   1. Null [characterClass] renders the placeholder copy.
///   2. Each of the 8 class variants renders its localized label (en).
///   3. Visual contract — three tiers (stub / Initiate / earned class):
///      * Stub: [AppColors.textDim] italic.
///      * Initiate: [AppColors.primaryViolet] upright (quieter "still on
///        the way" palette).
///      * Earned classes (berserker through ascendant):
///        [AppColors.hotViolet] upright.
///   4. Sigil corners — asymmetric [BorderRadius] (top-left/bottom-right
///      4dp, top-right/bottom-left 10dp) so the badge reads as a struck
///      faction mark, not a tappable Material chip.
///   5. Type scale — label uses [TextTheme.titleMedium], not titleSmall.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/rpg/models/character_class.dart';
import 'package:repsaga/features/rpg/ui/widgets/class_badge.dart';
import 'package:repsaga/l10n/app_localizations.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(CharacterClass? cls) {
  return TestMaterialApp(
    home: Scaffold(
      body: Center(child: ClassBadge(characterClass: cls)),
    ),
  );
}

/// Each of the 8 v1 classes paired with its expected en label so we can
/// loop the variant coverage instead of duplicating boilerplate per case.
const _expectedEnLabels = <CharacterClass, String>{
  CharacterClass.initiate: 'Initiate',
  CharacterClass.berserker: 'Berserker',
  CharacterClass.bulwark: 'Bulwark',
  CharacterClass.sentinel: 'Sentinel',
  CharacterClass.pathfinder: 'Pathfinder',
  CharacterClass.atlas: 'Atlas',
  CharacterClass.anchor: 'Anchor',
  CharacterClass.ascendant: 'Ascendant',
};

void main() {
  group('ClassBadge', () {
    testWidgets('null characterClass renders the placeholder copy', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(null));
      await tester.pump();

      expect(find.text('The iron will name you.'), findsOneWidget);
    });

    for (final entry in _expectedEnLabels.entries) {
      final cls = entry.key;
      final label = entry.value;
      testWidgets('${cls.slug} renders the localized label "$label"', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(cls));
        await tester.pump();

        expect(find.text(label), findsOneWidget);
        expect(find.text('The iron will name you.'), findsNothing);
      });
    }

    testWidgets('stub state renders in textDim italic', (tester) async {
      await tester.pumpWidget(_wrap(null));
      await tester.pump();

      final text = tester.widget<Text>(find.text('The iron will name you.'));
      expect(text.style?.color, AppColors.textDim);
      expect(text.style?.fontStyle, FontStyle.italic);
    });

    testWidgets(
      'earned-class state (e.g. bulwark) renders in hotViolet upright',
      (tester) async {
        await tester.pumpWidget(_wrap(CharacterClass.bulwark));
        await tester.pump();

        // Resolve the localized label so the assertion does not break under
        // editorial copy revisions to `app_en.arb`.
        final ctx = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(ctx);
        final text = tester.widget<Text>(find.text(l10n.classBulwark));
        expect(text.style?.color, AppColors.hotViolet);
        expect(text.style?.fontStyle, FontStyle.normal);
      },
    );

    testWidgets(
      'Initiate renders in primaryViolet (quieter still-on-the-way palette)',
      (tester) async {
        // UX-critic finding 1: pre-tightening, every resolved class shared
        // the same hotViolet palette so a day-3 Initiate looked identical to
        // a 4-year veteran's Ascendant. Initiate now gets primaryViolet text
        // — visibly quieter than the seven earned classes — so the prestige
        // curve has somewhere to climb.
        await tester.pumpWidget(_wrap(CharacterClass.initiate));
        await tester.pump();

        final ctx = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(ctx);
        final text = tester.widget<Text>(find.text(l10n.classInitiate));
        expect(text.style?.color, AppColors.primaryViolet);
        expect(
          text.style?.color,
          isNot(AppColors.hotViolet),
          reason:
              'Initiate must use the quieter primaryViolet tier — '
              'reusing hotViolet collapses the two-tier prestige distinction.',
        );
        expect(text.style?.fontStyle, FontStyle.normal);
      },
    );

    testWidgets(
      'sigil corners: BorderRadius is asymmetric, not a Material chip',
      (tester) async {
        // UX-critic finding 2: a symmetric 8-10dp radius reads as a
        // tappable Material chip alongside ElevatedButton, OutlinedButton,
        // CardTheme, and the title pill. Asymmetric corners
        // (TL+BR=4, TR+BL=10) read as a struck faction mark instead.
        await tester.pumpWidget(_wrap(CharacterClass.bulwark));
        await tester.pump();

        // Find the Container that owns the badge decoration. The badge is
        // the only Container in this widget tree's body, so a single match
        // is expected — but scope to "has a BoxDecoration" defensively in
        // case TestMaterialApp adds wrappers in the future.
        final containerFinder = find.descendant(
          of: find.byType(Scaffold),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        final container = tester.widgetList<Container>(containerFinder).first;
        final decoration = container.decoration! as BoxDecoration;
        final radius = decoration.borderRadius! as BorderRadius;
        expect(radius.topLeft, const Radius.circular(4));
        expect(radius.topRight, const Radius.circular(10));
        expect(radius.bottomLeft, const Radius.circular(10));
        expect(radius.bottomRight, const Radius.circular(4));
      },
    );

    testWidgets(
      'label uses titleMedium type scale (not titleSmall metadata size)',
      (tester) async {
        // UX-critic finding 3: titleSmall (~14sp) reads as metadata under
        // the 56sp Rajdhani LVL numeral; titleMedium (~16sp) restores the
        // intended hierarchy LVL > class > title pill. We assert the
        // resolved text style's fontSize matches the theme's titleMedium.
        await tester.pumpWidget(_wrap(CharacterClass.bulwark));
        await tester.pump();

        final ctx = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(ctx);
        final text = tester.widget<Text>(find.text(l10n.classBulwark));
        final theme = Theme.of(ctx);
        expect(
          text.style?.fontSize,
          theme.textTheme.titleMedium?.fontSize,
          reason:
              'Class badge must use titleMedium (~16sp) so it does not '
              'recede beneath the LVL numeral.',
        );
      },
    );
  });
}
