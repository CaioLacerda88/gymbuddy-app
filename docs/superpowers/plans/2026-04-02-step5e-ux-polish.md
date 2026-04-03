# Step 5e: UX Polish Sprint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the core logging loop, onboarding, and navigation before Step 6 (Templates) ships — fixing the 6 critical and 6 important usability issues identified by the Product Owner + UI/UX Critic audit.

**Architecture:** Surgical edits to existing widgets and screens. One new feature directory (`profile/`) with model, repository, provider, and screen. No new dependencies. All changes follow existing Riverpod + Freezed + GoRouter patterns.

**Tech Stack:** Flutter, Riverpod, Freezed, GoRouter, Supabase, Hive

**Key patterns to follow:**
- Providers in `features/{name}/providers/` — repositories as Provider, notifiers as AsyncNotifierProvider
- Models in `features/{name}/models/` — Freezed with `@JsonSerializable(fieldRename: FieldRename.snake)`
- Repositories extend `BaseRepository` from `core/data/base_repository.dart`
- Widget tests use `ProviderScope(overrides: [...])` + `tester.pumpWidget(MaterialApp(...))`
- Unit tests use `ProviderContainer(overrides: [...])` with mocktail mocks
- Run `export PATH="/c/flutter/bin:$PATH"` before any Flutter/Dart commands

---

## File Map

### New Files
- `lib/features/profile/models/profile.dart` — Freezed Profile model
- `lib/features/profile/models/profile.freezed.dart` — generated
- `lib/features/profile/models/profile.g.dart` — generated
- `lib/features/profile/data/profile_repository.dart` — Supabase CRUD for profiles table
- `lib/features/profile/providers/profile_providers.dart` — profileRepository + profileNotifier providers
- `lib/features/profile/ui/profile_screen.dart` — minimal profile screen (name, email, weight unit, logout)
- `test/unit/features/profile/data/profile_repository_test.dart`
- `test/widget/features/profile/ui/profile_screen_test.dart`

### Modified Files
- `lib/features/auth/ui/onboarding_screen.dart` — remove page 3, wire profile save on page 2
- `lib/features/workouts/ui/home_screen.dart` — remove name dialog, auto-name workout
- `lib/features/workouts/providers/notifiers/active_workout_notifier.dart` — auto-name in startWorkout
- `lib/features/workouts/ui/active_workout_screen.dart` — inline rename AppBar, move Finish to bottom, bigger Add Set button
- `lib/features/workouts/ui/widgets/set_row.dart` — remove RPE column, enlarge numbers
- `lib/shared/widgets/weight_stepper.dart` — larger number display, tap-to-type
- `lib/shared/widgets/reps_stepper.dart` — larger number display, tap-to-type
- `lib/features/workouts/ui/widgets/exercise_picker_sheet.dart` — add "Create Exercise" action
- `lib/features/workouts/ui/widgets/rest_timer_overlay.dart` — add +30s/-30s buttons
- `lib/core/router/app_router.dart` — replace Profile placeholder, increase banner visibility
- `lib/features/workouts/ui/workout_history_screen.dart` — add exercise names to cards
- `lib/features/workouts/models/workout.dart` — (verify exerciseNames field or query approach)
- `test/widget/features/auth/ui/onboarding_screen_test.dart` — update for 2-page flow
- `test/widget/features/workouts/ui/widgets/set_row_test.dart` — update for no RPE
- `test/widget/shared/widgets/weight_stepper_test.dart` — update for tap-to-type
- `test/widget/shared/widgets/reps_stepper_test.dart` — update for tap-to-type

---

## Task 1: Profile Model & Repository

**Files:**
- Create: `lib/features/profile/models/profile.dart`
- Create: `lib/features/profile/data/profile_repository.dart`
- Create: `lib/features/profile/providers/profile_providers.dart`
- Create: `test/unit/features/profile/data/profile_repository_test.dart`

This is a dependency for Tasks 2 (profile screen) and 3 (onboarding wire-up).

- [ ] **Step 1: Create Profile model**

```dart
// lib/features/profile/models/profile.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'fitness_level') String? fitnessLevel,
    @JsonKey(name: 'weight_unit') @Default('kg') String weightUnit,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
```

- [ ] **Step 2: Create ProfileRepository**

