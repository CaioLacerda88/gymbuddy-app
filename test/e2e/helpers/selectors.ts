/**
 * Centralized selectors for GymBuddy Flutter web.
 *
 * Flutter 3.41.6+ uses the Accessibility Object Model (AOM) for accessible
 * names instead of setting `aria-label` as a DOM attribute on flt-semantics
 * elements. This means CSS selectors like `flt-semantics[aria-label="X"]`
 * return 0 matches. Instead, use Playwright role-based selectors like
 * `role=button[name="X"]` which query the browser accessibility tree.
 *
 * Exceptions (still use DOM attributes):
 *   - Native <input> elements retain `aria-label` (e.g., AUTH.emailInput)
 *   - `aria-live` attributes are still set as DOM attributes
 *   - `role` is still set as a DOM attribute on flt-semantics elements
 *
 * Semantics labels found in the source (use role= selectors to match):
 *   - _MuscleGroupButton:  'role=button[name="<name> muscle group filter"]'
 *   - _SearchBar:          'role=textbox[name="Search exercises"]'
 *   - _EquipmentFilter:    'role=checkbox[name="<name>"]'
 *   - _ExerciseCard:       'role=button[name="Exercise: <name>"]'
 *   - _CreateExerciseFab:  'role=button[name="Create new exercise"]'
 *   - _TappableImage:      'role=img[name="<name> start position"]' / "end position"
 *   - Delete button:       'role=button[name="Delete exercise"]'
 */

// ---------------------------------------------------------------------------
// Auth — LoginScreen
// LoginScreen uses AppTextField with label props "Email" and "Password" and
// AppButton with label "LOG IN" / "SIGN UP". No Semantics wrappers added yet,
// so we target visible text / placeholder text.
// ---------------------------------------------------------------------------
export const AUTH = {
  /** AppTextField with label "Email" — Flutter renders <input> in HTML mode */
  emailInput: '[aria-label="Email"]',
  /** AppTextField with label "Password" */
  passwordInput: '[aria-label="Password"]',
  /** AppButton label "LOG IN" — nth=0 avoids strict-mode on nested flt-semantics */
  loginButton: 'role=button[name="LOG IN"] >> nth=0',
  /** AppButton label "SIGN UP" — nth=0 avoids strict-mode on nested flt-semantics */
  signUpButton: 'role=button[name="SIGN UP"] >> nth=0',
  /** TextButton "Don't have an account? Sign up" */
  toggleToSignUp: "text=Don't have an account? Sign up",
  /** TextButton "Already have an account? Log in" */
  toggleToLogIn: 'text=Already have an account? Log in',
  /** OutlinedButton.icon "Continue with Google" */
  googleButton: 'text=Continue with Google',
  /** TextButton "Forgot password?" */
  forgotPasswordButton: 'text=Forgot password?',
  /** "Send Reset Email" button in the forgot password confirmation dialog */
  sendResetEmailButton: 'text=Send Reset Email',
  /** The "GymBuddy" headline present on the login screen */
  appTitle: 'text=GymBuddy',
  /** "Welcome back" subtitle (sign-in mode) */
  welcomeBack: 'text=Welcome back',
  /** Inline error message — Semantics(liveRegion: true) sets aria-live */
  errorMessage: '[aria-live="polite"]',
} as const;

// ---------------------------------------------------------------------------
// Onboarding — OnboardingScreen (2-page flow after first sign-up, Step 5e)
//
// Step 5e trimmed onboarding from 3 pages to 2:
//   Page 1: Welcome ("Track every rep, every time") → GET STARTED
//   Page 2: Profile setup (display name + fitness level) → LET'S GO
//
// The old NEXT button and workout-choice page (page 3) were removed.
// ---------------------------------------------------------------------------
export const ONBOARDING = {
  /** Page 1 CTA — takes user to profile setup */
  getStartedButton: 'text=GET STARTED',
  /**
   * NEXT button — was used on page 2 of the old 3-page flow.
   * After Step 5e this button no longer exists. The selector is kept here
   * so tests can assert `not.toBeVisible()` on it.
   */
  nextButton: 'text=NEXT',
  /** Display name input on page 2 */
  displayNameInput: '[aria-label="Display name"]',
  /** Page 2 final CTA — submits onboarding profile and navigates to home */
  letsGoButton: "text=LET'S GO",
} as const;

