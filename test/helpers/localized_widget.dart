import 'package:flutter/material.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/l10n/app_localizations.dart';

/// Wraps [child] in a [MaterialApp] with localization delegates and the
/// dark theme. Use this in widget tests that need [AppLocalizations.of]
/// to resolve without a full app bootstrap.
Widget buildLocalizedTestWidget(
  Widget child, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.dark,
    home: child,
  );
}