```dart
// lib/features/profile/data/profile_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/base_repository.dart';
import '../models/profile.dart';

class ProfileRepository extends BaseRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> getProfile(String userId) async {
    return handleErrors(() async {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromJson(data);
    });
  }

  Future<Profile> upsertProfile({
    required String userId,
    String? displayName,
    String? fitnessLevel,
    String? weightUnit,
  }) async {
    return handleErrors(() async {
      final data = await _client.from('profiles').upsert({
        'id': userId,
        if (displayName != null) 'display_name': displayName,
        if (fitnessLevel != null) 'fitness_level': fitnessLevel,
        if (weightUnit != null) 'weight_unit': weightUnit,
      }).select().single();
      return Profile.fromJson(data);
    });
  }

  Future<void> updateWeightUnit(String userId, String unit) async {
    return handleErrors(() async {
      await _client
          .from('profiles')
          .update({'weight_unit': unit})
          .eq('id', userId);
    });
  }
}
```

- [ ] **Step 3: Create profile providers**

```dart
// lib/features/profile/providers/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_repository.dart';
import '../models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final repo = ref.read(profileRepositoryProvider);
    return repo.getProfile(user.id);
  }

  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final repo = ref.read(profileRepositoryProvider);
    state = AsyncData(await repo.upsertProfile(
      userId: user.id,
      displayName: displayName,
      fitnessLevel: fitnessLevel,
    ));
  }

  Future<void> toggleWeightUnit() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final newUnit = current.weightUnit == 'kg' ? 'lbs' : 'kg';
    final repo = ref.read(profileRepositoryProvider);
    await repo.updateWeightUnit(user.id, newUnit);
    state = AsyncData(current.copyWith(weightUnit: newUnit));
  }
}
```

- [ ] **Step 4: Run code generation**

```bash
export PATH="/c/flutter/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `profile.freezed.dart` and `profile.g.dart`

- [ ] **Step 5: Write unit tests for ProfileRepository**

```dart
// test/unit/features/profile/data/profile_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/profile/models/profile.dart';