// ---------------------------------------------------------------------------
// Shell / Bottom Navigation
// NavigationDestination labels are exposed as accessible names via AOM.
// Use role=tab selectors to match them in the accessibility tree.
// Tabs: Home, Exercises, Routines, Profile.
// ---------------------------------------------------------------------------
export const NAV = {
  homeTab: 'role=tab[name="Home"]',
  exercisesTab: 'role=tab[name="Exercises"]',
  routinesTab: 'role=tab[name="Routines"]',
  profileTab: 'role=tab[name="Profile"]',
} as const;

// ---------------------------------------------------------------------------
// Exercise list — ExerciseListScreen
// ---------------------------------------------------------------------------
export const EXERCISE_LIST = {
  /** Page heading — use first() to avoid strict-mode collision with nav tab */
  heading: 'text=Exercises',
  /** Search field — role selector matches computed accessible name */
  searchInput: 'role=textbox[name*="Search exercises"]',
  /** "All" muscle group filter — role selector matches computed accessible name */
  allMuscleGroupFilter: 'role=button[name*="All muscle group filter"]',
  /** Muscle group filter buttons — role selector for computed accessible name */
  muscleGroupFilter: (name: string) =>
    `role=button[name*="${name} muscle group filter"]`,
  /** Equipment FilterChip — role selector for computed accessible name */
  equipmentFilter: (name: string) =>
    `role=checkbox[name*="${name}"]`,
  /** Individual exercise card — role selector for computed accessible name */
  exerciseCard: (name: string) => `role=button[name*="Exercise: ${name}"]`,
  /** FAB — role selector for computed accessible name */
  createFab: 'role=button[name*="Create new exercise"]',
  /** Empty state when no filters applied */
  emptyStateNoFilter: 'text=Your exercises will appear here',
  /** Empty state when filters yield no results */
  emptyStateFiltered: 'text=No exercises match your filters',
  /** Clear Filters button in filtered empty state */
  clearFiltersButton: 'text=Clear Filters',
} as const;

// ---------------------------------------------------------------------------
// Exercise detail — ExerciseDetailScreen
// ---------------------------------------------------------------------------
export const EXERCISE_DETAIL = {
  /** AppBar title */
  appBarTitle: 'text=Exercise Details',
  /** "Custom exercise" badge (only on user-created exercises) */
  customBadge: 'text=Custom exercise',
  /** Delete button — case-insensitive match for "Delete Exercise" / "Delete exercise" */
  deleteButton: 'role=button[name=/delete exercise/i]',
  /** Confirmation dialog content — unique to the dialog, avoids collision with
   *  "Delete Exercise" button text which also matches 'text=Delete Exercise' */
  deleteDialogContent: 'text=Are you sure you want to delete',
  /** Confirm delete action in the dialog — scoped to alertdialog to avoid
   *  matching the "Delete Exercise" button on the detail screen itself */
  deleteConfirmButton: 'role=alertdialog >> role=button[name="Delete"]',
  /** Cancel delete action in dialog */
  deleteCancelButton: 'text=Cancel',
  /** Coming-soon placeholder text */
  prPlaceholder: 'text=Personal records & workout history coming soon',
  /**
   * Start-position image for a named exercise in _ExerciseImageRow.
   * _TappableImage wraps the image in Semantics(label: '${name} start position', image: true).
   * Flutter 3.41.6+ exposes this as role=img with the computed accessible name.
   */
  startImage: (name: string) => `role=img[name*="${name} start position"]`,
  /**
   * End-position image for a named exercise in _ExerciseImageRow.
   * _TappableImage wraps the image in Semantics(label: '${name} end position', image: true).
   */
  endImage: (name: string) => `role=img[name*="${name} end position"]`,
} as const;

// ---------------------------------------------------------------------------
// Create exercise — CreateExerciseScreen
// AppTextField label is "Exercise Name", button label is "CREATE EXERCISE"
// ---------------------------------------------------------------------------
export const CREATE_EXERCISE = {
  nameInput: 'role=textbox[name*="Exercise Name"]',
  /** Case-sensitive exact match avoids collision with heading "Create Exercise" */
  saveButton: 'text="CREATE EXERCISE"',
} as const;

