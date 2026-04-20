import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// Bottom navigation label for home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label for exercises tab
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get navExercises;

  /// Bottom navigation label for routines tab
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get navRoutines;

  /// Bottom navigation label for profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Confirm button label
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Dismiss button label
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Continue button label (continueLabel avoids Dart keyword)
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Log out button label
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Done button label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Skip button label
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Back button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Start action label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Remove button label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Discard button label
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Resume button label
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Clear button label
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Replace button label
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// Undo action label
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// All filter label
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Separator between login methods
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// Generic loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// Empty search results message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Generic empty state message
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyState;

  /// Search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Log in button label
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get logIn;

  /// Sign up button label
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get signUp;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Send password reset email button label
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get sendResetEmail;

  /// Offline connectivity banner text
  ///
  /// In en, this message translates to:
  /// **'Offline — changes will sync when you\'re back online'**
  String get offlineBanner;

  /// Singular form: number of offline changes pending sync
  ///
  /// In en, this message translates to:
  /// **'{count} change pending sync'**
  String pendingSyncSingular(int count);

  /// Plural form: number of offline changes pending sync
  ///
  /// In en, this message translates to:
  /// **'{count} changes pending sync'**
  String pendingSyncPlural(int count);

  /// Relative date: today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Relative date: yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Relative date: N days ago
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// Relative date: N weeks ago
  ///
  /// In en, this message translates to:
  /// **'{count} weeks ago'**
  String weeksAgo(int count);

  /// Relative date: N months ago
  ///
  /// In en, this message translates to:
  /// **'{count} months ago'**
  String monthsAgo(int count);

  /// Muscle group: chest
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get muscleGroupChest;

  /// Muscle group: back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get muscleGroupBack;

  /// Muscle group: legs
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get muscleGroupLegs;

  /// Muscle group: shoulders
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get muscleGroupShoulders;

  /// Muscle group: arms
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get muscleGroupArms;

  /// Muscle group: core
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get muscleGroupCore;

  /// Muscle group: cardio
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get muscleGroupCardio;

  /// Equipment type: barbell
  ///
  /// In en, this message translates to:
  /// **'Barbell'**
  String get equipmentBarbell;

  /// Equipment type: dumbbell
  ///
  /// In en, this message translates to:
  /// **'Dumbbell'**
  String get equipmentDumbbell;

  /// Equipment type: cable
  ///
  /// In en, this message translates to:
  /// **'Cable'**
  String get equipmentCable;

  /// Equipment type: machine
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get equipmentMachine;

  /// Equipment type: bodyweight
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get equipmentBodyweight;

  /// Equipment type: bands
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get equipmentBands;

  /// Equipment type: kettlebell
  ///
  /// In en, this message translates to:
  /// **'Kettlebell'**
  String get equipmentKettlebell;

  /// Set type: working set
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get setTypeWorking;

  /// Set type: warm-up
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get setTypeWarmup;

  /// Set type: drop set
  ///
  /// In en, this message translates to:
  /// **'Drop Set'**
  String get setTypeDropset;

  /// Set type: to failure
  ///
  /// In en, this message translates to:
  /// **'To Failure'**
  String get setTypeFailure;

  /// Record type: max weight
  ///
  /// In en, this message translates to:
  /// **'Max Weight'**
  String get recordTypeMaxWeight;

  /// Record type: max reps
  ///
  /// In en, this message translates to:
  /// **'Max Reps'**
  String get recordTypeMaxReps;

  /// Record type: max volume
  ///
  /// In en, this message translates to:
  /// **'Max Volume'**
  String get recordTypeMaxVolume;

  /// Weight unit: kilograms (display)
  ///
  /// In en, this message translates to:
  /// **'KG'**
  String get weightUnitKg;

  /// Weight unit: pounds (display)
  ///
  /// In en, this message translates to:
  /// **'LBS'**
  String get weightUnitLbs;

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'GymBuddy'**
  String get appName;

  /// Login screen subtitle for existing users
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Login screen subtitle for new users
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// Email validation error: empty
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Email validation error: invalid format
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// Password validation error: empty
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Password validation error: too short
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// Hint when forgot password tapped without email
  ///
  /// In en, this message translates to:
  /// **'Enter your email above, then tap \"Forgot password?\"'**
  String get forgotPasswordHint;

  /// Reset password dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Reset password confirmation message
  ///
  /// In en, this message translates to:
  /// **'Send a password reset email to {email}?'**
  String sendResetEmailTo(String email);

  /// Snackbar after password reset email sent
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get resetEmailSent;

  /// Google sign-in button label
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Toggle to login mode
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get alreadyHaveAccount;

  /// Toggle to signup mode
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get dontHaveAccount;

  /// Legal footer prefix text
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get legalAgreePrefix;

  /// Terms of Service link text
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Legal footer and separator
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andSeparator;

  /// Privacy Policy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Auth error: invalid credentials
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Please try again.'**
  String get authErrorInvalidCredentials;

  /// Auth error: email not confirmed
  ///
  /// In en, this message translates to:
  /// **'Please check your inbox and confirm your email first.'**
  String get authErrorEmailNotConfirmed;

  /// Auth error: already registered
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Try logging in instead.'**
  String get authErrorAlreadyRegistered;

  /// Auth error: rate limited
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get authErrorRateLimit;

  /// Auth error: weak password
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get authErrorWeakPassword;

  /// Auth error: network issue
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get authErrorNetwork;

  /// Auth error: timeout
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get authErrorTimeout;

  /// Auth error: expired token/OTP
  ///
  /// In en, this message translates to:
  /// **'The confirmation link has expired. Please request a new one.'**
  String get authErrorTokenExpired;

  /// Auth error: generic fallback
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// Email confirmation screen title
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get checkYourInbox;

  /// Confirmation email sent to specific address
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation email to'**
  String get confirmationSentTo;

  /// Confirmation email sent (no address)
  ///
  /// In en, this message translates to:
  /// **'We sent you a confirmation email'**
  String get confirmationSent;

  /// Instructions to verify email
  ///
  /// In en, this message translates to:
  /// **'Tap the link in the email to verify your account, then come back and log in.'**
  String get tapLinkToVerify;

  /// Confirmation when email resent
  ///
  /// In en, this message translates to:
  /// **'Email resent! Check your inbox.'**
  String get emailResent;

  /// Back to login button
  ///
  /// In en, this message translates to:
  /// **'BACK TO LOGIN'**
  String get backToLogin;

  /// Resend confirmation email link
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive it? Resend email'**
  String get didntReceiveResend;

  /// Onboarding welcome headline
  ///
  /// In en, this message translates to:
  /// **'Track every rep,\nevery time'**
  String get onboardingHeadline;

  /// Onboarding welcome subtitle
  ///
  /// In en, this message translates to:
  /// **'Log workouts, crush personal records, and build the physique you want.'**
  String get onboardingSubtitle;

  /// Onboarding get started button
  ///
  /// In en, this message translates to:
  /// **'GET STARTED'**
  String get getStarted;

  /// Profile setup page title
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setupProfile;

  /// Profile setup subtitle
  ///
  /// In en, this message translates to:
  /// **'Tell us a bit about yourself'**
  String get tellUsAboutYourself;

  /// Display name field label
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// Fitness level section label
  ///
  /// In en, this message translates to:
  /// **'Fitness level'**
  String get fitnessLevel;

  /// Training frequency question
  ///
  /// In en, this message translates to:
  /// **'How often do you plan to train?'**
  String get howOftenTrain;

  /// Weekly goal hint text
  ///
  /// In en, this message translates to:
  /// **'Your weekly goal — you can change this anytime'**
  String get weeklyGoalHint;

  /// Finish onboarding button
  ///
  /// In en, this message translates to:
  /// **'LET\'S GO'**
  String get letsGo;

  /// Validation: name required on onboarding
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get pleaseEnterName;

  /// Snackbar: profile save failed
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile. Please try again.'**
  String get failedToSaveProfile;

  /// Fitness level: beginner
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get fitnessLevelBeginner;

  /// Fitness level: intermediate
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get fitnessLevelIntermediate;

  /// Fitness level: advanced
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get fitnessLevelAdvanced;

  /// Home status line when week is complete
  ///
  /// In en, this message translates to:
  /// **'Week complete — {count} of {count} done'**
  String homeStatusWeekComplete(int count);

  /// Home status line suffix showing weekly progress
  ///
  /// In en, this message translates to:
  /// **' of {total} this week'**
  String homeStatusProgress(int total);

  /// Home status: no active plan
  ///
  /// In en, this message translates to:
  /// **'No plan this week'**
  String get noPlanThisWeek;

  /// Confirmation banner question
  ///
  /// In en, this message translates to:
  /// **'Same plan this week?'**
  String get samePlanThisWeek;

  /// Section header for user's routines on home
  ///
  /// In en, this message translates to:
  /// **'MY ROUTINES'**
  String get myRoutines;

  /// Link to see all routines
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// CTA for first routine creation
  ///
  /// In en, this message translates to:
  /// **'Create Your First Routine'**
  String get createYourFirstRoutine;

  /// Action hero label: up next
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get heroUpNext;

  /// Action hero label: first workout
  ///
  /// In en, this message translates to:
  /// **'YOUR FIRST WORKOUT'**
  String get heroYourFirstWorkout;

  /// Action hero label: no plan
  ///
  /// In en, this message translates to:
  /// **'NO PLAN'**
  String get heroNoPlan;

  /// Action hero label: new week
  ///
  /// In en, this message translates to:
  /// **'NEW WEEK'**
  String get heroNewWeek;

  /// Action hero headline: plan your week
  ///
  /// In en, this message translates to:
  /// **'Plan your week'**
  String get planYourWeek;

  /// Action hero subline: pick routines
  ///
  /// In en, this message translates to:
  /// **'Pick routines for the week'**
  String get pickRoutinesForWeek;

  /// Quick workout button
  ///
  /// In en, this message translates to:
  /// **'Quick workout'**
  String get quickWorkout;

  /// Start new week headline
  ///
  /// In en, this message translates to:
  /// **'Start new week'**
  String get startNewWeek;

  /// Completed count subline
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} done'**
  String nOfNDone(int completed, int total);

  /// Exercise count and estimated duration
  ///
  /// In en, this message translates to:
  /// **'{count} exercises · ~{minutes} min'**
  String exerciseCountDuration(int count, int minutes);

  /// Snackbar: offline start workout blocked
  ///
  /// In en, this message translates to:
  /// **'Starting a workout requires an internet connection'**
  String get offlineStartWorkout;

  /// Snackbar: exercise load failure for routine
  ///
  /// In en, this message translates to:
  /// **'Could not load exercises. Please try again.'**
  String get couldNotLoadExercises;

  /// Prefix for last session line on home
  ///
  /// In en, this message translates to:
  /// **'Last: '**
  String get lastSessionPrefix;

  /// Exercises screen title
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// Search exercises placeholder
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercises;

  /// Empty state: filters active, no results
  ///
  /// In en, this message translates to:
  /// **'No exercises match your filters'**
  String get noExercisesMatchFilters;

  /// Empty state: no exercises at all
  ///
  /// In en, this message translates to:
  /// **'Your exercises will appear here'**
  String get yourExercisesWillAppear;

  /// Clear filters button
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// Create exercise button
  ///
  /// In en, this message translates to:
  /// **'Create Exercise'**
  String get createExercise;

  /// Exercise detail screen title
  ///
  /// In en, this message translates to:
  /// **'Exercise Details'**
  String get exerciseDetails;

  /// Error loading exercise detail
  ///
  /// In en, this message translates to:
  /// **'Failed to load exercise'**
  String get failedToLoadExercise;

  /// Badge for user-created exercises
  ///
  /// In en, this message translates to:
  /// **'Custom exercise'**
  String get customExercise;

  /// Section header: personal records
  ///
  /// In en, this message translates to:
  /// **'Personal Records'**
  String get personalRecords;

  /// Empty state: no personal records
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noRecordsYet;

  /// Delete exercise button/dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise'**
  String get deleteExercise;

  /// Delete exercise confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteExerciseConfirm(String name);

  /// Deleting state label
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// Exercise image label: start position
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get imageStart;

  /// Exercise image label: end position
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get imageEnd;

  /// Reps display with count
  ///
  /// In en, this message translates to:
  /// **'{count} reps'**
  String repsUnit(int count);

  /// Exercise name field label
  ///
  /// In en, this message translates to:
  /// **'Exercise Name'**
  String get exerciseName;

  /// Validation: name required
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// Validation: name too short
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameTooShort;

  /// Muscle group section label
  ///
  /// In en, this message translates to:
  /// **'Muscle Group'**
  String get muscleGroup;

  /// Equipment type section label
  ///
  /// In en, this message translates to:
  /// **'Equipment Type'**
  String get equipmentType;

  /// Validation: muscle+equipment required
  ///
  /// In en, this message translates to:
  /// **'Please select a muscle group and equipment type'**
  String get selectMuscleAndEquipment;

  /// Session expired snackbar
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get sessionExpired;

  /// Snackbar: exercise created
  ///
  /// In en, this message translates to:
  /// **'Exercise created successfully'**
  String get exerciseCreated;

  /// Create exercise submit button
  ///
  /// In en, this message translates to:
  /// **'CREATE EXERCISE'**
  String get createExerciseButton;

  /// Description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Description field hint
  ///
  /// In en, this message translates to:
  /// **'Brief description of the exercise (optional)'**
  String get descriptionHint;

  /// Form tips field label
  ///
  /// In en, this message translates to:
  /// **'Form Tips'**
  String get formTips;

  /// Form tips field hint
  ///
  /// In en, this message translates to:
  /// **'Form cues, one per line (optional)'**
  String get formTipsHint;

  /// Form tips field helper text
  ///
  /// In en, this message translates to:
  /// **'Enter each tip on a new line'**
  String get formTipsHelper;

  /// Exercise detail about section header
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutSection;

  /// Exercise detail form tips section header
  ///
  /// In en, this message translates to:
  /// **'FORM TIPS'**
  String get formTipsSection;

  /// Finish workout button
  ///
  /// In en, this message translates to:
  /// **'Finish Workout'**
  String get finishWorkout;

  /// Hint: need completed set to finish
  ///
  /// In en, this message translates to:
  /// **'Complete at least one set to finish'**
  String get completeOneSet;

  /// Empty workout: add exercise prompt
  ///
  /// In en, this message translates to:
  /// **'Add your first exercise'**
  String get addFirstExercise;

  /// Empty workout: add exercise hint
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to get started'**
  String get tapButtonToStart;

  /// Add exercise button
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get addExercise;

  /// Add set button
  ///
  /// In en, this message translates to:
  /// **'Add Set'**
  String get addSet;

  /// Fill remaining sets button
  ///
  /// In en, this message translates to:
  /// **'Fill remaining'**
  String get fillRemaining;

  /// Snackbar: filled remaining sets
  ///
  /// In en, this message translates to:
  /// **'Filled remaining sets'**
  String get filledRemainingSets;

  /// Remove exercise dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove Exercise?'**
  String get removeExerciseTitle;

  /// Remove exercise dialog content
  ///
  /// In en, this message translates to:
  /// **'Remove {name} and all its sets?'**
  String removeExerciseContent(String name);

  /// Snackbar: discard workout failed
  ///
  /// In en, this message translates to:
  /// **'Failed to discard workout. Please retry.'**
  String get failedToDiscardWorkout;

  /// Snackbar: save workout failed
  ///
  /// In en, this message translates to:
  /// **'Failed to save workout. Please retry.'**
  String get failedToSaveWorkout;

  /// Snackbar: workout saved offline
  ///
  /// In en, this message translates to:
  /// **'Workout saved. Will sync when back online.'**
  String get workoutSavedOffline;

  /// Set column header: set number
  ///
  /// In en, this message translates to:
  /// **'SET'**
  String get setColumnSet;

  /// Set column header: weight
  ///
  /// In en, this message translates to:
  /// **'WEIGHT'**
  String get setColumnWeight;

  /// Set column header: reps
  ///
  /// In en, this message translates to:
  /// **'REPS'**
  String get setColumnReps;

  /// Set column header: type (read-only detail)
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get setColumnType;

  /// Snackbar: set deleted
  ///
  /// In en, this message translates to:
  /// **'Set {number} deleted'**
  String setDeleted(int number);

  /// Previous session set hint
  ///
  /// In en, this message translates to:
  /// **'Previous: {weight}{unit} × {reps}'**
  String previousSet(String weight, String unit, int reps);

  /// Discard workout dialog title
  ///
  /// In en, this message translates to:
  /// **'Discard Workout?'**
  String get discardWorkoutTitle;

  /// Discard workout dialog content
  ///
  /// In en, this message translates to:
  /// **'You\'ve been working out for {duration}. This cannot be undone.'**
  String discardWorkoutContent(String duration);

  /// Finish workout dialog title
  ///
  /// In en, this message translates to:
  /// **'Finish Workout?'**
  String get finishWorkoutTitle;

  /// Warning about incomplete sets
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 incomplete set} other{You have {count} incomplete sets}}'**
  String incompleteSetsWarning(int count);

  /// Workout notes hint
  ///
  /// In en, this message translates to:
  /// **'Add notes (optional)'**
  String get addNotesHint;

  /// Keep going button in finish dialog
  ///
  /// In en, this message translates to:
  /// **'Keep Going'**
  String get keepGoing;

  /// Save and finish button
  ///
  /// In en, this message translates to:
  /// **'Save & Finish'**
  String get saveAndFinish;

  /// Resume workout dialog title
  ///
  /// In en, this message translates to:
  /// **'Resume workout?'**
  String get resumeWorkoutTitle;

  /// Resume stale workout dialog title
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off?'**
  String get resumeWorkoutStaleTitle;

  /// Resume dialog: workout in progress
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is still in progress.'**
  String workoutInProgress(String name);

  /// Resume dialog: stale workout interrupted info
  ///
  /// In en, this message translates to:
  /// **'was interrupted {age}.'**
  String workoutInterrupted(String age);

  /// Resume anyway button for stale workouts
  ///
  /// In en, this message translates to:
  /// **'Resume anyway'**
  String get resumeAnyway;

  /// Rest timer default exercise name
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get restTimerLabel;

  /// Rest timer semantics label
  ///
  /// In en, this message translates to:
  /// **'Rest timer: {time} remaining'**
  String restTimerRemaining(String time);

  /// Rest timer -30s button semantics
  ///
  /// In en, this message translates to:
  /// **'Subtract 30 seconds'**
  String get subtract30Semantics;

  /// Rest timer +30s button semantics
  ///
  /// In en, this message translates to:
  /// **'Add 30 seconds'**
  String get add30Semantics;

  /// Rest timer skip button semantics
  ///
  /// In en, this message translates to:
  /// **'Skip rest timer'**
  String get skipRestSemantics;

  /// Rest timer dismiss hint
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to dismiss'**
  String get tapToDismiss;

  /// Resume age: less than 1 hour
  ///
  /// In en, this message translates to:
  /// **'less than an hour ago'**
  String get lessThanAnHourAgo;

  /// Resume age: N hours ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// Resume age: yesterday at time
  ///
  /// In en, this message translates to:
  /// **'yesterday at {time}'**
  String yesterdayAt(String time);

  /// Resume age: weekday at time
  ///
  /// In en, this message translates to:
  /// **'{weekday} at {time}'**
  String weekdayAt(String weekday, String time);

  /// Workout history screen title
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Error loading workout history
  ///
  /// In en, this message translates to:
  /// **'Failed to load history'**
  String get failedToLoadHistory;

  /// Empty history: title
  ///
  /// In en, this message translates to:
  /// **'No workouts yet'**
  String get noWorkoutsYet;

  /// Empty history: subtitle
  ///
  /// In en, this message translates to:
  /// **'Your completed workouts will appear here'**
  String get completedWorkoutsAppear;

  /// Empty history: CTA
  ///
  /// In en, this message translates to:
  /// **'Start your first workout'**
  String get startFirstWorkout;

  /// Error loading workout detail
  ///
  /// In en, this message translates to:
  /// **'Failed to load workout'**
  String get failedToLoadWorkout;

  /// Workout generic label
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// Fallback exercise name when name is null
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exerciseGeneric;

  /// Notes section label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Total volume footer in workout detail
  ///
  /// In en, this message translates to:
  /// **'Total Volume: {volume}'**
  String totalVolume(String volume);

  /// Routines screen title
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get routines;

  /// Error loading routines
  ///
  /// In en, this message translates to:
  /// **'Failed to load routines'**
  String get failedToLoadRoutines;

  /// Section header: my routines
  ///
  /// In en, this message translates to:
  /// **'MY ROUTINES'**
  String get myRoutinesSection;

  /// Section header: starter routines
  ///
  /// In en, this message translates to:
  /// **'STARTER ROUTINES'**
  String get starterRoutinesSection;

  /// Empty state: no custom routines
  ///
  /// In en, this message translates to:
  /// **'No custom routines yet. Tap + to create one.'**
  String get noCustomRoutines;

  /// Create routine screen title
  ///
  /// In en, this message translates to:
  /// **'Create Routine'**
  String get createRoutine;

  /// Edit routine screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Routine'**
  String get editRoutine;

  /// Routine name field hint
  ///
  /// In en, this message translates to:
  /// **'Routine name'**
  String get routineName;

  /// Snackbar: routine save failed
  ///
  /// In en, this message translates to:
  /// **'Failed to save routine. Please retry.'**
  String get failedToSaveRoutine;

  /// Sets label in routine exercise card
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get setsLabel;

  /// Rest label in routine exercise card
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get restLabel;

  /// Routine action: duplicate and edit
  ///
  /// In en, this message translates to:
  /// **'Duplicate and Edit'**
  String get duplicateAndEdit;

  /// Delete routine dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Routine'**
  String get deleteRoutine;

  /// Delete routine confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteRoutineConfirm(String name);

  /// Number of exercises
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String exercisesCount(int count);

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Default display name
  ///
  /// In en, this message translates to:
  /// **'Gym User'**
  String get gymUser;

  /// Edit name dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Display Name'**
  String get editDisplayName;

  /// Edit name field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// Workouts stat label
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// Member since stat label
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// Weight unit section label
  ///
  /// In en, this message translates to:
  /// **'Weight Unit'**
  String get weightUnit;

  /// Weekly goal section label
  ///
  /// In en, this message translates to:
  /// **'Weekly Goal'**
  String get weeklyGoal;

  /// Section header: data management
  ///
  /// In en, this message translates to:
  /// **'DATA MANAGEMENT'**
  String get dataManagement;

  /// Manage data link
  ///
  /// In en, this message translates to:
  /// **'Manage Data'**
  String get manageData;

  /// Section header: legal
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get legal;

  /// Crash reports toggle title
  ///
  /// In en, this message translates to:
  /// **'Send crash reports'**
  String get sendCrashReports;

  /// Crash reports toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Help improve GymBuddy by sending anonymous crash data.'**
  String get crashReportsSubtitle;

  /// Log out confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logOutConfirm;

  /// Manage data screen title
  ///
  /// In en, this message translates to:
  /// **'Manage Data'**
  String get manageDataTitle;

  /// Delete history tile title
  ///
  /// In en, this message translates to:
  /// **'Delete Workout History'**
  String get deleteWorkoutHistory;

  /// Delete history subtitle — count is pre-formatted (may be '...' during loading)
  ///
  /// In en, this message translates to:
  /// **'{count} workouts will be removed'**
  String workoutsWillBeRemoved(String count);

  /// Reset all data tile title
  ///
  /// In en, this message translates to:
  /// **'Reset All Account Data'**
  String get resetAllAccountData;

  /// Reset all data subtitle
  ///
  /// In en, this message translates to:
  /// **'Removes everything. Permanent.'**
  String get resetAllSubtitle;

  /// Delete account tile title/dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Delete account subtitle
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all data'**
  String get deleteAccountSubtitle;

  /// Delete history dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete all workout history?'**
  String get deleteAllHistoryTitle;

  /// Delete history dialog content
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all {count} workouts and cannot be undone.'**
  String deleteAllHistoryContent(int count);

  /// Delete history confirm button
  ///
  /// In en, this message translates to:
  /// **'Delete History'**
  String get deleteHistoryButton;

  /// Double confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// Double confirm delete button
  ///
  /// In en, this message translates to:
  /// **'Yes, Delete'**
  String get yesDelete;

  /// Snackbar: history cleared
  ///
  /// In en, this message translates to:
  /// **'Workout history cleared'**
  String get historyCleared;

  /// Snackbar: clear history failed
  ///
  /// In en, this message translates to:
  /// **'Failed to clear history: {message}'**
  String failedToClearHistory(String message);

  /// Reset account data dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset Account Data'**
  String get resetAccountData;

  /// Reset account warning text
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all workouts and personal records. Your routines and custom exercises will be kept. There is no undo.'**
  String get resetAccountWarning;

  /// Reset confirmation instruction
  ///
  /// In en, this message translates to:
  /// **'Type RESET to confirm'**
  String get typeResetToConfirm;

  /// Reset account confirm button
  ///
  /// In en, this message translates to:
  /// **'Reset Account'**
  String get resetAccountButton;

  /// Snackbar: account data reset
  ///
  /// In en, this message translates to:
  /// **'Account data reset'**
  String get accountDataReset;

  /// Snackbar: reset data failed
  ///
  /// In en, this message translates to:
  /// **'Failed to reset data: {message}'**
  String failedToResetData(String message);

  /// Delete account warning text
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account, all your workouts, personal records, routines, and custom exercises. This cannot be undone.'**
  String get deleteAccountWarning;

  /// Delete account confirmation instruction
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get typeDeleteToConfirm;

  /// Delete account confirm button
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButton;

  /// Snackbar: delete account failed
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {message}'**
  String failedToDeleteAccount(String message);

  /// Delete history: second dialog content
  ///
  /// In en, this message translates to:
  /// **'Your personal records and routines will be kept.'**
  String get prsRoutinesKept;

  /// Section header: workout history
  ///
  /// In en, this message translates to:
  /// **'WORKOUT HISTORY'**
  String get workoutHistorySection;

  /// Section header: danger
  ///
  /// In en, this message translates to:
  /// **'DANGER'**
  String get dangerSection;

  /// Section header: privacy
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get privacySection;

  /// PRs stat label
  ///
  /// In en, this message translates to:
  /// **'PRs'**
  String get prsLabel;

  /// Training frequency display
  ///
  /// In en, this message translates to:
  /// **'{count}x per week'**
  String perWeekLabel(int count);

  /// Frequency picker question
  ///
  /// In en, this message translates to:
  /// **'How many times per week do you want to train?'**
  String get frequencyQuestion;

  /// Generic retry message
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// PR list screen title
  ///
  /// In en, this message translates to:
  /// **'Personal Records'**
  String get personalRecordsTitle;

  /// Error loading PR list
  ///
  /// In en, this message translates to:
  /// **'Failed to load records'**
  String get failedToLoadRecords;

  /// Empty PR list: title
  ///
  /// In en, this message translates to:
  /// **'No Records Yet'**
  String get noRecordsYetTitle;

  /// Empty PR list: subtitle
  ///
  /// In en, this message translates to:
  /// **'Complete a workout to start tracking records'**
  String get completeWorkoutToTrack;

  /// Start workout CTA
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkout;

  /// PR celebration: new PR heading
  ///
  /// In en, this message translates to:
  /// **'NEW PR'**
  String get newPrHeading;

  /// PR celebration: first workout title
  ///
  /// In en, this message translates to:
  /// **'First Workout Complete!'**
  String get firstWorkoutComplete;

  /// PR celebration: first workout subtitle
  ///
  /// In en, this message translates to:
  /// **'These are your starting benchmarks'**
  String get startingBenchmarks;

  /// Fallback exercise name
  ///
  /// In en, this message translates to:
  /// **'Unknown Exercise'**
  String get unknownExercise;

  /// Plan management screen title
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Plan'**
  String get thisWeeksPlan;

  /// Overflow menu tooltip
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// Auto-fill menu option
  ///
  /// In en, this message translates to:
  /// **'Auto-fill'**
  String get autoFill;

  /// Clear week menu option
  ///
  /// In en, this message translates to:
  /// **'Clear Week'**
  String get clearWeek;

  /// Add routine row label
  ///
  /// In en, this message translates to:
  /// **'Add Routine'**
  String get addRoutine;

  /// Plan progress: at soft cap
  ///
  /// In en, this message translates to:
  /// **'{count}/{total} planned — ready to go'**
  String plannedReadyToGo(int count, int total);

  /// Plan progress: below soft cap
  ///
  /// In en, this message translates to:
  /// **'{count}/{total} planned this week'**
  String plannedThisWeek(int count, int total);

  /// Empty plan state
  ///
  /// In en, this message translates to:
  /// **'No routines planned this week'**
  String get noRoutinesPlanned;

  /// Add routines button
  ///
  /// In en, this message translates to:
  /// **'Add Routines'**
  String get addRoutines;

  /// Auto-fill replace dialog title
  ///
  /// In en, this message translates to:
  /// **'Replace current plan?'**
  String get replacePlanTitle;

  /// Auto-fill replace dialog content
  ///
  /// In en, this message translates to:
  /// **'Auto-fill will replace your current plan with your most-used routines.'**
  String get replacePlanContent;

  /// Clear week dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear Week'**
  String get clearWeekTitle;

  /// Clear week dialog content
  ///
  /// In en, this message translates to:
  /// **'Start fresh this week?'**
  String get clearWeekContent;

  /// Snackbar: routine removed from plan
  ///
  /// In en, this message translates to:
  /// **'Routine removed'**
  String get routineRemoved;

  /// Fallback routine name
  ///
  /// In en, this message translates to:
  /// **'Unknown Routine'**
  String get unknownRoutine;

  /// Add routines sheet title
  ///
  /// In en, this message translates to:
  /// **'Add Routines'**
  String get addRoutinesSheet;

  /// All routines already in plan
  ///
  /// In en, this message translates to:
  /// **'All routines in plan'**
  String get allRoutinesInPlan;

  /// Hint: no more routines to add
  ///
  /// In en, this message translates to:
  /// **'Create more routines to add them here.'**
  String get createMoreRoutines;

  /// Add N routines button label
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{ADD 1 ROUTINE} other{ADD {count} ROUTINES}}'**
  String addCountRoutines(int count);

  /// Week review: complete header
  ///
  /// In en, this message translates to:
  /// **'WEEK COMPLETE'**
  String get weekComplete;

  /// Week review: in-progress header
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get thisWeek;

  /// Week review: new week link
  ///
  /// In en, this message translates to:
  /// **'NEW WEEK'**
  String get newWeekLink;

  /// Week review: session count
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String sessionsCount(int count);

  /// Week review: PR count
  ///
  /// In en, this message translates to:
  /// **'{count} PRs'**
  String prsCount(int count);

  /// Add routine to plan prompt
  ///
  /// In en, this message translates to:
  /// **'{name} isn\'t in your plan yet. Add it?'**
  String addToPlanPrompt(String name);

  /// Sync failure: one workout
  ///
  /// In en, this message translates to:
  /// **'Workout couldn\'t sync'**
  String get syncFailureSingular;

  /// Sync failure: multiple workouts
  ///
  /// In en, this message translates to:
  /// **'{count} workouts couldn\'t sync'**
  String syncFailurePlural(int count);

  /// Sync failure subtitle
  ///
  /// In en, this message translates to:
  /// **'Saved locally. Retry or dismiss.'**
  String get savedLocallyRetry;

  /// Snackbar: retry blocked while offline
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — retry when back online'**
  String get offlineRetryHint;

  /// Pending sync sheet title
  ///
  /// In en, this message translates to:
  /// **'Pending Sync'**
  String get pendingSyncTitle;

  /// Item count in pending sync sheet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// Empty pending sync sheet
  ///
  /// In en, this message translates to:
  /// **'All synced!'**
  String get allSynced;

  /// Snackbar: sync success
  ///
  /// In en, this message translates to:
  /// **'Synced successfully.'**
  String get syncedSuccessfully;

  /// Pending action: save workout
  ///
  /// In en, this message translates to:
  /// **'Save workout'**
  String get pendingActionSaveWorkout;

  /// Pending action: update records
  ///
  /// In en, this message translates to:
  /// **'Update records'**
  String get pendingActionUpdateRecords;

  /// Pending action: mark routine complete
  ///
  /// In en, this message translates to:
  /// **'Mark routine complete'**
  String get pendingActionMarkComplete;

  /// Pending action queued time
  ///
  /// In en, this message translates to:
  /// **'Queued at {time}'**
  String queuedAt(String time);

  /// Pending action retry count
  ///
  /// In en, this message translates to:
  /// **'{count} retries'**
  String retryCount(int count);

  /// Pending sync badge: one workout
  ///
  /// In en, this message translates to:
  /// **'1 workout pending sync'**
  String get pendingSyncBadgeSingular;

  /// Pending sync badge: multiple workouts
  ///
  /// In en, this message translates to:
  /// **'{count} workouts pending sync'**
  String pendingSyncBadgePlural(int count);

  /// Exercise picker: empty result
  ///
  /// In en, this message translates to:
  /// **'No exercises found'**
  String get noExercisesFound;

  /// Exercise picker: load error
  ///
  /// In en, this message translates to:
  /// **'Failed to load exercises'**
  String get failedToLoadExercises;

  /// Exercise picker: create exercise with search query name
  ///
  /// In en, this message translates to:
  /// **'Create \"{name}\"'**
  String createWithName(String name);

  /// Duration format: less than 1 minute
  ///
  /// In en, this message translates to:
  /// **'< 1m'**
  String get durationLessThanOneMin;

  /// Weight input dialog title
  ///
  /// In en, this message translates to:
  /// **'Enter weight'**
  String get enterWeight;

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Reps input dialog title
  ///
  /// In en, this message translates to:
  /// **'Enter reps'**
  String get enterReps;

  /// Error loading legal document
  ///
  /// In en, this message translates to:
  /// **'Failed to load document'**
  String get failedToLoadDocument;

  /// Discard workout tooltip
  ///
  /// In en, this message translates to:
  /// **'Discard workout'**
  String get discardWorkout;

  /// Move exercise up tooltip
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// Move exercise down tooltip
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// Swap exercise tooltip
  ///
  /// In en, this message translates to:
  /// **'Swap exercise'**
  String get swapExercise;

  /// Remove exercise tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get removeExercise;

  /// RPE tooltip
  ///
  /// In en, this message translates to:
  /// **'Rate of perceived exertion'**
  String get rpeTooltip;

  /// Chart time window: last 30 days
  ///
  /// In en, this message translates to:
  /// **'30d'**
  String get last30Days;

  /// Chart time window: last 90 days
  ///
  /// In en, this message translates to:
  /// **'90d'**
  String get last90Days;

  /// Chart time window: all time
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// Accessibility label for metric cycle button
  ///
  /// In en, this message translates to:
  /// **'Switch metric to {metric}'**
  String switchMetricTo(String metric);

  /// Chart error: failed to load progress data
  ///
  /// In en, this message translates to:
  /// **'Could not load progress'**
  String get couldNotLoadProgress;

  /// Chart empty state: no data yet
  ///
  /// In en, this message translates to:
  /// **'Log your first set to start tracking'**
  String get logFirstSetToTrack;

  /// Chart metric label: estimated one-rep max
  ///
  /// In en, this message translates to:
  /// **'e1RM'**
  String get chartMetricE1rm;

  /// Chart metric label: raw weight
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get chartMetricWeight;

  /// Chart window label: 30 days
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get chartWindowDays30;

  /// Chart window label: 90 days
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get chartWindowDays90;

  /// Chart window label: all time
  ///
  /// In en, this message translates to:
  /// **'all time'**
  String get chartWindowAllTime;

  /// Chart trend: N workouts logged with no trend direction
  ///
  /// In en, this message translates to:
  /// **'{count} workouts logged — keep going'**
  String workoutsLoggedKeepGoing(int count);

  /// Chart trend: 1 workout logged
  ///
  /// In en, this message translates to:
  /// **'1 workout logged — keep going'**
  String get oneWorkoutLoggedKeepGoing;

  /// Chart trend: no change
  ///
  /// In en, this message translates to:
  /// **'Holding steady at {weight} {unit}'**
  String holdingSteadyAt(String weight, String unit);

  /// Chart trend: positive delta
  ///
  /// In en, this message translates to:
  /// **'Up {weight} {unit} in {window}'**
  String trendUp(String weight, String unit, String window);

  /// Chart trend: negative delta
  ///
  /// In en, this message translates to:
  /// **'Down {weight} {unit} in {window}'**
  String trendDown(String weight, String unit, String window);

  /// Accessibility: PR ring anchor label
  ///
  /// In en, this message translates to:
  /// **'PR marker at {weight} {unit}'**
  String prMarkerAt(String weight, String unit);

  /// Set row accessibility: set number with type info
  ///
  /// In en, this message translates to:
  /// **'Set {number}. Long press to change type: {type}'**
  String setNumberSemantics(int number, String type);

  /// Set row accessibility: set number with copy hint and type info
  ///
  /// In en, this message translates to:
  /// **'Set {number}. Tap to copy previous set. Long press to change type: {type}'**
  String setNumberCopySemantics(int number, String type);

  /// Set row tooltip: tap to copy, hold to change type
  ///
  /// In en, this message translates to:
  /// **'Tap: copy last set\nHold: change type'**
  String get tooltipCopyLastSetAndChangeType;

  /// Set row tooltip: hold to change type
  ///
  /// In en, this message translates to:
  /// **'Hold: change type'**
  String get tooltipChangeType;

  /// Accessibility: set completion checkbox label (completed)
  ///
  /// In en, this message translates to:
  /// **'Set completed'**
  String get setCompleted;

  /// Accessibility: set completion checkbox label (not completed)
  ///
  /// In en, this message translates to:
  /// **'Mark set as done'**
  String get markSetAsDone;

  /// Accessibility: RPE indicator with value
  ///
  /// In en, this message translates to:
  /// **'RPE {value}. Tap to change.'**
  String rpeValue(int value);

  /// Accessibility: RPE indicator without value
  ///
  /// In en, this message translates to:
  /// **'Set RPE'**
  String get setRpe;

  /// RPE label displayed in indicator
  ///
  /// In en, this message translates to:
  /// **'RPE'**
  String get rpeLabel;

  /// RPE popup menu item
  ///
  /// In en, this message translates to:
  /// **'RPE {value}'**
  String rpeMenuItem(int value);

  /// Tooltip: enter reorder mode
  ///
  /// In en, this message translates to:
  /// **'Reorder exercises'**
  String get reorderExercisesTooltip;

  /// Tooltip: exit reorder mode
  ///
  /// In en, this message translates to:
  /// **'Exit reorder mode'**
  String get exitReorderModeTooltip;

  /// Exercise card accessibility label in active workout
  ///
  /// In en, this message translates to:
  /// **'Exercise: {name}. Tap for details. Long press to swap.'**
  String exerciseSemanticsLabel(String name);

  /// Accessibility: fill remaining sets button
  ///
  /// In en, this message translates to:
  /// **'Fill remaining sets with last completed values'**
  String get fillRemainingSetsSemantics;

  /// Accessibility: add exercise FAB
  ///
  /// In en, this message translates to:
  /// **'Add exercise to workout'**
  String get addExerciseToWorkoutSemantics;

  /// Accessibility: exercise picker search
  ///
  /// In en, this message translates to:
  /// **'Search exercises to add'**
  String get searchExercisesToAddSemantics;

  /// Accessibility: add specific exercise from picker
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String addExerciseSemantics(String name);

  /// Set type abbreviation: working
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get setTypeAbbrWorking;

  /// Set type abbreviation: warm-up
  ///
  /// In en, this message translates to:
  /// **'WU'**
  String get setTypeAbbrWarmup;

  /// Set type abbreviation: drop set
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get setTypeAbbrDropset;

  /// Set type abbreviation: to failure
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get setTypeAbbrFailure;

  /// Set type abbreviation: warm-up (detail view)
  ///
  /// In en, this message translates to:
  /// **'Wu'**
  String get setTypeAbbrWarmupShort;

  /// Accessibility: last session line
  ///
  /// In en, this message translates to:
  /// **'Last session: {name}, {date}'**
  String lastSessionSemantics(String name, String date);

  /// Accessibility: exercise list search
  ///
  /// In en, this message translates to:
  /// **'Search exercises'**
  String get searchExercisesSemantics;

  /// Accessibility: exercise list item
  ///
  /// In en, this message translates to:
  /// **'Exercise: {name}'**
  String exerciseItemSemantics(String name);

  /// Accessibility: create exercise FAB
  ///
  /// In en, this message translates to:
  /// **'Create new exercise'**
  String get createNewExerciseSemantics;

  /// Accessibility prefix for muscle group picker
  ///
  /// In en, this message translates to:
  /// **'Muscle group'**
  String get muscleGroupSemanticsPrefix;

  /// Accessibility prefix for equipment type picker
  ///
  /// In en, this message translates to:
  /// **'Equipment type'**
  String get equipmentTypeSemanticsPrefix;

  /// Accessibility: delete exercise button
  ///
  /// In en, this message translates to:
  /// **'Delete exercise'**
  String get deleteExerciseSemantics;

  /// Validation: exercise name already exists
  ///
  /// In en, this message translates to:
  /// **'An exercise with this name already exists'**
  String get exerciseNameDuplicate;

  /// Short relative date: N days ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgoShort(int count);

  /// Short relative date: N weeks ago
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String weeksAgoShort(int count);

  /// Short relative date: N months ago
  ///
  /// In en, this message translates to:
  /// **'{count}mo ago'**
  String monthsAgoShort(int count);

  /// Default routine name: Push Day
  ///
  /// In en, this message translates to:
  /// **'Push Day'**
  String get routineNamePushDay;

  /// Default routine name: Pull Day
  ///
  /// In en, this message translates to:
  /// **'Pull Day'**
  String get routineNamePullDay;

  /// Default routine name: Leg Day
  ///
  /// In en, this message translates to:
  /// **'Leg Day'**
  String get routineNameLegDay;

  /// Default routine name: Full Body
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get routineNameFullBody;

  /// Default routine name: Upper/Lower — Upper
  ///
  /// In en, this message translates to:
  /// **'Upper/Lower — Upper'**
  String get routineNameUpperLowerUpper;

  /// Default routine name: Upper/Lower — Lower
  ///
  /// In en, this message translates to:
  /// **'Upper/Lower — Lower'**
  String get routineNameUpperLowerLower;

  /// Default routine name: 5x5 Strength
  ///
  /// In en, this message translates to:
  /// **'5x5 Strength'**
  String get routineNameFiveByFiveStrength;

  /// Default routine name: Full Body Beginner
  ///
  /// In en, this message translates to:
  /// **'Full Body Beginner'**
  String get routineNameFullBodyBeginner;

  /// Default routine name: Arms & Abs
  ///
  /// In en, this message translates to:
  /// **'Arms & Abs'**
  String get routineNameArmsAndAbs;

  /// Exercise name: Barbell Bench Press
  ///
  /// In en, this message translates to:
  /// **'Barbell Bench Press'**
  String get exerciseName_barbell_bench_press;

  /// Exercise name: Incline Barbell Bench Press
  ///
  /// In en, this message translates to:
  /// **'Incline Barbell Bench Press'**
  String get exerciseName_incline_barbell_bench_press;

  /// Exercise name: Decline Barbell Bench Press
  ///
  /// In en, this message translates to:
  /// **'Decline Barbell Bench Press'**
  String get exerciseName_decline_barbell_bench_press;

  /// Exercise name: Dumbbell Bench Press
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Bench Press'**
  String get exerciseName_dumbbell_bench_press;

  /// Exercise name: Incline Dumbbell Press
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Press'**
  String get exerciseName_incline_dumbbell_press;

  /// Exercise name: Dumbbell Fly
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Fly'**
  String get exerciseName_dumbbell_fly;

  /// Exercise name: Cable Crossover
  ///
  /// In en, this message translates to:
  /// **'Cable Crossover'**
  String get exerciseName_cable_crossover;

  /// Exercise name: Machine Chest Press
  ///
  /// In en, this message translates to:
  /// **'Machine Chest Press'**
  String get exerciseName_machine_chest_press;

  /// Exercise name: Push-Up
  ///
  /// In en, this message translates to:
  /// **'Push-Up'**
  String get exerciseName_push_up;

  /// Exercise name: Barbell Bent-Over Row
  ///
  /// In en, this message translates to:
  /// **'Barbell Bent-Over Row'**
  String get exerciseName_barbell_bent_over_row;

  /// Exercise name: Deadlift
  ///
  /// In en, this message translates to:
  /// **'Deadlift'**
  String get exerciseName_deadlift;

  /// Exercise name: T-Bar Row
  ///
  /// In en, this message translates to:
  /// **'T-Bar Row'**
  String get exerciseName_t_bar_row;

  /// Exercise name: Dumbbell Row
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Row'**
  String get exerciseName_dumbbell_row;

  /// Exercise name: Dumbbell Pullover
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Pullover'**
  String get exerciseName_dumbbell_pullover;

  /// Exercise name: Cable Row
  ///
  /// In en, this message translates to:
  /// **'Cable Row'**
  String get exerciseName_cable_row;

  /// Exercise name: Lat Pulldown
  ///
  /// In en, this message translates to:
  /// **'Lat Pulldown'**
  String get exerciseName_lat_pulldown;

  /// Exercise name: Pull-Up
  ///
  /// In en, this message translates to:
  /// **'Pull-Up'**
  String get exerciseName_pull_up;

  /// Exercise name: Chin-Up
  ///
  /// In en, this message translates to:
  /// **'Chin-Up'**
  String get exerciseName_chin_up;

  /// Exercise name: Machine Row
  ///
  /// In en, this message translates to:
  /// **'Machine Row'**
  String get exerciseName_machine_row;

  /// Exercise name: Barbell Squat
  ///
  /// In en, this message translates to:
  /// **'Barbell Squat'**
  String get exerciseName_barbell_squat;

  /// Exercise name: Front Squat
  ///
  /// In en, this message translates to:
  /// **'Front Squat'**
  String get exerciseName_front_squat;

  /// Exercise name: Romanian Deadlift
  ///
  /// In en, this message translates to:
  /// **'Romanian Deadlift'**
  String get exerciseName_romanian_deadlift;

  /// Exercise name: Hip Thrust
  ///
  /// In en, this message translates to:
  /// **'Hip Thrust'**
  String get exerciseName_hip_thrust;

  /// Exercise name: Dumbbell Lunges
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Lunges'**
  String get exerciseName_dumbbell_lunges;

  /// Exercise name: Bulgarian Split Squat
  ///
  /// In en, this message translates to:
  /// **'Bulgarian Split Squat'**
  String get exerciseName_bulgarian_split_squat;

  /// Exercise name: Goblet Squat
  ///
  /// In en, this message translates to:
  /// **'Goblet Squat'**
  String get exerciseName_goblet_squat;

  /// Exercise name: Leg Press
  ///
  /// In en, this message translates to:
  /// **'Leg Press'**
  String get exerciseName_leg_press;

  /// Exercise name: Leg Extension
  ///
  /// In en, this message translates to:
  /// **'Leg Extension'**
  String get exerciseName_leg_extension;

  /// Exercise name: Leg Curl
  ///
  /// In en, this message translates to:
  /// **'Leg Curl'**
  String get exerciseName_leg_curl;

  /// Exercise name: Calf Raise
  ///
  /// In en, this message translates to:
  /// **'Calf Raise'**
  String get exerciseName_calf_raise;

  /// Exercise name: Overhead Press
  ///
  /// In en, this message translates to:
  /// **'Overhead Press'**
  String get exerciseName_overhead_press;

  /// Exercise name: Push Press
  ///
  /// In en, this message translates to:
  /// **'Push Press'**
  String get exerciseName_push_press;

  /// Exercise name: Dumbbell Shoulder Press
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Shoulder Press'**
  String get exerciseName_dumbbell_shoulder_press;

  /// Exercise name: Arnold Press
  ///
  /// In en, this message translates to:
  /// **'Arnold Press'**
  String get exerciseName_arnold_press;

  /// Exercise name: Lateral Raise
  ///
  /// In en, this message translates to:
  /// **'Lateral Raise'**
  String get exerciseName_lateral_raise;

  /// Exercise name: Front Raise
  ///
  /// In en, this message translates to:
  /// **'Front Raise'**
  String get exerciseName_front_raise;

  /// Exercise name: Rear Delt Fly
  ///
  /// In en, this message translates to:
  /// **'Rear Delt Fly'**
  String get exerciseName_rear_delt_fly;

  /// Exercise name: Cable Face Pull
  ///
  /// In en, this message translates to:
  /// **'Cable Face Pull'**
  String get exerciseName_cable_face_pull;

  /// Exercise name: Barbell Curl
  ///
  /// In en, this message translates to:
  /// **'Barbell Curl'**
  String get exerciseName_barbell_curl;

  /// Exercise name: EZ Bar Curl
  ///
  /// In en, this message translates to:
  /// **'EZ Bar Curl'**
  String get exerciseName_ez_bar_curl;

  /// Exercise name: Skull Crusher
  ///
  /// In en, this message translates to:
  /// **'Skull Crusher'**
  String get exerciseName_skull_crusher;

  /// Exercise name: Dumbbell Curl
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Curl'**
  String get exerciseName_dumbbell_curl;

  /// Exercise name: Hammer Curl
  ///
  /// In en, this message translates to:
  /// **'Hammer Curl'**
  String get exerciseName_hammer_curl;

  /// Exercise name: Concentration Curl
  ///
  /// In en, this message translates to:
  /// **'Concentration Curl'**
  String get exerciseName_concentration_curl;

  /// Exercise name: Dumbbell Tricep Extension
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Tricep Extension'**
  String get exerciseName_dumbbell_tricep_extension;

  /// Exercise name: Tricep Pushdown
  ///
  /// In en, this message translates to:
  /// **'Tricep Pushdown'**
  String get exerciseName_tricep_pushdown;

  /// Exercise name: Cable Curl
  ///
  /// In en, this message translates to:
  /// **'Cable Curl'**
  String get exerciseName_cable_curl;

  /// Exercise name: Dips
  ///
  /// In en, this message translates to:
  /// **'Dips'**
  String get exerciseName_dips;

  /// Exercise name: Plank
  ///
  /// In en, this message translates to:
  /// **'Plank'**
  String get exerciseName_plank;

  /// Exercise name: Hanging Leg Raise
  ///
  /// In en, this message translates to:
  /// **'Hanging Leg Raise'**
  String get exerciseName_hanging_leg_raise;

  /// Exercise name: Crunches
  ///
  /// In en, this message translates to:
  /// **'Crunches'**
  String get exerciseName_crunches;

  /// Exercise name: Ab Rollout
  ///
  /// In en, this message translates to:
  /// **'Ab Rollout'**
  String get exerciseName_ab_rollout;

  /// Exercise name: Russian Twist
  ///
  /// In en, this message translates to:
  /// **'Russian Twist'**
  String get exerciseName_russian_twist;

  /// Exercise name: Dead Bug
  ///
  /// In en, this message translates to:
  /// **'Dead Bug'**
  String get exerciseName_dead_bug;

  /// Exercise name: Cable Woodchop
  ///
  /// In en, this message translates to:
  /// **'Cable Woodchop'**
  String get exerciseName_cable_woodchop;

  /// Exercise name: Band Pull-Apart
  ///
  /// In en, this message translates to:
  /// **'Band Pull-Apart'**
  String get exerciseName_band_pull_apart;

  /// Exercise name: Band Face Pull
  ///
  /// In en, this message translates to:
  /// **'Band Face Pull'**
  String get exerciseName_band_face_pull;

  /// Exercise name: Band Squat
  ///
  /// In en, this message translates to:
  /// **'Band Squat'**
  String get exerciseName_band_squat;

  /// Exercise name: Kettlebell Swing
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Swing'**
  String get exerciseName_kettlebell_swing;

  /// Exercise name: Kettlebell Goblet Squat
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Goblet Squat'**
  String get exerciseName_kettlebell_goblet_squat;

  /// Exercise name: Kettlebell Turkish Get-Up
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Turkish Get-Up'**
  String get exerciseName_kettlebell_turkish_get_up;

  /// Exercise name: Pec Deck
  ///
  /// In en, this message translates to:
  /// **'Pec Deck'**
  String get exerciseName_pec_deck;

  /// Exercise name: Cable Chest Press
  ///
  /// In en, this message translates to:
  /// **'Cable Chest Press'**
  String get exerciseName_cable_chest_press;

  /// Exercise name: Wide Push-Up
  ///
  /// In en, this message translates to:
  /// **'Wide Push-Up'**
  String get exerciseName_wide_push_up;

  /// Exercise name: Face Pull
  ///
  /// In en, this message translates to:
  /// **'Face Pull'**
  String get exerciseName_face_pull;

  /// Exercise name: Rack Pull
  ///
  /// In en, this message translates to:
  /// **'Rack Pull'**
  String get exerciseName_rack_pull;

  /// Exercise name: Good Morning
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get exerciseName_good_morning;

  /// Exercise name: Pendlay Row
  ///
  /// In en, this message translates to:
  /// **'Pendlay Row'**
  String get exerciseName_pendlay_row;

  /// Exercise name: Hack Squat
  ///
  /// In en, this message translates to:
  /// **'Hack Squat'**
  String get exerciseName_hack_squat;

  /// Exercise name: Sumo Deadlift
  ///
  /// In en, this message translates to:
  /// **'Sumo Deadlift'**
  String get exerciseName_sumo_deadlift;

  /// Exercise name: Walking Lunges
  ///
  /// In en, this message translates to:
  /// **'Walking Lunges'**
  String get exerciseName_walking_lunges;

  /// Exercise name: Step-Up
  ///
  /// In en, this message translates to:
  /// **'Step-Up'**
  String get exerciseName_step_up;

  /// Exercise name: Seated Calf Raise
  ///
  /// In en, this message translates to:
  /// **'Seated Calf Raise'**
  String get exerciseName_seated_calf_raise;

  /// Exercise name: Leg Abductor
  ///
  /// In en, this message translates to:
  /// **'Leg Abductor'**
  String get exerciseName_leg_abductor;

  /// Exercise name: Leg Adductor
  ///
  /// In en, this message translates to:
  /// **'Leg Adductor'**
  String get exerciseName_leg_adductor;

  /// Exercise name: Upright Row
  ///
  /// In en, this message translates to:
  /// **'Upright Row'**
  String get exerciseName_upright_row;

  /// Exercise name: Machine Shoulder Press
  ///
  /// In en, this message translates to:
  /// **'Machine Shoulder Press'**
  String get exerciseName_machine_shoulder_press;

  /// Exercise name: Cable Lateral Raise
  ///
  /// In en, this message translates to:
  /// **'Cable Lateral Raise'**
  String get exerciseName_cable_lateral_raise;

  /// Exercise name: Preacher Curl
  ///
  /// In en, this message translates to:
  /// **'Preacher Curl'**
  String get exerciseName_preacher_curl;

  /// Exercise name: Incline Dumbbell Curl
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Curl'**
  String get exerciseName_incline_dumbbell_curl;

  /// Exercise name: Close-Grip Bench Press
  ///
  /// In en, this message translates to:
  /// **'Close-Grip Bench Press'**
  String get exerciseName_close_grip_bench_press;

  /// Exercise name: Overhead Tricep Extension
  ///
  /// In en, this message translates to:
  /// **'Overhead Tricep Extension'**
  String get exerciseName_overhead_tricep_extension;

  /// Exercise name: Rope Pushdown
  ///
  /// In en, this message translates to:
  /// **'Rope Pushdown'**
  String get exerciseName_rope_pushdown;

  /// Exercise name: Bicycle Crunch
  ///
  /// In en, this message translates to:
  /// **'Bicycle Crunch'**
  String get exerciseName_bicycle_crunch;

  /// Exercise name: Cable Crunch
  ///
  /// In en, this message translates to:
  /// **'Cable Crunch'**
  String get exerciseName_cable_crunch;

  /// Exercise name: Pallof Press
  ///
  /// In en, this message translates to:
  /// **'Pallof Press'**
  String get exerciseName_pallof_press;

  /// Exercise name: Side Plank
  ///
  /// In en, this message translates to:
  /// **'Side Plank'**
  String get exerciseName_side_plank;

  /// Exercise name: Treadmill
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get exerciseName_treadmill;

  /// Exercise name: Rowing Machine
  ///
  /// In en, this message translates to:
  /// **'Rowing Machine'**
  String get exerciseName_rowing_machine;

  /// Exercise name: Stationary Bike
  ///
  /// In en, this message translates to:
  /// **'Stationary Bike'**
  String get exerciseName_stationary_bike;

  /// Exercise name: Jump Rope
  ///
  /// In en, this message translates to:
  /// **'Jump Rope'**
  String get exerciseName_jump_rope;

  /// Exercise name: Elliptical
  ///
  /// In en, this message translates to:
  /// **'Elliptical'**
  String get exerciseName_elliptical;

  /// Exercise name: Incline Dumbbell Fly
  ///
  /// In en, this message translates to:
  /// **'Incline Dumbbell Fly'**
  String get exerciseName_incline_dumbbell_fly;

  /// Exercise name: Decline Dumbbell Press
  ///
  /// In en, this message translates to:
  /// **'Decline Dumbbell Press'**
  String get exerciseName_decline_dumbbell_press;

  /// Exercise name: Landmine Press
  ///
  /// In en, this message translates to:
  /// **'Landmine Press'**
  String get exerciseName_landmine_press;

  /// Exercise name: Diamond Push-Up
  ///
  /// In en, this message translates to:
  /// **'Diamond Push-Up'**
  String get exerciseName_diamond_push_up;

  /// Exercise name: Incline Push-Up
  ///
  /// In en, this message translates to:
  /// **'Incline Push-Up'**
  String get exerciseName_incline_push_up;

  /// Exercise name: Decline Push-Up
  ///
  /// In en, this message translates to:
  /// **'Decline Push-Up'**
  String get exerciseName_decline_push_up;

  /// Exercise name: Hyperextension
  ///
  /// In en, this message translates to:
  /// **'Hyperextension'**
  String get exerciseName_hyperextension;

  /// Exercise name: Back Extension
  ///
  /// In en, this message translates to:
  /// **'Back Extension'**
  String get exerciseName_back_extension;

  /// Exercise name: Inverted Row
  ///
  /// In en, this message translates to:
  /// **'Inverted Row'**
  String get exerciseName_inverted_row;

  /// Exercise name: Chest-Supported Row
  ///
  /// In en, this message translates to:
  /// **'Chest-Supported Row'**
  String get exerciseName_chest_supported_row;

  /// Exercise name: Seal Row
  ///
  /// In en, this message translates to:
  /// **'Seal Row'**
  String get exerciseName_seal_row;

  /// Exercise name: Straight-Arm Pulldown
  ///
  /// In en, this message translates to:
  /// **'Straight-Arm Pulldown'**
  String get exerciseName_straight_arm_pulldown;

  /// Exercise name: Close-Grip Lat Pulldown
  ///
  /// In en, this message translates to:
  /// **'Close-Grip Lat Pulldown'**
  String get exerciseName_close_grip_lat_pulldown;

  /// Exercise name: Wide-Grip Pull-Up
  ///
  /// In en, this message translates to:
  /// **'Wide-Grip Pull-Up'**
  String get exerciseName_wide_grip_pull_up;

  /// Exercise name: Kettlebell Row
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Row'**
  String get exerciseName_kettlebell_row;

  /// Exercise name: Glute Bridge
  ///
  /// In en, this message translates to:
  /// **'Glute Bridge'**
  String get exerciseName_glute_bridge;

  /// Exercise name: Single-Leg Glute Bridge
  ///
  /// In en, this message translates to:
  /// **'Single-Leg Glute Bridge'**
  String get exerciseName_single_leg_glute_bridge;

  /// Exercise name: Box Jump
  ///
  /// In en, this message translates to:
  /// **'Box Jump'**
  String get exerciseName_box_jump;

  /// Exercise name: Nordic Curl
  ///
  /// In en, this message translates to:
  /// **'Nordic Curl'**
  String get exerciseName_nordic_curl;

  /// Exercise name: Wall Sit
  ///
  /// In en, this message translates to:
  /// **'Wall Sit'**
  String get exerciseName_wall_sit;

  /// Exercise name: Donkey Kick
  ///
  /// In en, this message translates to:
  /// **'Donkey Kick'**
  String get exerciseName_donkey_kick;

  /// Exercise name: Bodyweight Squat
  ///
  /// In en, this message translates to:
  /// **'Bodyweight Squat'**
  String get exerciseName_bodyweight_squat;

  /// Exercise name: Reverse Lunges
  ///
  /// In en, this message translates to:
  /// **'Reverse Lunges'**
  String get exerciseName_reverse_lunges;

  /// Exercise name: Dumbbell Calf Raise
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Calf Raise'**
  String get exerciseName_dumbbell_calf_raise;

  /// Exercise name: Single-Leg Leg Press
  ///
  /// In en, this message translates to:
  /// **'Single-Leg Leg Press'**
  String get exerciseName_single_leg_leg_press;

  /// Exercise name: Reverse Hyperextension
  ///
  /// In en, this message translates to:
  /// **'Reverse Hyperextension'**
  String get exerciseName_reverse_hyperextension;

  /// Exercise name: Cable Glute Kickback
  ///
  /// In en, this message translates to:
  /// **'Cable Glute Kickback'**
  String get exerciseName_cable_glute_kickback;

  /// Exercise name: Cable Pull-Through
  ///
  /// In en, this message translates to:
  /// **'Cable Pull-Through'**
  String get exerciseName_cable_pull_through;

  /// Exercise name: Kettlebell Deadlift
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Deadlift'**
  String get exerciseName_kettlebell_deadlift;

  /// Exercise name: Barbell Shrug
  ///
  /// In en, this message translates to:
  /// **'Barbell Shrug'**
  String get exerciseName_barbell_shrug;

  /// Exercise name: Dumbbell Shrug
  ///
  /// In en, this message translates to:
  /// **'Dumbbell Shrug'**
  String get exerciseName_dumbbell_shrug;

  /// Exercise name: Cable Rear Delt Fly
  ///
  /// In en, this message translates to:
  /// **'Cable Rear Delt Fly'**
  String get exerciseName_cable_rear_delt_fly;

  /// Exercise name: Cable Front Raise
  ///
  /// In en, this message translates to:
  /// **'Cable Front Raise'**
  String get exerciseName_cable_front_raise;

  /// Exercise name: Reverse Pec Deck
  ///
  /// In en, this message translates to:
  /// **'Reverse Pec Deck'**
  String get exerciseName_reverse_pec_deck;

  /// Exercise name: Landmine Shoulder Press
  ///
  /// In en, this message translates to:
  /// **'Landmine Shoulder Press'**
  String get exerciseName_landmine_shoulder_press;

  /// Exercise name: Kettlebell Press
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Press'**
  String get exerciseName_kettlebell_press;

  /// Exercise name: Spider Curl
  ///
  /// In en, this message translates to:
  /// **'Spider Curl'**
  String get exerciseName_spider_curl;

  /// Exercise name: Zottman Curl
  ///
  /// In en, this message translates to:
  /// **'Zottman Curl'**
  String get exerciseName_zottman_curl;

  /// Exercise name: Reverse Curl
  ///
  /// In en, this message translates to:
  /// **'Reverse Curl'**
  String get exerciseName_reverse_curl;

  /// Exercise name: Wrist Curl
  ///
  /// In en, this message translates to:
  /// **'Wrist Curl'**
  String get exerciseName_wrist_curl;

  /// Exercise name: Reverse Wrist Curl
  ///
  /// In en, this message translates to:
  /// **'Reverse Wrist Curl'**
  String get exerciseName_reverse_wrist_curl;

  /// Exercise name: Farmer's Walk
  ///
  /// In en, this message translates to:
  /// **'Farmer\'s Walk'**
  String get exerciseName_farmer_s_walk;

  /// Exercise name: Cable Hammer Curl
  ///
  /// In en, this message translates to:
  /// **'Cable Hammer Curl'**
  String get exerciseName_cable_hammer_curl;

  /// Exercise name: Bench Dip
  ///
  /// In en, this message translates to:
  /// **'Bench Dip'**
  String get exerciseName_bench_dip;

  /// Exercise name: Close-Grip Push-Up
  ///
  /// In en, this message translates to:
  /// **'Close-Grip Push-Up'**
  String get exerciseName_close_grip_push_up;

  /// Exercise name: JM Press
  ///
  /// In en, this message translates to:
  /// **'JM Press'**
  String get exerciseName_jm_press;

  /// Exercise name: Sit-Up
  ///
  /// In en, this message translates to:
  /// **'Sit-Up'**
  String get exerciseName_sit_up;

  /// Exercise name: Mountain Climber
  ///
  /// In en, this message translates to:
  /// **'Mountain Climber'**
  String get exerciseName_mountain_climber;

  /// Exercise name: Toe Touch
  ///
  /// In en, this message translates to:
  /// **'Toe Touch'**
  String get exerciseName_toe_touch;

  /// Exercise name: Hollow Body Hold
  ///
  /// In en, this message translates to:
  /// **'Hollow Body Hold'**
  String get exerciseName_hollow_body_hold;

  /// Exercise name: V-Up
  ///
  /// In en, this message translates to:
  /// **'V-Up'**
  String get exerciseName_v_up;

  /// Exercise name: Flutter Kick
  ///
  /// In en, this message translates to:
  /// **'Flutter Kick'**
  String get exerciseName_flutter_kick;

  /// Exercise name: Reverse Crunch
  ///
  /// In en, this message translates to:
  /// **'Reverse Crunch'**
  String get exerciseName_reverse_crunch;

  /// Exercise name: Leg Raise
  ///
  /// In en, this message translates to:
  /// **'Leg Raise'**
  String get exerciseName_leg_raise;

  /// Exercise name: Windshield Wiper
  ///
  /// In en, this message translates to:
  /// **'Windshield Wiper'**
  String get exerciseName_windshield_wiper;

  /// Exercise name: Plank Up-Down
  ///
  /// In en, this message translates to:
  /// **'Plank Up-Down'**
  String get exerciseName_plank_up_down;

  /// Exercise name: Heel Touch
  ///
  /// In en, this message translates to:
  /// **'Heel Touch'**
  String get exerciseName_heel_touch;

  /// Exercise name: Kettlebell Windmill
  ///
  /// In en, this message translates to:
  /// **'Kettlebell Windmill'**
  String get exerciseName_kettlebell_windmill;

  /// Section header: preferences
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// Language preference row label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
