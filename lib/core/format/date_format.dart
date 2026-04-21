import 'package:intl/intl.dart';

/// Locale-aware date formatting helpers.
///
/// All helpers take [locale] as an explicit parameter (typically the language
/// code read from `Localizations.localeOf(context).languageCode`). Explicit
/// threading keeps callers refactor-proof if the locale provider changes
/// shape later.
class AppDateFormat {
  AppDateFormat._();

  /// Short numeric date — `dd/MM/yyyy` (pt) / `MM/dd/yyyy` (en).
  ///
  /// Uses `DateFormat.yMd`, which emits the locale's short-date skeleton:
  ///   - pt:  `18/04/2026`
  ///   - en:  `4/18/2026`
  static String shortDate(DateTime date, {required String locale}) {
    return DateFormat.yMd(locale).format(date);
  }

  /// Short month + year — `abr. de 2026` (pt) / `Apr 2026` (en).
  ///
  /// Used on the profile "Member since" stat and similar compact rollups.
  static String monthYear(DateTime date, {required String locale}) {
    return DateFormat.yMMM(locale).format(date);
  }

  /// Month + day — `18 de abr.` (pt) / `Apr 18` (en).
  ///
  /// Used on chart x-axis labels.
  static String monthDay(DateTime date, {required String locale}) {
    return DateFormat.MMMd(locale).format(date);
  }
}
