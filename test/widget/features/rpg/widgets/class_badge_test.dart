/// Widget tests for [ClassBadge] (Phase 18b stub → Phase 18e real classes).
///
/// The kickoff lock requires the slot to ALWAYS render — even when the
/// upstream provider is loading and no class has been derived yet. The badge
/// transitions from the day-1 placeholder copy ("The iron will name you.")
/// to the real localized class label as soon as data arrives.
///
/// Tests:
///   1. Null [characterClass] renders the placeholder copy.
///   2. Each of the 8 class variants renders its localized label (en).
///   3. Visual contract: stub state uses textDim italic; real label uses
///      hotViolet upright.
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

    testWidgets('real-class state renders in hotViolet upright', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(CharacterClass.bulwark));
      await tester.pump();

      // Resolve the localized label so the assertion does not break under
      // editorial copy revisions to `app_en.arb`.
      final ctx = tester.element(find.byType(Scaffold));
      final l10n = AppLocalizations.of(ctx);
      final text = tester.widget<Text>(find.text(l10n.classBulwark));
      expect(text.style?.color, AppColors.hotViolet);
      expect(text.style?.fontStyle, FontStyle.normal);
    });
  });
}
