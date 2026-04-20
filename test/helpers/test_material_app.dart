import 'package:flutter/material.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/l10n/app_localizations.dart';

/// A drop-in replacement for [MaterialApp] in widget tests.
///
/// Automatically injects [AppLocalizations] delegates so that any widget
/// using `AppLocalizations.of(context)` works without extra boilerplate.
///
/// All [MaterialApp] parameters are forwarded. If [localizationsDelegates]
/// or [supportedLocales] are not provided, the app-level defaults are used.
class TestMaterialApp extends StatelessWidget {
  const TestMaterialApp({
    super.key,
    this.home,
    this.theme,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales,
    this.navigatorObservers,
    this.routes,
    this.initialRoute,
    this.onGenerateRoute,
    this.builder,
    this.scaffoldMessengerKey,
    this.navigatorKey,
    this.debugShowCheckedModeBanner = false,
  });

  final Widget? home;
  final ThemeData? theme;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Iterable<Locale>? supportedLocales;
  final List<NavigatorObserver>? navigatorObservers;
  final Map<String, WidgetBuilder>? routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final TransitionBuilder? builder;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: home,
      theme: theme ?? AppTheme.dark,
      locale: locale ?? const Locale('en'),
      localizationsDelegates:
          localizationsDelegates ?? AppLocalizations.localizationsDelegates,
      supportedLocales: supportedLocales ?? AppLocalizations.supportedLocales,
      navigatorObservers: navigatorObservers ?? const [],
      routes: routes ?? const {},
      initialRoute: initialRoute,
      onGenerateRoute: onGenerateRoute,
      builder: builder,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }
}