// ---------------------------------------------------------------------------
// Active workout — ActiveWorkoutScreen
// ---------------------------------------------------------------------------
export const WORKOUT = {
  /** "Start Empty Workout" button on the Home screen launchpad */
  startEmpty: 'text=Start Empty Workout',
  /** "Finish Workout" button in the persistent bottom bar */
  finishButton: 'text=Finish Workout',
  /** "Save & Finish" button in the finish workout confirmation dialog */
  dialogFinishButton: 'text=Save & Finish',
  /** "Add Exercise" FAB on the active workout screen */
  addExerciseFab: 'text=Add Exercise',
  /** "Add Set" button within an exercise card */
  addSetButton: 'text=Add Set',
  /** Checkbox to mark a set as done — unchecked state */
  markSetDone: 'role=checkbox[name="Mark set as done"]',
  /** Checkbox to mark a set as done — checked state */
  setCompleted: 'role=checkbox[name="Set completed"]',
  /** Close / discard icon button in the AppBar — Semantics label "Discard workout" */
  discardButton: 'role=button[name="Discard workout"]',
  /** "Discard" confirm button inside the DiscardWorkoutDialog */
  discardConfirmButton: 'role=button[name="Discard"]',
  /** "Keep Going" button in the finish confirmation dialog (cancels finish) */
  keepGoingButton: 'text=Keep Going',
  /** Tappable weight value that opens the weight entry dialog */
  enterWeightDialog: 'text=Enter weight',
  /** Tappable reps value that opens the reps entry dialog */
  enterRepsDialog: 'text=Enter reps',
  /** Optional notes input on the active workout screen */
  notesInput: 'role=textbox[name="Workout notes"]',
  /**
   * Exercise name tappable area inside an exercise card during an active workout.
   *
   * _ExerciseCard wraps the exercise name in a Semantics with the label:
   *   "Exercise: <name>. Tap for details. Long press to swap."
   * Flutter 3.41.6+ renders this as role=group (not role=button) because the
   * parent Semantics node merges children into a group container.
   * We match on the "Tap for details" substring to target the tappable region
   * regardless of exercise name.
   */
  exerciseDetailTap: (name: string) =>
    `role=group[name*="Exercise: ${name}. Tap for details"]`,
} as const;

// ---------------------------------------------------------------------------
// Exercise picker — bottom sheet shown when adding exercises to a workout
// ---------------------------------------------------------------------------
export const EXERCISE_PICKER = {
  /** Search field — role selector matches computed accessible name */
  searchInput: 'role=textbox[name*="Search exercises to add"]',
  /** "Add <name>" tile — role selector for computed accessible name */
  addExerciseButton: (name: string) =>
    `role=button[name*="Add ${name}"]`,
} as const;

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------
export const HOME = {
  /**
   * Active workout banner in the shell bottom bar — shown when an active
   * workout is in progress on any tab. _ActiveWorkoutBanner (app_router.dart)
   * wraps the banner in Semantics(button: true, label: 'Active workout: <name>').
   * The prefix "Active workout:" is stable regardless of whether the workout
   * was started from a routine (name = routine name) or manually (name =
   * "Workout \u2014 <date>").
   */
  activeBanner: 'role=button[name*="Active workout:"]',
} as const;

// ---------------------------------------------------------------------------
// Personal Records — celebration screen and records list
// ---------------------------------------------------------------------------
export const PR = {
  /** Heading shown when a new personal record is set */
  newPRHeading: 'text=NEW PR',
  /** Heading shown when the user completes their first workout */
  firstWorkoutHeading: 'text=First Workout Complete!',
  /** "Continue" button on the PR celebration screen */
  continueButton: 'text=Continue',
  /** "RECENT RECORDS" section on the progress tab */
  recentRecordsSection: 'text=RECENT RECORDS',
} as const;

// ---------------------------------------------------------------------------
// Routines list — RoutinesScreen
// ---------------------------------------------------------------------------
export const ROUTINE = {
  /** Page heading — use .first() to avoid strict-mode collision with nav tab */
  heading: 'text=Routines',
  /** "MY ROUTINES" section header */
  myRoutinesSection: 'text=MY ROUTINES',
  /** "STARTER ROUTINES" section header */
  starterRoutinesSection: 'text=STARTER ROUTINES',
  /** AppBar action button or on-screen CTA to create a routine */
  createButton: 'text=Create Routine',
  /** Routine card identified by name */
  routineName: (name: string) => `text=${name}`,
  /** Context menu or overflow "Edit" option */
  editOption: 'text=Edit',
  /** Context menu or overflow "Delete" option */
  deleteOption: 'text=Delete',
  /** Delete confirmation dialog title */
  deleteDialogTitle: 'text=Delete Routine',
  /** "Cancel" button in delete dialog */
  cancelButton: 'text=Cancel',
  /** "Delete" confirm button in delete dialog — exact match to avoid title collision */
  deleteConfirmButton: 'text="Delete"',
} as const;

