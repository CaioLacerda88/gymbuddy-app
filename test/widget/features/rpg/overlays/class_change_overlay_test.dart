/// Widget tests for [ClassChangeOverlay] (BUG-011, Cluster 3).
///
/// The 1600ms choreography choreography is locked at the spec level (see
/// `lib/features/rpg/ui/overlays/class_change_overlay.dart` docstring).
/// These tests pin:
///   * Class name + subtitle render
///   * "before: {className}" only fires on Initiate→first transition
///   * Double-pulse haptic (heavyImpact + mediumImpact) at t=700ms,
///     idempotent (one fire across the entire timeline)
///   * NO heroGold pixels anywhere — class-up is violet-only end-to-end,
///     the differentiator from rank-up's gold peak
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/rpg/models/character_class.dart';
import 'package:repsaga/features/rpg/ui/overlays/class_change_overlay.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(Widget child) => TestMaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Walk the widget tree under [root] and look for any reference to
/// [AppColors.heroGold] in:
///   * `Text.style.color`
///   * `Container.decoration.color` and `BoxShadow.color` chain
///   * `ColoredBox.color`
///   * `Opacity` + `DecoratedBox` chains
///
/// Returns true if no heroGold reference is found at any depth.
///
/// **Why a tree-walking helper instead of golden tests:** the rank-up
/// overlay uses heroGold legitimately (200-500ms gold-hold beat). A
/// golden-image diff between class-up and rank-up wouldn't pin the
/// "no heroGold" invariant — both could regress without a goldens
/// failure. The structural assertion gives us a load-bearing invariant
/// the visual test surface can't.
bool _hasHeroGoldDescendant(WidgetTester tester, Type rootType) {
  for (final w in tester.allWidgets) {
    if (w is Text) {
      if (w.style?.color == AppColors.heroGold) return true;
    } else if (w is Container) {
      final deco = w.decoration;
      if (deco is BoxDecoration) {
        if (deco.color == AppColors.heroGold) return true;
        for (final s in deco.boxShadow ?? const <BoxShadow>[]) {
          if (s.color == AppColors.heroGold) return true;
        }
        final border = deco.border;
        if (border is Border && border.top.color == AppColors.heroGold) {
          return true;
        }
      }
    } else if (w is ColoredBox) {
      if (w.color == AppColors.heroGold) return true;
    } else if (w is DecoratedBox) {
      final deco = w.decoration;
      if (deco is BoxDecoration && deco.color == AppColors.heroGold) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  group('ClassChangeOverlay', () {
    late int hapticHeavyCount;
    late int hapticMediumCount;

    setUp(() {
      hapticHeavyCount = 0;
      hapticMediumCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              if (call.arguments == 'HapticFeedbackType.heavyImpact') {
                hapticHeavyCount += 1;
              } else if (call.arguments == 'HapticFeedbackType.mediumImpact') {
                hapticMediumCount += 1;
              }
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders class name (English class label)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ClassChangeOverlay(
            fromClass: CharacterClass.initiate,
            toClass: CharacterClass.bulwark,
          ),
        ),
      );
      // Mount + advance past the name reveal beat (700-1000ms).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      // Cluster-3 review (2026-05-02): the headline now renders the class
      // name with a per-character stagger (each glyph is its own Text
      // widget so the 700-1000ms reveal can fade letter-by-letter). The
      // previous `ClipRect` wipe cut mid-glyph for long pt-BR names like
      // "DESBRAVADOR". Pin the new structural contract: scope the search
      // to the inner `class-change-name-label` Semantics node and join
      // its Text descendants in tree order.
      final headlineSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == 'class-change-name-label',
      );
      expect(headlineSemantics, findsOneWidget);
      final glyphFinder = find.descendant(
        of: headlineSemantics,
        matching: find.byType(Text),
      );
      final glyphs = tester
          .widgetList<Text>(glyphFinder)
          .toList(growable: false);
      final rendered = glyphs.map((t) => t.data ?? '').join();
      expect(
        rendered,
        equals('BULWARK'),
        reason:
            'Per-character reveal should produce one Text per uppercase '
            'glyph; concatenating in tree order must equal the class name.',
      );
    });

    testWidgets('renders subtitle line at the end of the choreography', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ClassChangeOverlay(
            fromClass: CharacterClass.initiate,
            toClass: CharacterClass.bulwark,
          ),
        ),
      );
      await tester.pump();
      // Advance to the subtitle beat (1400-1600ms).
      await tester.pump(const Duration(milliseconds: 1600));

      expect(find.text('Your journey has earned a name.'), findsOneWidget);
    });

    testWidgets(
      'renders "before: {className}" subtitle ONLY on Initiate→first transition',
      (tester) async {
        // Initiate→Bulwark must show the previous label.
        await tester.pumpWidget(
          _wrap(
            const ClassChangeOverlay(
              fromClass: CharacterClass.initiate,
              toClass: CharacterClass.bulwark,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));
        expect(find.text('before: Initiate'), findsOneWidget);

        // Bulwark→Sentinel must NOT show the previous label.
        await tester.pumpWidget(
          _wrap(
            const ClassChangeOverlay(
              fromClass: CharacterClass.bulwark,
              toClass: CharacterClass.sentinel,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));
        // The "before" prefix shouldn't appear at all on a non-Initiate
        // transition. Match by substring to defend against capitalisation
        // drift in copy.
        expect(find.textContaining('before:'), findsNothing);
      },
    );

    testWidgets(
      'fires double-pulse haptic at t=700ms (heavy + medium), idempotent',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const ClassChangeOverlay(
              fromClass: CharacterClass.initiate,
              toClass: CharacterClass.bulwark,
            ),
          ),
        );
        await tester.pump();
        // Before t=700ms — neither pulse has fired.
        await tester.pump(const Duration(milliseconds: 600));
        expect(hapticHeavyCount, 0);
        expect(hapticMediumCount, 0);

        // Past t=700ms but before t=780ms — heavy fires, medium hasn't yet.
        await tester.pump(const Duration(milliseconds: 110));
        expect(hapticHeavyCount, 1);
        expect(hapticMediumCount, 0);

        // Past t=780ms — medium fires.
        await tester.pump(const Duration(milliseconds: 80));
        expect(hapticHeavyCount, 1);
        expect(hapticMediumCount, 1);

        // Stay alive through the rest of the choreography — no extra
        // pulses fire (one-fire guarantee via the per-pulse booleans).
        await tester.pump(const Duration(milliseconds: 800));
        expect(hapticHeavyCount, 1);
        expect(hapticMediumCount, 1);
      },
    );

    testWidgets('NO heroGold pixels anywhere in the descendant tree', (
      tester,
    ) async {
      // BUG-011 differentiator from RankUpOverlay: the class-change
      // celebration is violet-only end-to-end. Rank-up uses heroGold at
      // its gold-hold beat (200-500ms). If a future regression adds a
      // gold accent to the class-change overlay, we lose the visual
      // hierarchy that distinguishes the two beats.
      await tester.pumpWidget(
        _wrap(
          const ClassChangeOverlay(
            fromClass: CharacterClass.initiate,
            toClass: CharacterClass.bulwark,
          ),
        ),
      );
      // Sample several beats across the timeline so a gold flash on any
      // single frame would surface.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_hasHeroGoldDescendant(tester, ClassChangeOverlay), isFalse);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_hasHeroGoldDescendant(tester, ClassChangeOverlay), isFalse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasHeroGoldDescendant(tester, ClassChangeOverlay), isFalse);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_hasHeroGoldDescendant(tester, ClassChangeOverlay), isFalse);
    });

    testWidgets('total duration matches ClassChangeOverlay.totalDuration', (
      tester,
    ) async {
      // The celebration player schedules its auto-pop against
      // ClassChangeOverlay.totalDuration. If the choreography drifts
      // past 1600ms (or compresses below), the player pops mid-animation.
      // Pin the public contract.
      expect(
        ClassChangeOverlay.totalDuration,
        const Duration(milliseconds: 1600),
      );
    });

    testWidgets('completes choreography without leaking tickers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ClassChangeOverlay(
            fromClass: CharacterClass.bulwark,
            toClass: CharacterClass.sentinel,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
      // tester would flag a pending timer at teardown if the controller
      // leaked.
      expect(find.byType(ClassChangeOverlay), findsNothing);
    });
  });
}
