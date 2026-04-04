# Step 8: Home Screen Polish & PR Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface PR data on the home screen and workout detail, add a resume workout banner on home, and enhance the nav bar banner.

**Architecture:** Four independent UI additions wired to two new providers and two new repository methods. All data already exists in `personal_records` and `workouts` tables. No migrations.

**Tech Stack:** Flutter, Riverpod (FutureProvider), Supabase client queries, Freezed models (existing)

**Spec:** `docs/superpowers/specs/2026-04-04-step8-home-polish-pr-integration-design.md`

**Commands:**
```bash
export PATH="/c/flutter/bin:$PATH"
flutter pub get
make gen          # if Freezed models change (not expected this step)
make format
make analyze
flutter test
```

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/features/personal_records/data/pr_repository.dart` | Modify | Add `getRecentRecordsWithExercises()` and `getPRsForWorkout()` |
| `lib/features/personal_records/providers/pr_providers.dart` | Modify | Add `recentPRsProvider` and `workoutPRSetIdsProvider` |
| `lib/features/workouts/ui/widgets/resume_workout_banner.dart` | Create | Resume banner widget |
| `lib/features/personal_records/ui/widgets/recent_prs_section.dart` | Create | Recent PRs section for home screen |
| `lib/features/workouts/ui/home_screen.dart` | Modify | Integrate banner + PR section |
| `lib/features/workouts/ui/workout_detail_screen.dart` | Modify | PR badge on set rows |
| `lib/core/router/app_router.dart` | Modify | Nav bar banner static upgrade |
| `test/fixtures/test_factories.dart` | Modify | Add `TestPersonalRecordWithExerciseFactory` |
| `test/unit/features/personal_records/data/pr_repository_test.dart` | Create | Unit tests for new repo methods |
| `test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart` | Create | Widget tests for resume banner |
| `test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart` | Create | Widget tests for recent PRs section |
| `test/widget/features/workouts/ui/workout_detail_screen_test.dart` | Create | Widget tests for PR badges |

---

## Task 1: Add `getRecentRecordsWithExercises()` to PR Repository

**Files:**
- Modify: `lib/features/personal_records/data/pr_repository.dart:59-85`
- Test: `test/unit/features/personal_records/data/pr_repository_test.dart` (create)

- [ ] **Step 1: Create test file with failing test**

Create `test/unit/features/personal_records/data/pr_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:gymbuddy/features/personal_records/data/pr_repository.dart';
import 'package:gymbuddy/features/personal_records/models/record_type.dart';

import '../../../../fixtures/test_factories.dart';