// ---------------------------------------------------------------------------
// Create/Edit routine — CreateRoutineScreen
// ---------------------------------------------------------------------------
export const CREATE_ROUTINE = {
  /** Name text field — hintText "Routine name". Target the flt-semantics
   *  text-field element directly via its data attribute to avoid the raw
   *  HTML input proxy that gets intercepted by the semantics overlay. */
  nameInput: 'input[data-semantics-role="text-field"]',
  /** "Add Exercise" button */
  addExerciseButton: 'text=Add Exercise',
  /** "Save" button */
  saveButton: 'text=Save',
  /** Sets label in set configuration row */
  setsLabel: 'text=Sets',
  /** Rest label in set configuration row */
  restLabel: 'text=Rest',
} as const;

// ---------------------------------------------------------------------------
// Workout history — HistoryScreen
// ---------------------------------------------------------------------------
export const HISTORY = {
  /** Page heading */
  heading: 'role=heading[name="History"]',
  /** Empty state message when no workouts have been logged */
  emptyState: 'text=No workouts yet',
  /** CTA in empty state */
  emptyStateCta: 'text=Start your first workout',
  /** Retry button shown on error state */
  retryButton: 'text=Retry',
} as const;

// ---------------------------------------------------------------------------
// Profile screen — ProfileScreen
// ---------------------------------------------------------------------------
export const PROFILE = {
  /** Page heading — use .first() to avoid strict-mode collision with nav tab */
  heading: 'text=Profile',
  /** Primary "Log Out" button */
  logOutButton: 'text=Log Out',
  /** Confirmation dialog body text */
  logOutConfirmDialog: 'text=Are you sure you want to log out?',
  /** Cancel button in the confirmation dialog */
  cancelButton: 'text=Cancel',
  /** Weight unit "kg" option */
  kgOption: 'text=kg',
  /** Weight unit "lbs" option */
  lbsOption: 'text=lbs',
  /**
   * "Manage Data" row in the DATA MANAGEMENT section.
   * ProfileScreen renders this as a plain Text widget — match on visible text.
   */
  manageData: 'text=Manage Data',
} as const;

// ---------------------------------------------------------------------------
// Manage Data screen — ManageDataScreen
// ---------------------------------------------------------------------------
export const MANAGE_DATA = {
  /** AppBar title */
  heading: 'text=Manage Data',
  /**
   * "Delete Workout History" list tile.
   * Rendered as a ListTile with title Text — match on visible text.
   */
  deleteHistory: 'text=Delete Workout History',
  /**
   * "Reset All Account Data" list tile.
   * Rendered as a ListTile with title Text — match on visible text.
   */
  resetAll: 'text=Reset All Account Data',
  /**
   * "Delete History" button inside the first confirmation dialog.
   * Exact match avoids collision with the tile text "Delete Workout History".
   */
  deleteHistoryConfirmButton: 'text="Delete History"',
  /**
   * "Yes, Delete" button inside the second confirmation dialog.
   */
  yesDeleteButton: 'text="Yes, Delete"',
  /**
   * TextField inside the Reset Account full-screen dialog.
   * Flutter renders a hidden <input> when the TextField is focused; we use the
   * hint text to identify it via role selector.
   */
  resetInput: 'role=textbox[name*="RESET"]',
  /**
   * "Reset Account" GradientButton inside the Reset Account dialog.
   * Match on visible text.
   */
  resetButton: 'role=button[name="Reset Account"]',
  /**
   * Close / cancel icon button in the Reset Account full-screen dialog.
   * The IconButton has tooltip: 'Cancel'.
   */
  resetCancelButton: 'role=button[name="Cancel"]',
  /** SnackBar confirmation after successful history deletion */
  historyCleared: 'text=Workout history cleared',
  /** SnackBar confirmation after successful reset */
  accountReset: 'text=Account data reset',
} as const;

