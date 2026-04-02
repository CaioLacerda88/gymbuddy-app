/**
 * Centralized selectors for GymBuddy Flutter web (HTML renderer).
 *
 * Flutter web with --web-renderer html renders real DOM elements, so standard
 * Playwright selectors work. Flutter also emits ARIA attributes from Semantics
 * widgets, which we use where available.
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
  /** Inline error message container */
  errorMessage: 'flt-semantics[role="alert"]',
} as const;

// ---------------------------------------------------------------------------
// Onboarding — OnboardingScreen (3-page flow after first sign-up)
// ---------------------------------------------------------------------------
export const ONBOARDING = {
  /** Page 1 CTA */
  getStartedButton: 'text=GET STARTED',
  /** Page 2 CTA */
  nextButton: 'text=NEXT',
  /** Display name input on page 2 */
  displayNameInput: '[aria-label="Display name"]',
  /** Page 3 CTA (enabled only when a choice is selected) */
  letsGoButton: "text=LET'S GO",
  /** Workout choice card titles */
  fullBodyOption: 'text=Full Body Starter',
  startBlankOption: 'text=Start Blank',
  browseExercisesOption: 'text=Browse Exercises',
} as const;

// ---------------------------------------------------------------------------
// Shell / Bottom Navigation
// NavigationDestination labels are used as aria-label by Flutter's semantics
// ---------------------------------------------------------------------------
export const NAV = {
  homeTab: 'flt-semantics[aria-label="Home"]',
  exercisesTab: 'flt-semantics[aria-label="Exercises"]',
  historyTab: 'flt-semantics[aria-label="History"]',
  profileTab: 'flt-semantics[aria-label="Profile"]',
} as const;

// ---------------------------------------------------------------------------
// Exercise list — ExerciseListScreen
// ---------------------------------------------------------------------------
export const EXERCISE_LIST = {
  /** Page heading */
  heading: 'text=Exercises',
  /** Search field — Semantics label "Search exercises" */
  searchInput: '[aria-label="Search exercises"]',
  /** "All" muscle group filter button */
  allMuscleGroupFilter: '[aria-label="All muscle group filter"]',
  /** Muscle group filter buttons — pass the MuscleGroup.displayName, e.g. "Chest" */
  muscleGroupFilter: (name: string) =>
    `[aria-label="${name} muscle group filter"]`,
  /** Equipment FilterChip — pass EquipmentType.displayName, e.g. "Barbell" */
  equipmentFilter: (name: string) =>
    `[aria-label="${name} equipment filter"]`,
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
// No Semantics labels in that file were read; these are text-based fallbacks.
// ---------------------------------------------------------------------------
export const CREATE_EXERCISE = {
  nameInput: '[aria-label="Exercise name"]',
  saveButton: 'text=SAVE',
} as const;
