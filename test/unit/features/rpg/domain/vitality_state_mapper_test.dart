import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/rpg/domain/vitality_state_mapper.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/vitality_state.dart';

/// Canonical mapper boundary + palette tests.
///
/// These pin the §8.4 contract:
///   * `pct == 0`      → dormant
///   * `(0, 0.30]`     → fading
///   * `(0.30, 0.70]`  → active
///   * `(0.70, 1.00]`  → radiant
///
/// Plus the locked body-part palette (UX-critic warning: drift across
/// surfaces if not pinned in one place).
void main() {
  group('VitalityStateMapper.fromPercent — boundaries', () {
    test('exactly 0 → dormant', () {
      expect(VitalityStateMapper.fromPercent(0), VitalityState.dormant);
    });

    test('0 + ε → fading (just above zero)', () {
      expect(VitalityStateMapper.fromPercent(0.001), VitalityState.fading);
      expect(VitalityStateMapper.fromPercent(0.0000001), VitalityState.fading);
    });

    test('exactly 0.30 → fading (right-edge inclusive)', () {
      expect(VitalityStateMapper.fromPercent(0.30), VitalityState.fading);
    });

    test('0.30 + ε → active', () {
      expect(VitalityStateMapper.fromPercent(0.3001), VitalityState.active);
      expect(VitalityStateMapper.fromPercent(0.30000001), VitalityState.active);
    });

    test('exactly 0.70 → active (right-edge inclusive)', () {
      expect(VitalityStateMapper.fromPercent(0.70), VitalityState.active);
    });

    test('0.70 + ε → radiant', () {
      expect(VitalityStateMapper.fromPercent(0.7001), VitalityState.radiant);
      expect(
        VitalityStateMapper.fromPercent(0.70000001),
        VitalityState.radiant,
      );
    });

    test('exactly 1.0 → radiant', () {
      expect(VitalityStateMapper.fromPercent(1.0), VitalityState.radiant);
    });

    test('above 1.0 (defensive) → radiant', () {
      // Floating-point overshoot from numeric(14,4) round-trips. The mapper
      // must not split into a fifth state for "over peak" — Vitality is
      // capped at peak by definition (spec §8.1 clamp).
      expect(VitalityStateMapper.fromPercent(1.01), VitalityState.radiant);
      expect(VitalityStateMapper.fromPercent(2.0), VitalityState.radiant);
    });

    test('negative (defensive) → dormant', () {
      // pct < 0 should never occur (clamp in VitalityCalculator.percentage),
      // but the mapper handles it gracefully.
      expect(VitalityStateMapper.fromPercent(-0.1), VitalityState.dormant);
    });

    test('boundary constants match spec §8.4', () {
      expect(VitalityStateMapper.fadingMaxPct, 0.30);
      expect(VitalityStateMapper.activeMaxPct, 0.70);
    });
  });

  group('VitalityStateMapper.fromVitality — ewma+peak normalisation', () {
    test('peak == 0 collapses to dormant regardless of ewma', () {
      // Even a non-zero EWMA against a zero peak is dormant — this guards
      // a never-trained body part and prevents divide-by-zero in the
      // percentage helper.
      expect(
        VitalityStateMapper.fromVitality(ewma: 0, peak: 0),
        VitalityState.dormant,
      );
      expect(
        VitalityStateMapper.fromVitality(ewma: 100, peak: 0),
        VitalityState.dormant,
      );
    });

    test('ewma == 0 with peak > 0 → dormant (fully decayed)', () {
      // pct = 0/peak = 0 → dormant boundary. Spec §8.4 puts a fully
      // decayed body part at the same visual state as a never-trained
      // one — the user has fallen completely off the path.
      expect(
        VitalityStateMapper.fromVitality(ewma: 0, peak: 1000),
        VitalityState.dormant,
      );
    });

    test('half of peak → active (boundary mid-band)', () {
      expect(
        VitalityStateMapper.fromVitality(ewma: 50, peak: 100),
        VitalityState.active,
      );
      expect(
        VitalityStateMapper.fromVitality(ewma: 5000, peak: 10000),
        VitalityState.active,
      );
    });

    test('80% of peak → radiant (real-world spec §13.3 example)', () {
      // Spec §13.3 sample: chest EWMA 8420, peak 9850 → pct ≈ 0.855 → radiant.
      expect(
        VitalityStateMapper.fromVitality(ewma: 8420, peak: 9850),
        VitalityState.radiant,
      );
    });
  });

  group('VitalityStateMapper — palette per state', () {
    test('borderColorFor pins to the canonical AppColors tokens', () {
      expect(
        VitalityStateMapper.borderColorFor(VitalityState.dormant),
        AppColors.textDim,
      );
      expect(
        VitalityStateMapper.borderColorFor(VitalityState.fading),
        AppColors.primaryViolet,
      );
      expect(
        VitalityStateMapper.borderColorFor(VitalityState.active),
        AppColors.hotViolet,
      );
      expect(
        VitalityStateMapper.borderColorFor(VitalityState.radiant),
        AppColors.heroGold,
      );
    });

    test('borderColorFor returns distinct colors per state', () {
      final colors = VitalityState.values
          .map(VitalityStateMapper.borderColorFor)
          .toSet();
      expect(colors.length, VitalityState.values.length);
    });

    test('haloColorFor and progressBarColorFor align with borderColorFor', () {
      // Locked single-source-of-truth contract: halo, border, progress bar
      // all read from the same per-state palette. Splitting them would
      // re-introduce the drift the mapper exists to prevent.
      for (final s in VitalityState.values) {
        expect(
          VitalityStateMapper.haloColorFor(s),
          VitalityStateMapper.borderColorFor(s),
        );
        expect(
          VitalityStateMapper.progressBarColorFor(s),
          VitalityStateMapper.borderColorFor(s),
        );
      }
    });
  });

  group('VitalityStateMapper.bodyPartColor — locked palette', () {
    test('all 7 body parts (6 v1 + cardio) have a color assignment', () {
      for (final bp in BodyPart.values) {
        expect(
          VitalityStateMapper.bodyPartColor.containsKey(bp),
          true,
          reason: 'body part ${bp.dbValue} missing from bodyPartColor map',
        );
      }
    });

    test('all 6 active (v1) body parts have distinct colors', () {
      // The trend chart in §13.3 puts six body-part lines on the same
      // canvas — they must be visually distinguishable. We don't assert
      // contrast metrics here (UX-critic / design pass), but at minimum
      // no two body parts can share an identical color.
      final v1Colors = activeBodyParts
          .map((bp) => VitalityStateMapper.bodyPartColor[bp])
          .whereType<Color>()
          .toSet();
      expect(v1Colors.length, activeBodyParts.length);
    });

    test('cardio uses a desaturated tone (v2 placeholder)', () {
      // Cardio is intentionally muted until earnable in v2 — same `hair`
      // hairline tone as the dormant cardio row.
      expect(
        VitalityStateMapper.bodyPartColor[BodyPart.cardio],
        AppColors.hair,
      );
    });

    test('heroGold is reserved (not used as a body-part color)', () {
      // Reward-scarcity contract: heroGold is only the radiant rune signal
      // and reward-only token, never a per-body-part identity color.
      for (final color in VitalityStateMapper.bodyPartColor.values) {
        expect(
          color,
          isNot(AppColors.heroGold),
          reason: 'heroGold leaked into bodyPartColor — reward scarcity broken',
        );
      }
    });
  });

  group('VitalityStateMapper.copyKey', () {
    test('returns a distinct l10n key per state', () {
      final keys = VitalityState.values
          .map(VitalityStateMapper.copyKey)
          .toSet();
      expect(keys.length, VitalityState.values.length);
    });

    test('keys match the AppLocalizations contract', () {
      expect(
        VitalityStateMapper.copyKey(VitalityState.dormant),
        'vitalityCopyDormant',
      );
      expect(
        VitalityStateMapper.copyKey(VitalityState.fading),
        'vitalityCopyFading',
      );
      expect(
        VitalityStateMapper.copyKey(VitalityState.active),
        'vitalityCopyActive',
      );
      expect(
        VitalityStateMapper.copyKey(VitalityState.radiant),
        'vitalityCopyRadiant',
      );
    });
  });
}
