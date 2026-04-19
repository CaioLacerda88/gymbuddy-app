// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navExercises => 'Exercises';

  @override
  String get navRoutines => 'Routines';

  @override
  String get navProfile => 'Profile';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get continueLabel => 'Continue';

  @override
  String get logOut => 'Log Out';

  @override
  String get done => 'Done';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get add => 'Add';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Something went wrong';

  @override
  String get noResults => 'No results found';

  @override
  String get emptyState => 'Nothing here yet';

  @override
  String get search => 'Search';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get logIn => 'LOG IN';

  @override
  String get signUp => 'SIGN UP';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get sendResetEmail => 'Send Reset Email';

  @override
  String get offlineBanner => 'You are offline';

  @override
  String pendingSyncSingular(int count) {
    return '$count change pending sync';
  }

  @override
  String pendingSyncPlural(int count) {
    return '$count changes pending sync';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String weeksAgo(int count) {
    return '$count weeks ago';
  }

  @override
  String monthsAgo(int count) {
    return '$count months ago';
  }
}