// ---------------------------------------------------------------------------
// Weekly plan — WeekBucketSection (Home screen) and PlanManagementScreen
// ---------------------------------------------------------------------------
export const WEEKLY_PLAN = {
  /**
   * "THIS WEEK" section header on the home screen.
   * _ActiveBucketSection renders Text('THIS WEEK') as a labelLarge.
   */
  thisWeekHeader: 'text=THIS WEEK',
  /**
   * "WEEK COMPLETE" header shown in WeekReviewSection when all buckets done.
   * WeekReviewSection renders isAllComplete ? 'WEEK COMPLETE' : 'THIS WEEK'.
   */
  weekCompleteHeader: 'text=WEEK COMPLETE',
  /**
   * "Plan your week" CTA tappable text in _EmptyBucketState.
   * Rendered when a plan is not set but the user has at least one routine.
   * _EmptyBucketState renders Text('Plan your week') — no trailing arrow.
   */
  planYourWeekCta: 'text=Plan your week',
  /**
   * AppBar title of PlanManagementScreen.
   * Scaffold AppBar title: Text("This Week's Plan").
   */
  planManagementTitle: "text=This Week's Plan",
  /**
   * "Add Routines" FilledButton in the empty state of PlanManagementScreen.
   * _EmptyState renders FilledButton.icon with label Text('Add Routines').
   */
  addRoutinesButton: 'text=Add Routines',
  /**
   * "Add Routine" row at the bottom of the ReorderableListView when items exist.
   * _AddRoutineRow renders Text('Add Routine').
   */
  addRoutineRow: 'text=Add Routine',
  /**
   * "Add Routines" bottom sheet title in AddRoutinesSheet.
   * Rendered as titleLarge Text('Add Routines').
   */
  addRoutinesSheetTitle: 'text=Add Routines',
  /**
   * "ADD 1 ROUTINE" / "ADD N ROUTINES" confirm button in AddRoutinesSheet.
   * Match on the "ADD" prefix — the count varies.
   */
  addConfirmButton: 'role=button[name*="ADD "]',
  /**
   * PopupMenuButton overflow icon (three dots) in the AppBar.
   * Wrapped in Semantics(label: 'More options') — renders as role="group"
   * with aria-label="More options". The child button has no aria-label itself.
   */
  overflowMenuButton: 'role=button[name="More options"]',
  /**
   * "Clear Week" option in the PopupMenuButton overflow menu.
   * PopupMenuItem renders as role="menuitem" with aria-label="Clear Week".
   * The textContent is empty (Flutter CanvasKit), so `text=` won't match.
   */
  clearWeekOption: 'role=menuitem[name="Clear Week"]',
  /**
   * "Clear" confirm button in the _confirmClear AlertDialog.
   * TextButton child: Text('Clear'). Use role=button to avoid matching the
   * "Clear Week" span from the popup menu (text= does substring matching).
   */
  clearConfirmButton: 'role=button[name="Clear"]',
  /**
   * "NEW WEEK" GestureDetector text in WeekReviewSection.
   * Rendered as labelLarge Text('NEW WEEK') when onNewWeek is provided.
   */
  newWeekButton: 'text=NEW WEEK',
  /**
   * Stats text in WeekReviewSection — contains "sessions" substring.
   * _buildStatsText always starts with "{n} sessions".
   */
  sessionsStatsText: 'text=/sessions/',
} as const;

// ---------------------------------------------------------------------------
// Onboarding — extended selectors for the 2-page flow
// ---------------------------------------------------------------------------
// Note: ONBOARDING already exists above. These are supplemental selectors for
// the onboarding smoke test that target specific page content.
// The base ONBOARDING object is already exported; we extend via ONBOARDING_FLOW.
export const ONBOARDING_FLOW = {
  /**
   * Page 1 welcome headline: "Track every rep,\nevery time".
   * _WelcomePage renders this as displayMedium Text.
   *
   * Flutter merges the entire _WelcomePage Column into a single semantics
   * button node, so the headline text appears only in the parent button's
   * aria-label — not as a standalone text element. The `text=` engine does
   * not match parent aria-labels when child nodes exist. Use `role=button`
   * with a `name` substring match instead.
   */
  welcomeHeadline: 'role=button[name*="Track every rep"]',
  /**
   * Page 2 indicator: the "Beginner" ChoiceChip is unique to the profile
   * setup page and has a reliable aria-label in the semantics tree.
   *
   * The "Set up your profile" headline text is rendered to canvas only —
   * it does NOT appear as an aria-label or text content in the DOM. Flutter
   * does not create a semantics node for non-interactive Text widgets on
   * this page. The ChoiceChips are the most reliable page 2 indicator.
   */
  profileSetupHeadline: 'role=checkbox[name="Beginner"]',
  /**
   * Display name AppTextField on page 2.
   *
   * Flutter merges the text field with surrounding non-interactive elements.
   * The flt-semantics node does NOT get an aria-label="Display name" — instead,
   * the hidden native <input> proxy gets a merged aria-label containing all page
   * text. We target the input via its data-semantics-role attribute since there
   * is only one text field on the profile setup page.
   */
  displayNameInput: 'input[data-semantics-role="text-field"]',
  /**
   * "3x" frequency ChoiceChip — the default selection.
   */
  frequency3x: 'role=checkbox[name="3x"]',
  /**
   * Back TextButton.icon on page 2.
   * TextButton label: Text('Back').
   */
  backButton: 'text=Back',
} as const;

