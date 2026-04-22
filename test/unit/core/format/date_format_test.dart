import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/format/date_format.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt');
    await initializeDateFormatting('en');
  });

  group('AppDateFormat.shortDate', () {
    test('renders dd/MM/yyyy in pt', () {
      // 2026-04-18 — chosen so dd != MM and no leading-zero ambiguity.
      final date = DateTime(2026, 4, 18);
      expect(AppDateFormat.shortDate(date, locale: 'pt'), '18/04/2026');
    });

    test('renders M/d/yyyy in en', () {
      // en_US short date has no leading zero on day/month.
      final date = DateTime(2026, 4, 18);
      expect(AppDateFormat.shortDate(date, locale: 'en'), '4/18/2026');
    });

    test('pt keeps leading zeros on single-digit day and month', () {
      final date = DateTime(2026, 1, 5);
      expect(AppDateFormat.shortDate(date, locale: 'pt'), '05/01/2026');
    });
  });

  group('AppDateFormat.monthYear', () {
    test('en renders short month + year', () {
      final date = DateTime(2026, 4, 18);
      // en_US: "Apr 2026"
      expect(AppDateFormat.monthYear(date, locale: 'en'), 'Apr 2026');
    });

    test('pt renders locale-appropriate format', () {
      final date = DateTime(2026, 4, 18);
      // pt: "abr. de 2026" — we assert the month (in pt) is present and the
      // year is present, without depending on the exact separator which can
      // vary between intl versions.
      final result = AppDateFormat.monthYear(date, locale: 'pt');
      expect(result.toLowerCase(), contains('abr'));
      expect(result, contains('2026'));
    });
  });

  group('AppDateFormat.monthDay', () {
    test('en renders "MMM d"', () {
      final date = DateTime(2026, 4, 18);
      expect(AppDateFormat.monthDay(date, locale: 'en'), 'Apr 18');
    });

    test('pt renders locale-appropriate format', () {
      final date = DateTime(2026, 4, 18);
      final result = AppDateFormat.monthDay(date, locale: 'pt');
      // pt uses "18 de abr." — just assert both pieces are present.
      expect(result, contains('18'));
      expect(result.toLowerCase(), contains('abr'));
    });
  });
}
