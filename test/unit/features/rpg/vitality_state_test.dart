import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/rpg/models/vitality_state.dart';

void main() {
  group('VitalityStateX.fromVitality', () {
    test('peak == 0 collapses to dormant regardless of EWMA', () {
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 0, vitalityPeak: 0),
        VitalityState.dormant,
      );
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 50, vitalityPeak: 0),
        VitalityState.dormant,
      );
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 100, vitalityPeak: 0),
        VitalityState.dormant,
      );
    });

    test('1..30% maps to fading when peak > 0', () {
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 0.5, vitalityPeak: 50),
        VitalityState.fading,
      );
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 30, vitalityPeak: 50),
        VitalityState.fading,
      );
    });

    test('30..70% maps to active', () {
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 31, vitalityPeak: 80),
        VitalityState.active,
      );
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 70, vitalityPeak: 80),
        VitalityState.active,
      );
    });

    test('70..100% maps to radiant', () {
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 71, vitalityPeak: 90),
        VitalityState.radiant,
      );
      expect(
        VitalityStateX.fromVitality(vitalityEwma: 100, vitalityPeak: 100),
        VitalityState.radiant,
      );
    });

    test('borderColor maps to the canonical AppColors palette per state', () {
      expect(VitalityState.dormant.borderColor, AppColors.textDim);
      expect(VitalityState.fading.borderColor, AppColors.primaryViolet);
      expect(VitalityState.active.borderColor, AppColors.hotViolet);
      expect(VitalityState.radiant.borderColor, AppColors.heroGold);
    });
  });
}
