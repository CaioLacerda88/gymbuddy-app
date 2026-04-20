import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/format/number_format.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    // intl's NumberFormat for non-en locales lazy-loads pattern data.
    // initializeDateFormatting also registers NumberFormat patterns for the
    // locale, so it's safe (and cheap) to call here.
    await initializeDateFormatting('pt');
    await initializeDateFormatting('en');
  });

  group('AppNumberFormat.weight', () {
    test('integer weights render without decimals (en)', () {
      expect(AppNumberFormat.weight(80, locale: 'en'), '80');
    });

    test('integer weights render without decimals (pt)', () {
      expect(AppNumberFormat.weight(80, locale: 'pt'), '80');
    });

    test('fractional weights use dot as decimal separator in en', () {
      expect(AppNumberFormat.weight(80.5, locale: 'en'), '80.5');
    });

    test('fractional weights use comma as decimal separator in pt', () {
      expect(AppNumberFormat.weight(80.5, locale: 'pt'), '80,5');
    });

    test('rounds to one decimal place (en)', () {
      expect(AppNumberFormat.weight(82.49, locale: 'en'), '82.5');
    });

    test('rounds to one decimal place (pt)', () {
      expect(AppNumberFormat.weight(82.49, locale: 'pt'), '82,5');
    });

    test('handles zero', () {
      expect(AppNumberFormat.weight(0, locale: 'en'), '0');
      expect(AppNumberFormat.weight(0, locale: 'pt'), '0');
    });

    test('negative weight preserves sign with locale-aware decimal separator', () {
      // The UI prevents users from entering negative weights, but the formatter
      // must not silently alter values that reach it (e.g. from direct API calls).
      expect(AppNumberFormat.weight(-80.5, locale: 'en'), '-80.5');
      expect(AppNumberFormat.weight(-80.5, locale: 'pt'), '-80,5');
    });
  });

  group('AppNumberFormat.weightWithUnit', () {
    test('appends unit in en', () {
      expect(
        AppNumberFormat.weightWithUnit(80.5, locale: 'en', unit: 'kg'),
        '80.5 kg',
      );
    });

    test('appends unit in pt', () {
      expect(
        AppNumberFormat.weightWithUnit(80.5, locale: 'pt', unit: 'kg'),
        '80,5 kg',
      );
    });

    test('honors lbs unit', () {
      expect(
        AppNumberFormat.weightWithUnit(180, locale: 'en', unit: 'lbs'),
        '180 lbs',
      );
    });
  });

  group('AppNumberFormat.volume', () {
    test('uses comma as thousands separator in en', () {
      expect(AppNumberFormat.volume(1234, locale: 'en'), '1,234');
    });

    test('uses dot as thousands separator in pt', () {
      expect(AppNumberFormat.volume(1234, locale: 'pt'), '1.234');
    });

    test('rounds fractional values before formatting', () {
      expect(AppNumberFormat.volume(1234.7, locale: 'en'), '1,235');
      expect(AppNumberFormat.volume(1234.2, locale: 'pt'), '1.234');
    });

    test('handles small values without separator', () {
      expect(AppNumberFormat.volume(42, locale: 'en'), '42');
      expect(AppNumberFormat.volume(42, locale: 'pt'), '42');
    });
  });

  group('AppNumberFormat.compactVolume', () {
    test('renders >=1000 as "Nk" with locale-aware decimal (en)', () {
      expect(AppNumberFormat.compactVolume(1200, locale: 'en'), '1.2k');
    });

    test('renders >=1000 as "Nk" with locale-aware decimal (pt)', () {
      expect(AppNumberFormat.compactVolume(1200, locale: 'pt'), '1,2k');
    });

    test('renders <1000 as integer (en)', () {
      expect(AppNumberFormat.compactVolume(500, locale: 'en'), '500');
    });

    test('renders <1000 as integer (pt)', () {
      expect(AppNumberFormat.compactVolume(500, locale: 'pt'), '500');
    });

    test('exactly 1000 renders as "1.0k" (en) and "1,0k" (pt)', () {
      // Boundary: 1000 is the first value >= 1000, so it enters the compact branch.
      // 1000 / 1000 = 1.0, formatted with one decimal → "1.0k" (en) / "1,0k" (pt).
      expect(AppNumberFormat.compactVolume(1000.0, locale: 'en'), '1.0k');
      expect(AppNumberFormat.compactVolume(1000.0, locale: 'pt'), '1,0k');
    });
  });
}
