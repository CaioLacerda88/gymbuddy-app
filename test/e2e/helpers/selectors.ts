/**
 * Centralized selectors for GymBuddy Flutter web.
 *
 * Flutter web emits flt-semantics elements with ARIA attributes from Semantics
 * widgets. Standard Playwright selectors target these accessibility nodes.
 *
 * Where Semantics labels exist in the Dart code they are noted below.
 * Where no Semantics label was added, we fall back to visible text content.
 *
 * Semantics labels found in the source:
 *   - _MuscleGroupButton:  '[aria-label="<name> muscle group filter"]'
 *   - _SearchBar:          '[aria-label="Search exercises"]'
 *   - _EquipmentFilter:    '[aria-label="<name> equipment filter"]'
 *   - _ExerciseCard:       '[aria-label="Exercise: <name>"]'
 *   - _CreateExerciseFab:  '[aria-label="Create new exercise"]'
 *   - _TappableImage:      '[aria-label="<name> start position"]' / "end position"
 *   - Delete button:       '[aria-label="Delete exercise"]'
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
  /** AppButton label "LOG IN" */
  loginButton: 'flt-semantics[aria-label="LOG IN"]',
  /** AppButton label "SIGN UP" */
  signUpButton: 'flt-semantics[aria-label="SIGN UP"]',
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
// NavigationDestination labels are used as aria-label by Flutter's semantics.
// Tabs: Home, Exercises, Routines, Profile.
// ---------------------------------------------------------------------------
export const NAV = {
  homeTab: 'flt-semantics[aria-label="Home"]',
  exercisesTab: 'flt-semantics[aria-label="Exercises"]',
  routinesTab: 'flt-semantics[aria-label="Routines"]',
  profileTab: 'flt-semantics[aria-label="Profile"]',
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
  /** Confirmation dialog title */
  deleteDialogTitle: 'text=Delete Exercise',
  /** Confirm delete action in dialog — exact match to avoid "Delete Exercise" collision */
  deleteConfirmButton: 'text="Delete"',
  /** Cancel delete action in dialog */
  deleteCancelButton: 'text=Cancel',
  /** Coming-soon placeholder text */
  prPlaceholder: 'text=Personal records & workout history coming soon',
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
  markSetDone: 'flt-semantics[aria-label="Mark set as done"]',
  /** Checkbox to mark a set as done — checked state */
  setCompleted: 'flt-semantics[aria-label="Set completed"]',
  /** "Discard" button in the discard confirmation dialog */
  discardButton: 'text=Discard',
  /** "Keep Going" button in the finish confirmation dialog (cancels finish) */
  keepGoingButton: 'text=Keep Going',
  /** Tappable weight value that opens the weight entry dialog */
  enterWeightDialog: 'text=Enter weight',
  /** Tappable reps value that opens the reps entry dialog */
  enterRepsDialog: 'text=Enter reps',
  /** Optional notes input on the active workout screen */
  notesInput: 'flt-semantics[aria-label="Workout notes"]',
  /**
   * Exercise name tappable area inside an exercise card during an active workout.
   *
   * _ExerciseCard wraps the exercise name in a Semantics with the label:
   *   "Exercise: <name>. Tap for details. Long press to swap."
   * We match on the "Tap for details" substring to target the tappable region
   * regardless of exercise name.
   */
  exerciseDetailTap: (name: string) =>
    `flt-semantics[aria-label*="Exercise: ${name}. Tap for details"]`,
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
   * renders the auto-generated workout name which always starts with
   * "Workout \u2014" (em-dash). Matching on this prefix is reliable because
   * no other text on the home screen contains an em-dash.
   */
  activeBanner: 'flt-semantics[aria-label*="Workout \u2014"]',
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
  /** Page heading */
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
  /** Name text field — hintText "Routine name" */
  nameInput: 'input',
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
  heading: 'text=History',
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
  /** Page heading */
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
  resetButton: 'text=Reset Account',
  /**
   * Close / cancel icon button in the Reset Account full-screen dialog.
   * The IconButton has tooltip: 'Cancel'.
   */
  resetCancelButton: 'flt-semantics[aria-label="Cancel"]',
  /** SnackBar confirmation after successful history deletion */
  historyCleared: 'text=Workout history cleared',
  /** SnackBar confirmation after successful reset */
  accountReset: 'text=Account data reset',
} as const;

// ---------------------------------------------------------------------------
// Home stat cards — _StatCardsRow in HomeScreen
// ---------------------------------------------------------------------------
export const HOME_STATS = {
  /**
   * Workouts stat card — Semantics label pattern:
   *   "$count Workouts, tap to view workouts"  (when data loaded)
   *   "Workouts loading"                        (while loading)
   * We match on the substring "tap to view workouts" to target the data state.
   */
  workoutsCard: 'flt-semantics[aria-label*="tap to view workouts"]',
  /**
   * Records stat card — Semantics label pattern:
   *   "$count Records, tap to view records"
   */
  recordsCard: 'flt-semantics[aria-label*="tap to view records"]',
} as const;