// ---------------------------------------------------------------------------
// Routine management — additional selectors for create/edit/delete flow
// ---------------------------------------------------------------------------
export const ROUTINE_MANAGEMENT = {
  /**
   * + IconButton in the RoutineListScreen AppBar.
   * IconButton icon: Icons.add. Flutter exposes this as an icon button with
   * accessible name derived from the tooltip or semantics label.
   * We match on the role and the known AppBar position.
   */
  createIconButton: 'role=button[name="Create routine"]',
  /**
   * AppBar title on CreateRoutineScreen when creating a new routine.
   * AppBar title: Text('Create Routine').
   */
  createRoutineScreenTitle: 'role=heading[name="Create Routine"]',
  /**
   * AppBar title on CreateRoutineScreen when editing an existing routine.
   * AppBar title: Text('Edit Routine').
   */
  editRoutineScreenTitle: 'role=heading[name="Edit Routine"]',
} as const;

// ---------------------------------------------------------------------------
// PR display — Personal Records screen selectors
// ---------------------------------------------------------------------------
export const PR_DISPLAY = {
  /**
   * AppBar title of PRListScreen.
   * AppBar title: Text('Personal Records').
   */
  screenTitle: 'text=Personal Records',
  /**
   * Empty state title when no records exist.
   * _EmptyState renders headlineMedium Text('No Records Yet').
   */
  emptyStateTitle: 'text=No Records Yet',
  /**
   * Empty state container — use to check if the screen is in empty state.
   * Text('Complete a workout to start tracking records').
   */
  emptyState: 'text=Complete a workout to start tracking records',
  /**
   * "Max Weight" label in _RecordTile.
   * RecordType.maxWeight.displayName — typically "Max Weight".
   */
  maxWeightLabel: 'text=Max Weight',
  /**
   * Exercise record card — the Card wrapping each exercise's PR data.
   * _ExerciseRecordCard renders as an InkWell inside a Card. The tappable
   * area navigates to /exercises/<id>. We select all flt-semantics with
   * role=button inside the records screen — use .first() in tests.
   * This selector targets any button that has text content (exercise name).
   */
  exerciseRecordCard: 'flt-semantics[role="button"]',
} as const;

// ---------------------------------------------------------------------------
// Profile Weekly Goal — selectors for _WeeklyGoalRow and frequency sheet
// ---------------------------------------------------------------------------
export const PROFILE_WEEKLY_GOAL = {
  /**
   * "Weekly Goal" section label above the _WeeklyGoalRow.
   * ProfileScreen renders titleMedium Text('Weekly Goal').
   */
  sectionLabel: 'text=Weekly Goal',
  /**
   * The _WeeklyGoalRow InkWell — matches on the "{n}x per week" text pattern.
   * We target the container text because there's no Semantics label.
   */
  frequencyRow: 'role=button[name=/per week/]',
  /**
   * Frequency row with a specific value, e.g. "3x per week".
   * Returns a selector for the row showing the given frequency number.
   */
  frequencyRowWithValue: (freq: number) => `role=button[name="${freq}x per week"]`,
  /**
   * Description text in the frequency selection bottom sheet.
   * Unique to the sheet — the section label on the Profile page is different.
   * Using this as a proxy for "sheet is open" avoids ambiguity with sectionLabel.
   */
  sheetTitle: 'text=How many times per week do you want to train?',
  /**
   * How many times per week description in the sheet.
   */
  sheetDescription: 'text=How many times per week do you want to train?',
} as const;

// ---------------------------------------------------------------------------
// Home stat cards — _StatCardsRow in HomeScreen
// ---------------------------------------------------------------------------
export const HOME_STATS = {
  /** "Last session" contextual stat cell — Semantics label "Last session: {value}" */
  lastSessionCell: 'role=button[name*="Last session"]',
  /** "Week's volume" contextual stat cell — Semantics label "Week's volume: {value}" */
  weekVolumeCell: 'role=button[name*="Week\'s volume"]',
} as const;
