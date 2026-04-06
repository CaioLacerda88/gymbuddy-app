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
  /** Search field — partial match because Flutter concatenates label + hint */
  searchInput: '[aria-label*="Search exercises"]',
  /** "All" muscle group filter — partial match (Flutter concatenates label + text) */
  allMuscleGroupFilter: '[aria-label*="All muscle group filter"]',
  /** Muscle group filter buttons — partial match for combined label */
  muscleGroupFilter: (name: string) =>
    `[aria-label*="${name} muscle group filter"]`,
  /** Equipment FilterChip — partial match for combined label */
  equipmentFilter: (name: string) =>
    `[aria-label*="${name} equipment filter"]`,
  /** Individual exercise card — Semantics label "Exercise: <name>" */
  exerciseCard: (name: string) => `[aria-label="Exercise: ${name}"]`,
  /** FAB — Semantics label "Create new exercise" */
  createFab: '[aria-label="Create new exercise"]',
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
  /** Delete button — Semantics label "Delete exercise" */
  deleteButton: '[aria-label="Delete exercise"]',
  /** Confirmation dialog title */
  deleteDialogTitle: 'text=Delete Exercise',
  /** Confirm delete action in dialog */
  deleteConfirmButton: 'text=Delete',
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
  nameInput: '[aria-label="Exercise Name"]',
  /** Case-sensitive exact match avoids collision with heading "Create Exercise" */
  saveButton: 'text="CREATE EXERCISE"',
} as const;

// ---------------------------------------------------------------------------
// Active workout — ActiveWorkoutScreen
// ---------------------------------------------------------------------------
export const WORKOUT = {
  /** "Start Empty Workout" button on the Home screen launchpad */
  startEmpty: 'text=Start Empty Workout',
  /** "Finish Workout" button in the persistent bottom bar and in the dialog */
  finishButton: 'text=Finish Workout',
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
} as const;

// ---------------------------------------------------------------------------
// Exercise picker — bottom sheet shown when adding exercises to a workout
// ---------------------------------------------------------------------------
export const EXERCISE_PICKER = {
  /** Search field — partial match because Flutter concatenates label + hint */
  searchInput: '[aria-label*="Search exercises to add"]',
  /** "Add <name>" tile for a specific exercise */
  addExerciseButton: (name: string) =>
    `flt-semantics[aria-label="Add ${name}"]`,
} as const;

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------
export const HOME = {
  /** "RECENT" section heading on the home screen */
  recentSection: 'text=RECENT',
  /** "View All" link to the full workout history */
  viewAllHistory: 'text=View All',
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
  /** "Delete" confirm button in delete dialog */
  deleteConfirmButton: 'text=Delete',
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
} as const;
