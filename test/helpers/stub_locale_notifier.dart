import 'package:flutter/material.dart';
import 'package:repsaga/core/l10n/locale_provider.dart';

/// Test-only [LocaleNotifier] that returns a fixed locale without touching Hive.
///
/// Use as an override in `ProviderScope` to drive locale-sensitive code paths
/// in widget and unit tests:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     localeProvider.overrideWith(() => StubLocaleNotifier(const Locale('pt'))),
///   ],
///   child: ...,
/// )
/// ```
class StubLocaleNotifier extends LocaleNotifier {
  StubLocaleNotifier(this._locale);
  final Locale _locale;

  @override
  Locale build() => _locale;
}