// Mock chain classes for Supabase query builder
class MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock
    implements supabase.SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestTransformBuilder extends Mock
    implements
        supabase.PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late PRRepository repo;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    when(() => mockClient.from('personal_records'))
        .thenReturn(mockQueryBuilder);
    repo = PRRepository(mockClient);
  });

  group('getRecentRecordsWithExercises', () {
    test('returns records with limit applied', () async {
      final mockFilter = MockPostgrestFilterBuilder();
      final mockTransform = MockPostgrestTransformBuilder();

      when(() => mockQueryBuilder.select('*, exercises(name, equipment_type)'))
          .thenReturn(mockFilter);
      when(() => mockFilter.eq('user_id', 'user-001'))
          .thenReturn(mockFilter);
      when(() => mockFilter.order('achieved_at', ascending: false))
          .thenReturn(mockTransform);
      when(() => mockTransform.limit(3)).thenAnswer((_) async => [
            {
              ...TestPersonalRecordFactory.create(
                id: 'pr-1',
                exerciseId: 'ex-1',
                recordType: 'max_weight',
                value: 100.0,
              ),
              'exercises': {'name': 'Bench Press', 'equipment_type': 'barbell'},
            },
            {
              ...TestPersonalRecordFactory.create(
                id: 'pr-2',
                exerciseId: 'ex-2',
                recordType: 'max_reps',
                value: 15.0,
              ),
              'exercises': {'name': 'Pull Up', 'equipment_type': 'bodyweight'},
            },
          ]);

      final result = await repo.getRecentRecordsWithExercises(
        'user-001',
        limit: 3,
      );

      expect(result, hasLength(2));
      expect(result[0].exerciseName, 'Bench Press');
      expect(result[0].record.recordType, RecordType.maxWeight);
      expect(result[1].exerciseName, 'Pull Up');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/unit/features/personal_records/data/pr_repository_test.dart -v
```

Expected: FAIL — `getRecentRecordsWithExercises` not defined.

- [ ] **Step 3: Implement `getRecentRecordsWithExercises()`**

Add this method to `PRRepository` in `lib/features/personal_records/data/pr_repository.dart`, after the existing `getRecordsWithExercises` method (after line 85):

```dart
  /// Fetch the most recent personal records with exercise details, limited.
  ///
  /// LIMIT is applied at the query level — does not fetch all and slice.
  Future<
    List<
      ({
        PersonalRecord record,
        String exerciseName,
        EquipmentType equipmentType,
      })
    >
  >
  getRecentRecordsWithExercises(String userId, {int limit = 3}) {
    return mapException(() async {
      final data = await _records
          .select('*, exercises(name, equipment_type)')
          .eq('user_id', userId)
          .order('achieved_at', ascending: false)
          .limit(limit);

      return data.map((row) {
        final exerciseData = row['exercises'] as Map<String, dynamic>?;
        final exerciseName =
            (exerciseData?['name'] as String?) ?? 'Unknown Exercise';
        final equipmentType = EquipmentType.fromString(
          (exerciseData?['equipment_type'] as String?) ?? 'barbell',
        );

        final recordRow = Map<String, dynamic>.from(row)..remove('exercises');
        final record = PersonalRecord.fromJson(recordRow);

        return (
          record: record,
          exerciseName: exerciseName,
          equipmentType: equipmentType,
        );
      }).toList();
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/unit/features/personal_records/data/pr_repository_test.dart -v
```

Expected: PASS. If the Supabase mock chain doesn't match exactly, adjust mock setup to match the actual query builder return types. The key verification is that `.limit(limit)` is called.

- [ ] **Step 5: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/personal_records/data/pr_repository.dart test/unit/features/personal_records/data/pr_repository_test.dart
git commit -m "feat(progress): add getRecentRecordsWithExercises with LIMIT to PR repository"
```

---

## Task 2: Add `getPRsForWorkout()` to PR Repository

**Files:**
- Modify: `lib/features/personal_records/data/pr_repository.dart`
- Modify: `test/unit/features/personal_records/data/pr_repository_test.dart`

- [ ] **Step 1: Add failing test**

Append to the test file from Task 1:

```dart
  group('getPRsForWorkout', () {
    test('returns PRs matching set IDs from workout', () async {
      // Query 1: fetch set IDs for workout
      final mockSetsBuilder = MockSupabaseQueryBuilder();
      final mockSetsFilter = MockPostgrestFilterBuilder();

      when(() => mockClient.from('sets')).thenReturn(mockSetsBuilder);
      when(() => mockSetsBuilder.select(
              'id, workout_exercises!inner(workout_id)'))
          .thenReturn(mockSetsFilter);
      when(() => mockSetsFilter.eq('workout_exercises.workout_id', 'w-001'))
          .thenAnswer((_) async => [
                {'id': 'set-1', 'workout_exercises': {'workout_id': 'w-001'}},
                {'id': 'set-2', 'workout_exercises': {'workout_id': 'w-001'}},
              ]);

      // Query 2: fetch PRs by set IDs
      final mockPRFilter = MockPostgrestFilterBuilder();
      when(() => mockQueryBuilder.select()).thenReturn(mockPRFilter);
      when(() => mockPRFilter.eq('user_id', 'user-001'))
          .thenReturn(mockPRFilter);
      when(() => mockPRFilter.inFilter('set_id', ['set-1', 'set-2']))
          .thenAnswer((_) async => [
                TestPersonalRecordFactory.create(
                  id: 'pr-1',
                  setId: 'set-1',
                  recordType: 'max_weight',
                  value: 100.0,
                ),
              ]);

      final result = await repo.getPRsForWorkout('w-001', 'user-001');

      expect(result, hasLength(1));
      expect(result.first.setId, 'set-1');
    });

    test('returns empty list when workout has no sets', () async {
      final mockSetsBuilder = MockSupabaseQueryBuilder();
      final mockSetsFilter = MockPostgrestFilterBuilder();

      when(() => mockClient.from('sets')).thenReturn(mockSetsBuilder);
      when(() => mockSetsBuilder.select(
              'id, workout_exercises!inner(workout_id)'))
          .thenReturn(mockSetsFilter);
      when(() => mockSetsFilter.eq('workout_exercises.workout_id', 'w-002'))
          .thenAnswer((_) async => []);

      final result = await repo.getPRsForWorkout('w-002', 'user-001');

      expect(result, isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/unit/features/personal_records/data/pr_repository_test.dart -v
```

Expected: FAIL — `getPRsForWorkout` not defined.

- [ ] **Step 3: Implement `getPRsForWorkout()`**

Add to `PRRepository` after the method from Task 1:

```dart
  /// Fetch personal records achieved during a specific workout.
  ///
  /// Two-query approach:
  /// 1. Fetch all set IDs for the workout (sets → workout_exercises → workout)
  /// 2. Fetch PRs where set_id is in those set IDs
  Future<List<PersonalRecord>> getPRsForWorkout(
    String workoutId,
    String userId,
  ) {
    return mapException(() async {
      // Query 1: get all set IDs belonging to this workout
      final setsData = await _client
          .from('sets')
          .select('id, workout_exercises!inner(workout_id)')
          .eq('workout_exercises.workout_id', workoutId);

      final setIds =
          setsData.map((row) => row['id'] as String).toList();

      if (setIds.isEmpty) return [];

      // Query 2: fetch PRs that reference these sets
      final prData = await _records
          .select()
          .eq('user_id', userId)
          .inFilter('set_id', setIds);

      return prData.map(PersonalRecord.fromJson).toList();
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/unit/features/personal_records/data/pr_repository_test.dart -v
```

- [ ] **Step 5: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/personal_records/data/pr_repository.dart test/unit/features/personal_records/data/pr_repository_test.dart
git commit -m "feat(progress): add getPRsForWorkout two-query method to PR repository"
```

---

## Task 3: Add `recentPRsProvider` and `workoutPRSetIdsProvider`

**Files:**
- Modify: `lib/features/personal_records/providers/pr_providers.dart`

- [ ] **Step 1: Add both providers**

Append to `lib/features/personal_records/providers/pr_providers.dart` after line 52:

```dart
/// Fetches the most recent PRs (max 3) with exercise details for home screen.
/// LIMIT applied at the database level via repository.
/// Hidden when empty — the home screen omits this section entirely if no PRs.
final recentPRsProvider = FutureProvider.autoDispose<List<PRWithExercise>>((ref) {
  final repo = ref.watch(prRepositoryProvider);
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return repo.getRecentRecordsWithExercises(user.id, limit: 3);
});

/// Fetches the set IDs that are personal records for a given workout.
/// Used by workout detail screen to show PR badges on specific sets.
final workoutPRSetIdsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((
  ref,
  workoutId,
) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return {};
  final repo = ref.watch(prRepositoryProvider);
  final prs = await repo.getPRsForWorkout(workoutId, user.id);
  return prs.map((pr) => pr.setId).whereType<String>().toSet();
});
```

- [ ] **Step 2: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/personal_records/providers/pr_providers.dart
git commit -m "feat(progress): add recentPRsProvider and workoutPRSetIdsProvider"
```

---

## Task 4: Create Resume Workout Banner Widget

**Files:**
- Create: `lib/features/workouts/ui/widgets/resume_workout_banner.dart`
- Test: `test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart` (create)

- [ ] **Step 1: Write failing widget test**

Create `test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy/features/workouts/models/workout.dart';
import 'package:gymbuddy/features/workouts/models/workout_exercise.dart';
import 'package:gymbuddy/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy/features/workouts/ui/widgets/resume_workout_banner.dart';

import '../../../../../fixtures/test_factories.dart';

void main() {
  Widget buildTestWidget({ActiveWorkoutState? activeState}) {
    return ProviderScope(
      overrides: [
        activeWorkoutProvider.overrideWith((ref) {
          return FakeActiveWorkoutNotifier(activeState);
        }),
        // Override the elapsed timer to avoid real stream
        elapsedTimerProvider(DateTime.now().toUtc())
            .overrideWith((ref) => Stream.value(const Duration(minutes: 5))),
      ],
      child: const MaterialApp(home: Scaffold(body: ResumeWorkoutBanner())),
    );
  }

  group('ResumeWorkoutBanner', () {
    testWidgets('renders nothing when no active workout', (tester) async {
      await tester.pumpWidget(buildTestWidget(activeState: null));
      await tester.pump();

      expect(find.byType(ResumeWorkoutBanner), findsOneWidget);
      // The banner should render an empty SizedBox.shrink
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('renders nothing when active workout has 0 exercises',
        (tester) async {
      final state = ActiveWorkoutState.fromJson(
        TestActiveWorkoutStateFactory.create(),
      );
      // state.exercises is empty by default from factory

      await tester.pumpWidget(buildTestWidget(activeState: state));
      await tester.pump();

      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('renders banner when active workout has exercises',
        (tester) async {
      final state = ActiveWorkoutState.fromJson(
        TestActiveWorkoutStateFactory.createWithExercises(),
      );

      await tester.pumpWidget(buildTestWidget(activeState: state));
      await tester.pump();

      expect(find.text(state.workout.name), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}

// Simple fake notifier for testing
class FakeActiveWorkoutNotifier extends ActiveWorkoutNotifier {
  FakeActiveWorkoutNotifier(this._state);
  final ActiveWorkoutState? _state;

  @override
  Future<ActiveWorkoutState?> build() async => _state;
}
```

Note: The exact mock setup may need adjustment based on how `ActiveWorkoutNotifier` is structured. The key assertions are: hidden when null/empty, visible when exercises exist.

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart -v
```

Expected: FAIL — `ResumeWorkoutBanner` not found.

- [ ] **Step 3: Implement the banner widget**

Create `lib/features/workouts/ui/widgets/resume_workout_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/workout_providers.dart';

/// Prominent resume banner shown at the top of the home screen when
/// an active workout exists with at least one exercise or completed set.
///
/// Static design — the live elapsed timer provides the "alive" signal.
class ResumeWorkoutBanner extends ConsumerWidget {
  const ResumeWorkoutBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWorkout = ref.watch(activeWorkoutProvider);

    final state = asyncWorkout.valueOrNull;
    if (state == null) return const SizedBox.shrink();

    // Hide for empty workouts (accidental start) — avoids stuck banner
    final hasContent = state.exercises.isNotEmpty ||
        state.exercises.any(
          (e) => e.sets.any((s) => s.isCompleted),
        );
    if (!hasContent) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final elapsed = ref.watch(elapsedTimerProvider(state.workout.startedAt));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.mediumImpact();
            context.go('/workout/active');
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.workout.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          elapsed.when(
                            data: _formatElapsed,
                            loading: () => '...',
                            error: (_, _) => '',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart -v
```

Adjust mock/fake setup as needed until tests pass.

- [ ] **Step 5: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/ui/widgets/resume_workout_banner.dart test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart
git commit -m "feat(workouts): add ResumeWorkoutBanner widget for home screen"
```

---

## Task 5: Create Recent PRs Section Widget

**Files:**
- Create: `lib/features/personal_records/ui/widgets/recent_prs_section.dart`
- Test: `test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart` (create)

- [ ] **Step 1: Write failing widget test**

Create `test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/features/exercises/models/exercise.dart';
import 'package:gymbuddy/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy/features/personal_records/models/record_type.dart';
import 'package:gymbuddy/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy/features/personal_records/ui/widgets/recent_prs_section.dart';

void main() {
  Widget buildTestWidget({required List<PRWithExercise> prs}) {
    return ProviderScope(
      overrides: [
        recentPRsProvider.overrideWith((ref) async => prs),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: RecentPRsSection())),
      ),
    );
  }

  group('RecentPRsSection', () {
    testWidgets('hidden when PR list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(prs: []));
      await tester.pumpAndSettle();

      expect(find.text('RECENT RECORDS'), findsNothing);
    });

    testWidgets('shows section header and View All when PRs exist',
        (tester) async {
      final prs = [
        (
          record: PersonalRecord(
            id: 'pr-1',
            userId: 'u-1',
            exerciseId: 'e-1',
            recordType: RecordType.maxWeight,
            value: 100.0,
            achievedAt: DateTime.now().toUtc(),
          ),
          exerciseName: 'Bench Press',
          equipmentType: EquipmentType.barbell,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(prs: prs));
      await tester.pumpAndSettle();

      expect(find.text('RECENT RECORDS'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('100 kg'), findsOneWidget);
    });

    testWidgets('shows up to 3 PR rows', (tester) async {
      final prs = List.generate(
        3,
        (i) => (
          record: PersonalRecord(
            id: 'pr-$i',
            userId: 'u-1',
            exerciseId: 'e-$i',
            recordType: RecordType.maxWeight,
            value: (100 + i * 10).toDouble(),
            achievedAt: DateTime.now().toUtc(),
          ),
          exerciseName: 'Exercise $i',
          equipmentType: EquipmentType.barbell,
        ),
      );

      await tester.pumpWidget(buildTestWidget(prs: prs));
      await tester.pumpAndSettle();

      expect(find.text('Exercise 0'), findsOneWidget);
      expect(find.text('Exercise 1'), findsOneWidget);
      expect(find.text('Exercise 2'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart -v
```

Expected: FAIL — `RecentPRsSection` not defined.

- [ ] **Step 3: Implement the Recent PRs Section widget**

Create `lib/features/personal_records/ui/widgets/recent_prs_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/record_type.dart';
import '../../providers/pr_providers.dart';

/// Displays the most recent personal records on the home screen.
///
/// Hidden entirely when loading, errored, or empty — no placeholder.
/// Matches the visual pattern of the _RecentWorkoutRow in home_screen.dart.
class RecentPRsSection extends ConsumerWidget {
  const RecentPRsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPRs = ref.watch(recentPRsProvider);

    return asyncPRs.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (prs) {
        if (prs.isEmpty) return const SizedBox.shrink();
        return _PRsSectionContent(prs: prs);
      },
    );
  }
}

class _PRsSectionContent extends StatelessWidget {
  const _PRsSectionContent({required this.prs});

  final List<PRWithExercise> prs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT RECORDS',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/records'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...prs.map((pr) => _RecentPRRow(pr: pr)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RecentPRRow extends StatelessWidget {
  const _RecentPRRow({required this.pr});

  final PRWithExercise pr;

  String _formatValue(RecordType type, double value) {
    return switch (type) {
      RecordType.maxWeight =>
        '${value == value.roundToDouble() ? value.toInt() : value} kg',
      RecordType.maxReps => '${value.toInt()} reps',
      RecordType.maxVolume =>
        '${value == value.roundToDouble() ? value.toInt() : value} kg',
    };
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pr.exerciseName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pr.record.recordType.displayName}  \u00b7  ${_formatRelativeDate(pr.record.achievedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatValue(pr.record.recordType, pr.record.value),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart -v
```

- [ ] **Step 5: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/personal_records/ui/widgets/recent_prs_section.dart test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart
git commit -m "feat(progress): add RecentPRsSection widget for home screen"
```

---

## Task 6: Integrate Banner + PRs into Home Screen

**Files:**
- Modify: `lib/features/workouts/ui/home_screen.dart`

- [ ] **Step 1: Add imports**

Add these imports at the top of `home_screen.dart`:

```dart
import '../../personal_records/ui/widgets/recent_prs_section.dart';
import 'widgets/resume_workout_banner.dart';
```

- [ ] **Step 2: Add ResumeWorkoutBanner as first child in Column**

In the `Column` children list (line 30), add `const ResumeWorkoutBanner()` as the first child before the header:

Replace:
```dart
          children: [
            // Header
            const SizedBox(height: 8),
```

With:
```dart
          children: [
            // Resume active workout banner (hidden when no active workout)
            const ResumeWorkoutBanner(),

            // Header
            const SizedBox(height: 8),
```

- [ ] **Step 3: Add RecentPRsSection after recent workouts**

Insert `const RecentPRsSection()` between the recent workouts section and the "Start Empty Workout" button. Replace:

```dart
            // Start empty workout
            Center(
```

With:
```dart
            // Recent personal records
            const RecentPRsSection(),

            // Start empty workout
            Center(
```

- [ ] **Step 4: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 5: Run all tests**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/workouts/ui/home_screen.dart
git commit -m "feat(workouts): integrate ResumeWorkoutBanner and RecentPRsSection into home screen"
```

---

## Task 7: Add PR Badges to Workout Detail Screen

**Files:**
- Modify: `lib/features/workouts/ui/workout_detail_screen.dart`
- Test: `test/widget/features/workouts/ui/workout_detail_screen_test.dart` (create)

- [ ] **Step 1: Write failing widget test**

Create `test/widget/features/workouts/ui/workout_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy/features/workouts/models/workout.dart';
import 'package:gymbuddy/features/workouts/models/workout_exercise.dart';
import 'package:gymbuddy/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy/features/workouts/ui/workout_detail_screen.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  late WorkoutDetail testDetail;

  setUp(() {
    final exerciseData = TestExerciseFactory.create(
      id: 'e-1',
      name: 'Bench Press',
    );
    final weData = TestWorkoutExerciseFactory.create(
      id: 'we-1',
      exerciseId: 'e-1',
    );

    testDetail = WorkoutRepository.parseWorkoutDetail({
      ...TestWorkoutFactory.create(id: 'w-1'),
      'workout_exercises': [
        {
          ...weData,
          'exercise': exerciseData,
          'sets': [
            TestSetFactory.create(
              id: 'set-1',
              workoutExerciseId: 'we-1',
              setNumber: 1,
            ),
            TestSetFactory.create(
              id: 'set-2',
              workoutExerciseId: 'we-1',
              setNumber: 2,
            ),
          ],
        },
      ],
    });
  });

  Widget buildTestWidget({Set<String> prSetIds = const {}}) {
    return ProviderScope(
      overrides: [
        workoutDetailProvider('w-1').overrideWith((ref) async => testDetail),
        workoutPRSetIdsProvider('w-1').overrideWith((ref) async => prSetIds),
      ],
      child: const MaterialApp(
        home: WorkoutDetailScreen(workoutId: 'w-1'),
      ),
    );
  }

  group('PR badges on workout detail', () {
    testWidgets('shows trophy icon on PR sets', (tester) async {
      await tester.pumpWidget(buildTestWidget(prSetIds: {'set-1'}));
      await tester.pumpAndSettle();

      // set-1 is a PR — should show trophy
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('shows set number on non-PR sets', (tester) async {
      await tester.pumpWidget(buildTestWidget(prSetIds: {}));
      await tester.pumpAndSettle();

      // No PR badges
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      // Both set numbers visible
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('no badges during loading state', (tester) async {
      // Override to never resolve
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutDetailProvider('w-1')
                .overrideWith((ref) async => testDetail),
            workoutPRSetIdsProvider('w-1')
                .overrideWith((ref) => Future.delayed(
                      const Duration(days: 1),
                      () => <String>{},
                    )),
          ],
          child: const MaterialApp(
            home: WorkoutDetailScreen(workoutId: 'w-1'),
          ),
        ),
      );
      await tester.pump(); // Don't settle — PR provider still loading

      // No trophy icons during loading
      expect(find.byIcon(Icons.emoji_events), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/widget/features/workouts/ui/workout_detail_screen_test.dart -v
```

Expected: FAIL — no `isPR` parameter, no trophy icon in the widget.

- [ ] **Step 3: Modify `_ReadOnlySetRow` to accept `isPR`**

In `lib/features/workouts/ui/workout_detail_screen.dart`, update `_ReadOnlySetRow`:

Replace the class definition (lines 221-295):

```dart
class _ReadOnlySetRow extends StatelessWidget {
  const _ReadOnlySetRow({required this.set, this.isPR = false});

  final ExerciseSet set;
  final bool isPR;

  String get _typeLabel => switch (set.setType) {
    SetType.working => 'W',
    SetType.warmup => 'Wu',
    SetType.dropset => 'D',
    SetType.failure => 'F',
  };

  Color _typeColor(ThemeData theme) => switch (set.setType) {
    SetType.working => theme.colorScheme.primary,
    SetType.warmup => theme.colorScheme.secondary,
    SetType.dropset => theme.colorScheme.tertiary,
    SetType.failure => theme.colorScheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: isPR
                ? Icon(
                    Icons.emoji_events,
                    size: 18,
                    color: Colors.amber[300],
                  )
                : Text(
                    '${set.setNumber}.',
                    style: textStyle?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              '${set.weight?.toStringAsFixed(set.weight == set.weight?.roundToDouble() ? 0 : 1) ?? '-'} kg',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${set.reps ?? '-'}',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor(theme).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _typeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _typeColor(theme),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Make `_ReadOnlyExerciseCard` consume PR data**

Convert `_ReadOnlyExerciseCard` to a `ConsumerWidget` and wire in `workoutPRSetIdsProvider`. Import the provider at the top of the file:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

(Already imported — check if it's there. If not, add it.)

Add the PR providers import:

```dart
import '../../personal_records/providers/pr_providers.dart';
```

Update the `_ReadOnlyExerciseCard` class. Change `StatelessWidget` to `ConsumerWidget` and accept `workoutId`:

```dart
class _ReadOnlyExerciseCard extends ConsumerWidget {
  const _ReadOnlyExerciseCard({
    required this.exercise,
    required this.sets,
    required this.workoutId,
  });

  final WorkoutExercise exercise;
  final List<ExerciseSet> sets;
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prSetIds =
        ref.watch(workoutPRSetIdsProvider(workoutId)).valueOrNull ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.exercise?.name ?? 'Exercise',
              style: theme.textTheme.titleMedium,
            ),
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SetColumnHeaders(theme: theme),
              const Divider(height: 1),
              ...sets.map(
                (s) => _ReadOnlySetRow(
                  set: s,
                  isPR: prSetIds.contains(s.id),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Pass `workoutId` to `_ReadOnlyExerciseCard` from `_WorkoutDetailBody`**

In `_WorkoutDetailBody.build()` (line 91-95), update the builder to pass `workoutId`:

Replace:
```dart
            return _ReadOnlyExerciseCard(exercise: exercise, sets: sets);
```

With:
```dart
            return _ReadOnlyExerciseCard(
              exercise: exercise,
              sets: sets,
              workoutId: detail.workout.id,
            );
```

- [ ] **Step 6: Run test to verify it passes**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test test/widget/features/workouts/ui/workout_detail_screen_test.dart -v
```

- [ ] **Step 7: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 8: Commit**

```bash
git add lib/features/workouts/ui/workout_detail_screen.dart test/widget/features/workouts/ui/workout_detail_screen_test.dart
git commit -m "feat(progress): add PR badges on workout detail set rows"
```

---

## Task 8: Enhance Nav Bar Banner

**Files:**
- Modify: `lib/core/router/app_router.dart:216-279`

- [ ] **Step 1: Update `_ActiveWorkoutBanner` decoration**

In `lib/core/router/app_router.dart`, update the `Container` decoration in `_ActiveWorkoutBanner.build()`. Replace the current decoration (around line 230):

Replace:
```dart
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.85),
          border: Border(
            top: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
```

With:
```dart
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ),
```

This changes: full opacity primary background (was 0.85) + contrasting top border (was same-color primary).

- [ ] **Step 2: Run format + analyze**

```bash
export PATH="/c/flutter/bin:$PATH" && dart format . && dart analyze --fatal-infos
```

- [ ] **Step 3: Run all tests**

```bash
export PATH="/c/flutter/bin:$PATH" && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(core): enhance active workout nav bar banner with full opacity and contrasting border"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Run full CI pipeline**

```bash
export PATH="/c/flutter/bin:$PATH" && make ci
```

Expected: all format, analyze, and test checks pass.

- [ ] **Step 2: Verify file count**

New files created:
- `lib/features/workouts/ui/widgets/resume_workout_banner.dart`
- `lib/features/personal_records/ui/widgets/recent_prs_section.dart`
- `test/unit/features/personal_records/data/pr_repository_test.dart`
- `test/widget/features/workouts/ui/widgets/resume_workout_banner_test.dart`
- `test/widget/features/personal_records/ui/widgets/recent_prs_section_test.dart`
- `test/widget/features/workouts/ui/workout_detail_screen_test.dart`

Modified files:
- `lib/features/personal_records/data/pr_repository.dart`
- `lib/features/personal_records/providers/pr_providers.dart`
- `lib/features/workouts/ui/home_screen.dart`
- `lib/features/workouts/ui/workout_detail_screen.dart`
- `lib/core/router/app_router.dart`

- [ ] **Step 3: Manual smoke test**

Run the app on Chrome and verify:
1. Home screen shows no resume banner (no active workout)
2. Start a workout, add an exercise → navigate to home → resume banner visible
3. Finish a workout with PRs → home screen shows Recent Records section
4. Open a workout from history → PR sets show trophy icon instead of set number
5. Active workout banner in nav bar has full opacity + contrasting top border

- [ ] **Step 4: Squash commits and prepare for PR**

All task commits should be on a feature branch. Squash into a single commit:

```bash
git checkout -b feature/step8-home-polish-pr-integration main~N
# (where N = number of Step 8 commits)
# Or create branch before starting tasks
```