void main() {
  group('Profile model', () {
    test('fromJson creates Profile correctly', () {
      final json = {
        'id': 'user-123',
        'display_name': 'John',
        'fitness_level': 'intermediate',
        'weight_unit': 'kg',
        'created_at': '2026-01-01T00:00:00Z',
      };
      final profile = Profile.fromJson(json);
      expect(profile.id, 'user-123');
      expect(profile.displayName, 'John');
      expect(profile.fitnessLevel, 'intermediate');
      expect(profile.weightUnit, 'kg');
    });

    test('toJson produces correct map', () {
      const profile = Profile(
        id: 'user-123',
        displayName: 'John',
        fitnessLevel: 'beginner',
        weightUnit: 'lbs',
      );
      final json = profile.toJson();
      expect(json['id'], 'user-123');
      expect(json['display_name'], 'John');
      expect(json['fitness_level'], 'beginner');
      expect(json['weight_unit'], 'lbs');
    });

    test('defaults weightUnit to kg', () {
      final profile = Profile.fromJson({
        'id': 'user-123',
      });
      expect(profile.weightUnit, 'kg');
    });

    test('copyWith produces new instance', () {
      const profile = Profile(id: 'user-123', weightUnit: 'kg');
      final updated = profile.copyWith(weightUnit: 'lbs');
      expect(updated.weightUnit, 'lbs');
      expect(profile.weightUnit, 'kg');
    });
  });
}
```

- [ ] **Step 6: Run tests**

```bash
export PATH="/c/flutter/bin:$PATH"
flutter test test/unit/features/profile/
```

Expected: all tests pass

- [ ] **Step 7: Commit**

```bash
git add lib/features/profile/ test/unit/features/profile/
git commit -m "feat(profile): add Profile model, repository, and providers"
```

---

## Task 2: Minimal Profile Screen

**Files:**
- Create: `lib/features/profile/ui/profile_screen.dart`
- Modify: `lib/core/router/app_router.dart` — replace _TabPlaceholder with ProfileScreen
- Create: `test/widget/features/profile/ui/profile_screen_test.dart`

**Depends on:** Task 1 (Profile model & providers)

- [ ] **Step 1: Create ProfileScreen**

```dart
// lib/features/profile/ui/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User identity card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.15),
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            profileAsync.when(
                              data: (profile) => Text(
                                profile?.displayName ?? 'Gym User',
                                style: theme.textTheme.titleLarge,
                              ),
                              loading: () => Text(
                                'Loading...',
                                style: theme.textTheme.titleLarge,
                              ),
                              error: (_, __) => Text(
                                'Gym User',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            if (user?.email != null)
                              Text(
                                user!.email!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Weight unit toggle
              Text('Preferences',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: profileAsync.when(
                  data: (profile) => ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: const Text('Weight Unit'),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('kg')),
                        ButtonSegment(value: 'lbs', label: Text('lbs')),
                      ],
                      selected: {profile?.weightUnit ?? 'kg'},
                      onSelectionChanged: (value) {
                        ref
                            .read(profileProvider.notifier)
                            .toggleWeightUnit();
                      },
                    ),
                  ),
                  loading: () => const ListTile(
                    leading: Icon(Icons.fitness_center),
                    title: Text('Weight Unit'),
                    trailing: CircularProgressIndicator(),
                  ),
                  error: (_, __) => const ListTile(
                    leading: Icon(Icons.fitness_center),
                    title: Text('Weight Unit'),
                    subtitle: Text('Could not load preferences'),
                  ),
                ),
              ),
              const Spacer(),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Log Out?'),
                        content: const Text(
                            'You can log back in anytime.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Log Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      ref.read(authRepositoryProvider).signOut();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire ProfileScreen into router**

In `lib/core/router/app_router.dart`, replace the profile route and remove `_TabPlaceholder`:

Replace:
```dart
GoRoute(
  path: '/profile',
  builder: (context, state) =>
      const _TabPlaceholder(title: 'Profile'),
),
```

With:
```dart
GoRoute(
  path: '/profile',
  builder: (context, state) =>
      const ProfileScreen(),
),
```

Add import at top of file:
```dart
import '../../features/profile/ui/profile_screen.dart';
```

Remove the `_TabPlaceholder` class entirely (lines 242-253).

- [ ] **Step 3: Write widget test for ProfileScreen**

```dart
// test/widget/features/profile/ui/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/profile/models/profile.dart';
import 'package:gymbuddy/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy/features/profile/ui/profile_screen.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('shows display name from profile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier(
              const Profile(
                id: 'user-1',
                displayName: 'John Doe',
                weightUnit: 'kg',
              ),
            )),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('shows weight unit segmented button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier(
              const Profile(id: 'user-1', weightUnit: 'kg'),
            )),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('lbs'), findsOneWidget);
    });

    testWidgets('shows logout button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier(
              const Profile(id: 'user-1'),
            )),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('shows fallback name when displayName is null',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier(
              const Profile(id: 'user-1'),
            )),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gym User'), findsOneWidget);
    });
  });
}

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  _FakeProfileNotifier(this._profile);
  final Profile? _profile;

  @override
  Future<Profile?> build() async => _profile;

  @override
  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
  }) async {}

  @override
  Future<void> toggleWeightUnit() async {}
}
```

- [ ] **Step 4: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/profile/ test/widget/features/profile/ lib/core/router/app_router.dart
dart analyze --fatal-infos lib/features/profile/ lib/core/router/app_router.dart
flutter test test/widget/features/profile/
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/ui/ lib/core/router/app_router.dart test/widget/features/profile/
git commit -m "feat(profile): add minimal profile screen with weight unit toggle and logout"
```

---

## Task 3: Trim Onboarding & Wire Profile Save

**Files:**
- Modify: `lib/features/auth/ui/onboarding_screen.dart`
- Modify: `test/widget/features/auth/ui/onboarding_screen_test.dart`

**Depends on:** Task 1 (profile providers)

- [ ] **Step 1: Remove page 3 and wire profile save**

In `lib/features/auth/ui/onboarding_screen.dart`:

1. Add import for profile providers:
```dart
import '../../profile/providers/profile_providers.dart';
```

2. Remove `_workoutChoice` state variable entirely.

3. Change `_totalPages` from 3 to 2.

4. In `_finishOnboarding()` (around line 43), replace the TODO comment with actual profile save:
```dart
Future<void> _finishOnboarding() async {
  await ref.read(profileProvider.notifier).saveOnboardingProfile(
    displayName: _nameController.text.trim(),
    fitnessLevel: _fitnessLevel,
  );
  ref.read(needsOnboardingProvider.notifier).state = false;
}
```

5. In the page 2 (`_ProfileSetupPage`) NEXT button's onPressed, change it to call `_finishOnboarding()` instead of advancing to page 3. The button text should change from "NEXT" to "LET'S GO".

6. Remove the entire `_WorkoutChoicePage` widget class and its usage in the PageView children list.

7. Update the page indicator dots to only show 2 dots.

- [ ] **Step 2: Update onboarding widget tests**

In `test/widget/features/auth/ui/onboarding_screen_test.dart`:

- Remove any tests that reference page 3 or workout choice
- Update tests that check total page count to expect 2
- Add a test that verifies profile save is called on completion:
  - Mock the profileProvider notifier
  - Fill in name and fitness level on page 2
  - Tap "LET'S GO"
  - Verify `saveOnboardingProfile` was called with correct args

- [ ] **Step 3: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/auth/ui/onboarding_screen.dart test/widget/features/auth/ui/onboarding_screen_test.dart
dart analyze --fatal-infos lib/features/auth/ui/onboarding_screen.dart
flutter test test/widget/features/auth/ui/onboarding_screen_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/ui/onboarding_screen.dart test/widget/features/auth/ui/onboarding_screen_test.dart
git commit -m "fix(auth): trim onboarding to 2 pages and wire profile save to Supabase"
```

---

## Task 4: Remove Start Workout Dialog & Auto-Name

**Files:**
- Modify: `lib/features/workouts/ui/home_screen.dart`
- Modify: `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`

- [ ] **Step 1: Update startWorkout to auto-generate name**

In `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`, change `startWorkout` signature:

Replace:
```dart
Future<void> startWorkout(String name) async {
```

With:
```dart
Future<void> startWorkout([String? name]) async {
```

Inside the method, generate a default name if none provided:
```dart
final workoutName = name ?? _generateWorkoutName();
```

Add helper method to the class:
```dart
String _generateWorkoutName() {
  final now = DateTime.now();
  final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1];
  final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1];
  return 'Workout — $weekday $month ${now.day}';
}
```

Then use `workoutName` instead of `name` in the `_repo.createActiveWorkout(userId, workoutName)` call.

- [ ] **Step 2: Simplify HomeScreen to skip dialog**

In `lib/features/workouts/ui/home_screen.dart`, replace `_showStartDialog()` with direct workout start:

Replace the `_StartWorkoutButton` onPressed logic. Instead of showing an AlertDialog, just start the workout directly:

```dart
onPressed: () async {
  await ref.read(activeWorkoutProvider.notifier).startWorkout();
  if (context.mounted) {
    context.go('/workout/active');
  }
},
```

Remove the entire `_showStartDialog` method.

- [ ] **Step 3: Add inline rename to active workout AppBar**

In `lib/features/workouts/ui/active_workout_screen.dart`, make the workout name in the AppBar tappable to edit:

Replace the static `Text(state.workout.name)` title with a `GestureDetector` that shows an inline `TextField` on tap. Use a `_isEditingName` boolean state:

```dart
// In _ActiveWorkoutBodyState:
bool _isEditingName = false;
late TextEditingController _nameController;

@override
void initState() {
  super.initState();
  _nameController = TextEditingController();
}

@override
void dispose() {
  _nameController.dispose();
  super.dispose();
}
```

In the AppBar title area, when `_isEditingName` is false, show the name as a tappable row with a small edit icon hint. When tapped, switch to a compact `TextField`. On submit or focus loss, save the name via `ref.read(activeWorkoutProvider.notifier).renameWorkout(newName)` and set `_isEditingName = false`.

Note: You'll need to add a `renameWorkout(String name)` method to `ActiveWorkoutNotifier`:
```dart
void renameWorkout(String name) {
  final current = state.valueOrNull;
  if (current == null) return;
  state = AsyncData(current.copyWith(
    workout: current.workout.copyWith(name: name),
  ));
  _saveToHive();
}
```

- [ ] **Step 4: Update existing tests**

In `test/unit/features/workouts/providers/active_workout_notifier_test.dart`:
- Update any tests that call `startWorkout('name')` — they should still pass since the param is now optional
- Add a test for auto-naming: call `startWorkout()` with no args and verify the workout name matches the expected date format
- Add a test for `renameWorkout()`

- [ ] **Step 5: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/home_screen.dart lib/features/workouts/ui/active_workout_screen.dart lib/features/workouts/providers/notifiers/active_workout_notifier.dart
dart analyze --fatal-infos lib/features/workouts/
flutter test test/unit/features/workouts/ test/widget/features/workouts/
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/
git commit -m "fix(workouts): remove start workout dialog and auto-name workouts by date"
```

---

## Task 5: Set Row Redesign — Hero Numbers & Remove RPE

**Files:**
- Modify: `lib/features/workouts/ui/widgets/set_row.dart`
- Modify: `lib/shared/widgets/weight_stepper.dart`
- Modify: `lib/shared/widgets/reps_stepper.dart`
- Modify: `lib/features/workouts/ui/active_workout_screen.dart` — `_SetColumnHeaders`
- Modify: `test/widget/features/workouts/ui/widgets/set_row_test.dart`
- Modify: `test/widget/shared/widgets/weight_stepper_test.dart`
- Modify: `test/widget/shared/widgets/reps_stepper_test.dart`

This is the largest single task. The set row is the most-used UI element in the app.

- [ ] **Step 1: Enlarge WeightStepper number display and add tap-to-type**

In `lib/shared/widgets/weight_stepper.dart`:

1. Change the center display from `titleMedium` (16sp) to `headlineMedium` (28sp, w700) with primary color tint:
```dart
// Replace the center Text widget
GestureDetector(
  onTap: _showNumberInput,
  child: SizedBox(
    width: 72,
    child: Text(
      _formatValue(value),
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.primary,
        shadows: [
          Shadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
    ),
  ),
),
```

2. Add `_showNumberInput()` method that shows a compact dialog with a `TextField` for direct number entry:
```dart
void _showNumberInput() {
  final controller = TextEditingController(text: _formatValue(widget.value));
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enter Weight'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: const InputDecoration(suffixText: 'kg'),
        onSubmitted: (val) {
          final parsed = double.tryParse(val);
          if (parsed != null && parsed >= 0) {
            widget.onChanged(parsed);
          }
          Navigator.pop(context);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final parsed = double.tryParse(controller.text);
            if (parsed != null && parsed >= 0) {
              widget.onChanged(parsed);
            }
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

3. Widen the center `SizedBox` from `width: 64` to `width: 72` to accommodate larger text.

- [ ] **Step 2: Enlarge RepsStepper number display and add tap-to-type**

In `lib/shared/widgets/reps_stepper.dart`:

Apply the same pattern as WeightStepper:
1. Change center display from `titleMedium` to `headlineSmall` with primary color + glow shadow
2. Add `_showNumberInput()` for direct integer entry (no decimal)
3. Widen center `SizedBox` from `width: 48` to `width: 56`

The number input dialog for reps should use `TextInputType.number` (no decimal option) and parse with `int.tryParse`.

- [ ] **Step 3: Remove RPE column from SetRow**

In `lib/features/workouts/ui/widgets/set_row.dart`:

1. Remove the `_RpeIndicator` widget usage from the row's children (around line 171-175)
2. Keep the `_RpeIndicator` class in the file for now — it can be re-enabled later via settings
3. The row layout becomes: set badge (48dp) | weight stepper (Expanded) | reps stepper (Expanded) | checkbox (48dp)
4. Wrap both steppers in `Expanded` to share remaining space equally

- [ ] **Step 4: Update _SetColumnHeaders**

In `lib/features/workouts/ui/active_workout_screen.dart`, in the `_SetColumnHeaders` widget:

Remove the RPE column header. Update layout to match new 4-column set row:
```dart
Row(
  children: [
    const SizedBox(width: 48, child: Text('SET', textAlign: TextAlign.center, ...)),
    Expanded(child: Text('WEIGHT', textAlign: TextAlign.center, ...)),
    Expanded(child: Text('REPS', textAlign: TextAlign.center, ...)),
    const SizedBox(width: 48), // checkbox column
  ],
)
```

- [ ] **Step 5: Update set_row_test.dart**

In `test/widget/features/workouts/ui/widgets/set_row_test.dart`:
- Remove any tests that look for RPE indicator or RPE popup menu
- Verify the row renders with weight, reps, set badge, and checkbox
- Add test: tap on weight number opens input dialog

- [ ] **Step 6: Update stepper tests**

In `test/widget/shared/widgets/weight_stepper_test.dart`:
- Add test: tap on center number opens number input dialog
- Add test: entering a value in dialog calls onChanged with that value
- Update any tests that check for `titleMedium` text style

In `test/widget/shared/widgets/reps_stepper_test.dart`:
- Same changes as weight stepper tests

- [ ] **Step 7: Run all tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/widgets/set_row.dart lib/shared/widgets/weight_stepper.dart lib/shared/widgets/reps_stepper.dart lib/features/workouts/ui/active_workout_screen.dart
dart format test/widget/features/workouts/ui/widgets/set_row_test.dart test/widget/shared/widgets/weight_stepper_test.dart test/widget/shared/widgets/reps_stepper_test.dart
dart analyze --fatal-infos
flutter test
```

- [ ] **Step 8: Commit**

```bash
git add lib/features/workouts/ui/widgets/set_row.dart lib/shared/widgets/weight_stepper.dart lib/shared/widgets/reps_stepper.dart lib/features/workouts/ui/active_workout_screen.dart test/widget/features/workouts/ui/widgets/ test/widget/shared/widgets/
git commit -m "feat(workouts): redesign set row with hero numbers, tap-to-type, and hidden RPE"
```

---

## Task 6: Move Finish Button to Bottom & Bigger Add Set

**Files:**
- Modify: `lib/features/workouts/ui/active_workout_screen.dart`

- [ ] **Step 1: Move Finish button to persistent bottom bar**

In `lib/features/workouts/ui/active_workout_screen.dart`:

1. Remove the "Finish" `FilledButton` from AppBar `actions` list.

2. Add a `bottomNavigationBar` to the Scaffold with a persistent finish bar:
```dart
bottomNavigationBar: SafeArea(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: FilledButton.icon(
      onPressed: hasCompletedSets ? () => _showFinishDialog(context, ref, state) : null,
      icon: const Icon(Icons.check_circle),
      label: const Text('Finish Workout'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  ),
),
```

The `hasCompletedSets` check is the same condition already used for the old Finish button: at least 1 completed set across all exercises.

3. Keep the AppBar clean — only the close/discard icon on the left and the reorder toggle on the right.

- [ ] **Step 2: Make Add Set button full-width and prominent**

In the same file, in `_ExerciseCard`, replace the `TextButton.icon` "Add Set" with:
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  child: OutlinedButton.icon(
    onPressed: () => ref.read(activeWorkoutProvider.notifier).addSet(workoutExercise.id),
    icon: const Icon(Icons.add, size: 20),
    label: const Text('Add Set'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
    ),
  ),
),
```

- [ ] **Step 3: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/active_workout_screen.dart
dart analyze --fatal-infos lib/features/workouts/ui/active_workout_screen.dart
flutter test test/widget/features/workouts/
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/workouts/ui/active_workout_screen.dart
git commit -m "fix(workouts): move Finish to bottom bar and make Add Set full-width"
```

---

## Task 7: Previous Session Data in Set Rows

**Files:**
- Modify: `lib/features/workouts/ui/widgets/set_row.dart`
- Modify: `lib/features/workouts/ui/active_workout_screen.dart`
- Modify: `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`

- [ ] **Step 1: Pass last-session data to SetRow**

The `lastWorkoutSetsProvider` already exists and returns `Map<String, List<ExerciseSet>>` keyed by exercise ID. In `_ExerciseCard`, read the last workout sets for the current exercise and pass them to each `SetRow`:

In `active_workout_screen.dart`, inside `_ExerciseCard.build`:
```dart
final lastSets = ref.watch(lastWorkoutSetsProvider(exerciseId));
```

Pass the relevant last set to each `SetRow`:
```dart
SetRow(
  set: set,
  workoutExerciseId: workoutExercise.id,
  onCompleted: () { ... },
  lastSet: lastSets != null && setIndex < lastSets.length
      ? lastSets[setIndex]
      : null,
),
```

- [ ] **Step 2: Display ghost data in SetRow**

In `lib/features/workouts/ui/widgets/set_row.dart`, add an optional `lastSet` parameter:
```dart
final ExerciseSet? lastSet;
```

Below the main set row, if `lastSet != null` and the current set is not completed, show a hint row:
```dart
if (lastSet != null && !set.isCompleted)
  Padding(
    padding: const EdgeInsets.only(left: 48, bottom: 4),
    child: Text(
      'Last: ${lastSet!.weight ?? 0}kg x ${lastSet!.reps ?? 0}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    ),
  ),
```

- [ ] **Step 3: Pre-fill new sets from last session**

In `active_workout_notifier.dart`, modify `addSet()` to accept optional default values and pre-fill from last session data when the provider has it:

The caller in `_ExerciseCard` should pass last session weight/reps when adding a set:
```dart
ref.read(activeWorkoutProvider.notifier).addSet(
  workoutExercise.id,
  defaultWeight: lastSets?[currentSetCount]?.weight,
  defaultReps: lastSets?[currentSetCount]?.reps,
);
```

Update `addSet` signature:
```dart
void addSet(String workoutExerciseId, {double? defaultWeight, int? defaultReps}) {
```

Use `defaultWeight ?? 0` and `defaultReps ?? 0` instead of hardcoded 0.

- [ ] **Step 4: Run tests**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/widgets/set_row.dart lib/features/workouts/ui/active_workout_screen.dart lib/features/workouts/providers/notifiers/active_workout_notifier.dart
dart analyze --fatal-infos lib/features/workouts/
flutter test test/unit/features/workouts/ test/widget/features/workouts/
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/workouts/
git commit -m "feat(workouts): show previous session data and pre-fill sets from last workout"
```

---

## Task 8: Create Exercise From Picker

**Files:**
- Modify: `lib/features/workouts/ui/widgets/exercise_picker_sheet.dart`

- [ ] **Step 1: Add Create Exercise button to empty state and list bottom**

In `lib/features/workouts/ui/widgets/exercise_picker_sheet.dart`:

1. In the empty state (around line 150), replace the plain "No exercises found" with:
```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.search_off,
        size: 48,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
    const SizedBox(height: 16),
    Text('No exercises found',
        style: theme.textTheme.bodyLarge),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: () => _navigateToCreateExercise(context, searchQuery),
      icon: const Icon(Icons.add),
      label: Text(
        searchQuery.isNotEmpty
            ? 'Create "$searchQuery"'
            : 'Create Exercise',
      ),
    ),
  ],
)
```

2. Add the navigation helper method:
```dart
Future<void> _navigateToCreateExercise(BuildContext context, String query) async {
  // Close the picker sheet first
  Navigator.pop(context);
  // Navigate to create exercise screen
  // The create exercise screen is at the exercises tab
  context.go('/exercises'); // Will need to deep-link to create
}
```

Note: Ideally this should push the CreateExerciseScreen directly as a modal. Check if `CreateExerciseScreen` can be shown as a bottom sheet or pushed route from within the picker. If the create screen is a full route (`/exercises/create`), navigate there. The agent implementing this should check the existing create exercise flow and adapt.

- [ ] **Step 2: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/widgets/exercise_picker_sheet.dart
dart analyze --fatal-infos lib/features/workouts/ui/widgets/exercise_picker_sheet.dart
flutter test test/widget/features/workouts/
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/workouts/ui/widgets/exercise_picker_sheet.dart
git commit -m "feat(workouts): add Create Exercise shortcut to exercise picker empty state"
```

---

## Task 9: Rest Timer +30s/-30s Adjustment

**Files:**
- Modify: `lib/features/workouts/ui/widgets/rest_timer_overlay.dart`
- Modify: `lib/features/workouts/providers/notifiers/rest_timer_notifier.dart`

- [ ] **Step 1: Add adjustTime method to RestTimerNotifier**

In `lib/features/workouts/providers/notifiers/rest_timer_notifier.dart`, add:
```dart
void adjustTime(int deltaSeconds) {
  if (state == null) return;
  final newTotal = (state!.totalSeconds + deltaSeconds).clamp(30, 600);
  final elapsed = state!.totalSeconds - state!.remainingSeconds;
  final newRemaining = (newTotal - elapsed).clamp(0, newTotal);
  state = state!.copyWith(
    totalSeconds: newTotal,
    remainingSeconds: newRemaining,
  );
}
```

Note: The agent should check the exact state structure of `RestTimerNotifier` — it may use a plain class state rather than Freezed. Adapt the `adjustTime` method to match the existing mutation pattern (direct field assignment vs copyWith).

- [ ] **Step 2: Add +30/-30 buttons to overlay**

In `lib/features/workouts/ui/widgets/rest_timer_overlay.dart`, add two buttons flanking the Skip button:

```dart
// Below the "Rest" label, replace the single Skip button with a row:
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // -30s button
    IconButton.filled(
      onPressed: () => ref.read(restTimerProvider.notifier).adjustTime(-30),
      icon: const Text('-30s', style: TextStyle(fontWeight: FontWeight.w700)),
      style: IconButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: Colors.white12,
      ),
    ),
    const SizedBox(width: 24),
    // Skip button (existing, keep as-is)
    TextButton(
      onPressed: () => ref.read(restTimerProvider.notifier).skip(),
      style: TextButton.styleFrom(
        minimumSize: const Size(120, 56),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Text('Skip', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16)),
    ),
    const SizedBox(width: 24),
    // +30s button
    IconButton.filled(
      onPressed: () => ref.read(restTimerProvider.notifier).adjustTime(30),
      icon: const Text('+30s', style: TextStyle(fontWeight: FontWeight.w700)),
      style: IconButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: Colors.white12,
      ),
    ),
  ],
),
```

- [ ] **Step 3: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/widgets/rest_timer_overlay.dart lib/features/workouts/providers/notifiers/rest_timer_notifier.dart
dart analyze --fatal-infos lib/features/workouts/
flutter test test/unit/features/workouts/providers/rest_timer_notifier_test.dart test/widget/features/workouts/ui/widgets/rest_timer_overlay_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/workouts/ui/widgets/rest_timer_overlay.dart lib/features/workouts/providers/notifiers/rest_timer_notifier.dart
git commit -m "feat(workouts): add +30s/-30s rest timer adjustment buttons"
```

---

## Task 10: Active Workout Banner Visibility

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Increase banner contrast and add pulse animation**

In `lib/core/router/app_router.dart`, in the `_ActiveWorkoutBanner` widget:

1. Change the background color from 15% opacity to full primary at 85% opacity:
```dart
color: theme.colorScheme.primary.withValues(alpha: 0.85),
```

2. Change text and icon colors to `onPrimary` (black on green) for contrast:
```dart
Icon(Icons.fitness_center, color: theme.colorScheme.onPrimary),
// ...
Text(name, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary)),
Text(elapsed, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
Icon(Icons.chevron_right, color: theme.colorScheme.onPrimary),
```

3. Optionally add a subtle pulsing border using `AnimatedContainer` or a `BoxDecoration` with a green border that pulses. A simple approach: add a `Border.all(color: primary, width: 2)` to the container decoration. A full pulse animation can be deferred.

- [ ] **Step 2: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/core/router/app_router.dart
dart analyze --fatal-infos lib/core/router/app_router.dart
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "fix(core): increase active workout banner visibility with high-contrast styling"
```

---

## Task 11: Exercise Summary in History Cards

**Files:**
- Modify: `lib/features/workouts/ui/workout_history_screen.dart`
- Modify: `lib/features/workouts/models/workout.dart` (if needed)
- Modify: `lib/features/workouts/data/workout_repository.dart` (if query needs exercise names)

- [ ] **Step 1: Check if workout history query includes exercise names**

Read `lib/features/workouts/data/workout_repository.dart` — check what `getWorkoutHistory()` returns. If it returns `Workout` models without exercise data, you'll need to either:
- a) Join exercise names in the history query (preferred — single query)
- b) Add a separate `exerciseNames` field populated from a subquery

The simplest approach: modify the history query to include a comma-separated exercise name summary. Check the `Workout` model — if it doesn't have an `exerciseNames` or `exerciseSummary` field, add one as an optional non-persisted field or compute it from the joined data.

- [ ] **Step 2: Display exercise names in _WorkoutHistoryCard**

In `lib/features/workouts/ui/workout_history_screen.dart`, in `_WorkoutHistoryCard`:

Add a subtitle line below the workout name showing exercise names:
```dart
// After the workout name Text widget:
if (workout.exerciseSummary != null && workout.exerciseSummary!.isNotEmpty)
  Text(
    workout.exerciseSummary!,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
```

The `exerciseSummary` should be a string like "Bench Press, Squat, Deadlift +2" — showing top 3 exercise names and a count of remaining.

- [ ] **Step 3: Run tests and format**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format lib/features/workouts/ui/workout_history_screen.dart lib/features/workouts/data/workout_repository.dart lib/features/workouts/models/workout.dart
dart analyze --fatal-infos lib/features/workouts/
flutter test test/unit/features/workouts/ test/widget/features/workouts/
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/workouts/
git commit -m "feat(workouts): show exercise summary on workout history cards"
```

---

## Task 12: Final Verification & CI

- [ ] **Step 1: Run full CI pipeline**

```bash
export PATH="/c/flutter/bin:$PATH"
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart run build_runner build --delete-conflicting-outputs
flutter test
```

All must pass with zero warnings.

- [ ] **Step 2: Manual smoke check list**

Verify these flows work end-to-end on `flutter run`:
1. Fresh signup → 2-page onboarding → profile data saved → home screen
2. Home → tap "Start Workout" → lands directly on active workout (no name dialog)
3. Active workout → tap workout name in AppBar → rename inline
4. Add exercise → add set → weight/reps numbers are large and glowing
5. Tap weight number → numpad opens → enter value → confirms
6. Previous session data shown as ghost text on set rows (requires having a prior workout)
7. Rest timer → shows -30s / +30s buttons alongside Skip
8. Finish button is at the bottom of the screen
9. History → cards show exercise names
10. Profile tab → shows name, email, weight unit toggle, logout works
11. Active workout banner (navigate to another tab while workout active) → high contrast green

- [ ] **Step 3: Commit any final fixes**

```bash
git add -A
git commit -m "fix(core): final Step 5e polish and test fixes"
```
