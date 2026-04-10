# GymBuddy PR 5 — Observability (Sentry + Supabase Analytics) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship first-party product analytics (9 events → Supabase `analytics_events` table) + Sentry crash reporting with strict PII scrubbing + a user-facing "Send crash reports" opt-out toggle, all as one bundled PR for Phase 13a Sprint A.

**Architecture:** Analytics is first-party — no third-party SDK. A new `analytics_events` table with RLS holds 9 typed events defined as a `freezed` union. A thin `AnalyticsRepository` extends `BaseRepository` and inserts rows via the existing Supabase client. Sentry is initialized in `main.dart` wrapping `runApp`, with `runZonedGuarded` + native hooks auto-wired. A `SentryReport` static helper gates captures/breadcrumbs via a Hive-backed `crash_reports_enabled` flag, allowing the opt-out toggle to control Sentry output without touching every call site.

**Tech Stack:** Flutter + Riverpod, `supabase_flutter ^2.5.0`, `freezed ^2.4.0`, `hive ^2.2.0`, `flutter_dotenv ^5.1.0`, new dep: `sentry_flutter` (latest compatible with Dart SDK `^3.11.4`). Tests use hand-rolled `Fake` classes (NOT `mocktail` mocks) per existing repo convention.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `supabase/migrations/00015_create_analytics_events.sql` | Schema + RLS for `analytics_events` table |
| `lib/features/analytics/data/models/analytics_event.dart` | Typed freezed union of the 9 events + `name` + `props` getters |
| `lib/features/analytics/data/analytics_repository.dart` | `insertEvent` method, extends `BaseRepository` |
| `lib/features/analytics/providers/analytics_providers.dart` | Riverpod providers for the repo |
| `lib/core/device/platform_info.dart` | Helpers: `currentPlatform()`, `currentAppVersion()` |
| `lib/core/observability/sentry_report.dart` | Static wrapper that gates `captureException` + `addBreadcrumb` via `_enabled` flag |
| `lib/core/observability/sentry_init.dart` | `initSentry()` helper: reads DSN, configures scrubbers, calls `SentryFlutter.init` |
| `lib/features/profile/providers/crash_reports_enabled_provider.dart` | Hive-backed provider for the opt-out flag |
| `test/unit/features/analytics/data/models/analytics_event_test.dart` | Tests for `name` + `props` on each variant |
| `test/unit/features/analytics/data/analytics_repository_test.dart` | Fake Supabase tests for insert behavior |
| `test/unit/core/observability/sentry_report_test.dart` | Tests for enabled/disabled gating |
| `test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart` | Hive persistence tests |

### Modified files

| Path | Change |
|---|---|
| `pubspec.yaml` | Add `sentry_flutter` dependency |
| `.env.example`, `.env` | Add `SENTRY_DSN=` key |
| `lib/main.dart` | Wrap `runApp` in `SentryFlutter.init(appRunner: ...)`, seed `SentryReport` from Hive |
| `lib/core/router/app_router.dart` | Add `SentryNavigatorObserver` with `routeNameExtractor` |
| `lib/core/data/base_repository.dart` | Call `SentryReport.captureException` inside `mapException` catch |
| `lib/features/auth/providers/notifiers/auth_notifier.dart` | Breadcrumbs on sign-in/sign-up/sign-out + `account_deleted` event |
| `lib/features/auth/ui/onboarding_screen.dart` | `onboarding_completed` event in `_finishOnboarding` |
| `lib/features/workouts/providers/notifiers/active_workout_notifier.dart` | `workout_started` (2 entry points), `workout_discarded`, `workout_finished` events + workout lifecycle breadcrumbs |
| `lib/features/personal_records/ui/pr_celebration_screen.dart` | `pr_celebration_seen` in `initState`, `add_to_plan_prompt_responded` in `_onContinue` |
| `lib/features/weekly_plan/ui/plan_management_screen.dart` | Refactor `_savePlan` to accept `source` + `usedAutofill` + `replacedExisting`, fire `week_plan_saved` |
| `lib/features/weekly_plan/providers/weekly_plan_provider.dart` | Fire `week_complete` in `markRoutineComplete` on transition to all-complete |
| `lib/features/profile/ui/profile_screen.dart` | Add "PRIVACY" section with "Send crash reports" `SwitchListTile` |
| `assets/legal/privacy_policy.md` | Targeted edits to Sections 2, 3, 5 + bump date |
| `docs/privacy_policy.md` | Mirror (preserve Jekyll front-matter) |

### Preconditions (verify before Task 1)

```bash
export PATH="/c/flutter/bin:$PATH"
git checkout main && git pull
git checkout -b feature/phase13a-sprintA-pr5-observability
flutter pub get
make ci
```

Expected: `make ci` passes on fresh main before any changes.

---

## Task 1: Create `analytics_events` migration

**Files:**
- Create: `supabase/migrations/00015_create_analytics_events.sql`

- [ ] **Step 1: Write the migration SQL**

Create `supabase/migrations/00015_create_analytics_events.sql` with:

```sql
-- Migration: create analytics_events table
-- Phase 13a Sprint A, PR 5 — first-party product analytics.
-- Events are inserted by authenticated users only (RLS), never read back
-- by users. Querying is done via the Supabase SQL editor with the service
-- role for retention/funnel analysis.

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  props       jsonb NOT NULL DEFAULT '{}'::jsonb,
  platform    text,
  app_version text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_created
  ON public.analytics_events (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_name_created
  ON public.analytics_events (name, created_at DESC);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_own_events"
  ON public.analytics_events
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Intentionally NO SELECT/UPDATE/DELETE policies: users cannot read their
-- own events back. Querying happens via the service role in the dashboard.
```

- [ ] **Step 2: Verify SQL parses (dry-run via psql if available, or visual review)**

This migration is applied post-merge via `npx supabase db push` per CLAUDE.md step 10. No local apply during this PR unless E2E tests need it (see Task 19).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/00015_create_analytics_events.sql
git commit -m "feat(core): add analytics_events table migration (PR 5)"
```

---

## Task 2: Define `AnalyticsEvent` freezed union

**Files:**
- Create: `lib/features/analytics/data/models/analytics_event.dart`
- Create: `test/unit/features/analytics/data/models/analytics_event_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/unit/features/analytics/data/models/analytics_event_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/analytics/data/models/analytics_event.dart';

void main() {
  group('AnalyticsEvent.name', () {
    test('onboardingCompleted → "onboarding_completed"', () {
      const event = AnalyticsEvent.onboardingCompleted(
        fitnessLevel: 'beginner',
        trainingFrequency: 3,
      );
      expect(event.name, 'onboarding_completed');
    });

    test('workoutStarted → "workout_started"', () {
      const event = AnalyticsEvent.workoutStarted(
        source: 'empty',
        routineId: null,
        exerciseCount: 0,
        hadActiveWorkoutConflict: false,
      );
      expect(event.name, 'workout_started');
    });

    test('workoutDiscarded → "workout_discarded"', () {
      const event = AnalyticsEvent.workoutDiscarded(
        elapsedSeconds: 120,
        completedSets: 2,
        exerciseCount: 3,
        source: 'routine_card',
      );
      expect(event.name, 'workout_discarded');
    });

    test('workoutFinished → "workout_finished"', () {
      const event = AnalyticsEvent.workoutFinished(
        durationSeconds: 3420,
        exerciseCount: 6,
        totalSets: 24,
        completedSets: 22,
        incompleteSetsSkipped: 2,
        hadPr: true,
        source: 'planned_bucket',
        workoutNumber: 5,
      );
      expect(event.name, 'workout_finished');
    });

    test('prCelebrationSeen → "pr_celebration_seen"', () {
      const event = AnalyticsEvent.prCelebrationSeen(
        isFirstWorkout: false,
        prCount: 2,
        recordTypes: ['max_weight', 'max_reps'],
      );
      expect(event.name, 'pr_celebration_seen');
    });

    test('weekPlanSaved → "week_plan_saved"', () {
      const event = AnalyticsEvent.weekPlanSaved(
        routineCount: 4,
        atSoftCap: true,
        usedAutofill: false,
        replacedExisting: false,
      );
      expect(event.name, 'week_plan_saved');
    });

    test('weekComplete → "week_complete"', () {
      const event = AnalyticsEvent.weekComplete(
        sessionsCompleted: 4,
        prCountThisWeek: 1,
        planSize: 4,
        weekNumber: 3,
      );
      expect(event.name, 'week_complete');
    });

    test('addToPlanPromptResponded → "add_to_plan_prompt_responded"', () {
      const event = AnalyticsEvent.addToPlanPromptResponded(
        action: 'added',
        trigger: 'pr_celebration_continue',
        routineId: '00000000-0000-0000-0000-000000000000',
      );
      expect(event.name, 'add_to_plan_prompt_responded');
    });

    test('accountDeleted → "account_deleted"', () {
      const event = AnalyticsEvent.accountDeleted(
        workoutCount: 12,
        daysSinceSignup: 47,
      );
      expect(event.name, 'account_deleted');
    });
  });

  group('AnalyticsEvent.props', () {
    test('onboardingCompleted produces snake_case prop keys', () {
      const event = AnalyticsEvent.onboardingCompleted(
        fitnessLevel: 'intermediate',
        trainingFrequency: 4,
      );
      expect(event.props, {
        'fitness_level': 'intermediate',
        'training_frequency': 4,
      });
    });

    test('workoutStarted omits null routine_id when source is empty', () {
      const event = AnalyticsEvent.workoutStarted(
        source: 'empty',
        routineId: null,
        exerciseCount: 0,
        hadActiveWorkoutConflict: false,
      );
      expect(event.props['routine_id'], null);
      expect(event.props['source'], 'empty');
      expect(event.props['exercise_count'], 0);
      expect(event.props['had_active_workout_conflict'], false);
    });

    test('workoutFinished includes all props in snake_case', () {
      const event = AnalyticsEvent.workoutFinished(
        durationSeconds: 3420,
        exerciseCount: 6,
        totalSets: 24,
        completedSets: 22,
        incompleteSetsSkipped: 2,
        hadPr: true,
        source: 'planned_bucket',
        workoutNumber: 5,
      );
      expect(event.props, {
        'duration_seconds': 3420,
        'exercise_count': 6,
        'total_sets': 24,
        'completed_sets': 22,
        'incomplete_sets_skipped': 2,
        'had_pr': true,
        'source': 'planned_bucket',
        'workout_number': 5,
      });
    });

    test('prCelebrationSeen serializes record_types as list', () {
      const event = AnalyticsEvent.prCelebrationSeen(
        isFirstWorkout: true,
        prCount: 3,
        recordTypes: ['max_weight', 'max_reps', 'max_volume'],
      );
      expect(event.props['record_types'], ['max_weight', 'max_reps', 'max_volume']);
      expect(event.props['is_first_workout'], true);
      expect(event.props['pr_count'], 3);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="/c/flutter/bin:$PATH"
flutter test test/unit/features/analytics/data/models/analytics_event_test.dart
```

Expected: FAIL with "target of URI doesn't exist: `package:gymbuddy_app/features/analytics/data/models/analytics_event.dart`"

- [ ] **Step 3: Create the freezed union**

Create `lib/features/analytics/data/models/analytics_event.dart`:

```dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_event.freezed.dart';

/// Typed product analytics events. Fixed set — new events require adding
/// a factory here and a case in the `name` + `props` getters.
///
/// Prop keys are serialized to snake_case to match the `analytics_events`
/// table's `props jsonb` column convention.
@freezed
class AnalyticsEvent with _$AnalyticsEvent {
  const AnalyticsEvent._();

  const factory AnalyticsEvent.onboardingCompleted({
    required String fitnessLevel,
    required int trainingFrequency,
  }) = _OnboardingCompleted;

  const factory AnalyticsEvent.workoutStarted({
    required String source,
    required String? routineId,
    required int exerciseCount,
    required bool hadActiveWorkoutConflict,
  }) = _WorkoutStarted;

  const factory AnalyticsEvent.workoutDiscarded({
    required int elapsedSeconds,
    required int completedSets,
    required int exerciseCount,
    required String source,
  }) = _WorkoutDiscarded;

  const factory AnalyticsEvent.workoutFinished({
    required int durationSeconds,
    required int exerciseCount,
    required int totalSets,
    required int completedSets,
    required int incompleteSetsSkipped,
    required bool hadPr,
    required String source,
    required int workoutNumber,
  }) = _WorkoutFinished;

  const factory AnalyticsEvent.prCelebrationSeen({
    required bool isFirstWorkout,
    required int prCount,
    required List<String> recordTypes,
  }) = _PrCelebrationSeen;

  const factory AnalyticsEvent.weekPlanSaved({
    required int routineCount,
    required bool atSoftCap,
    required bool usedAutofill,
    required bool replacedExisting,
  }) = _WeekPlanSaved;

  const factory AnalyticsEvent.weekComplete({
    required int sessionsCompleted,
    required int prCountThisWeek,
    required int planSize,
    required int weekNumber,
  }) = _WeekComplete;

  const factory AnalyticsEvent.addToPlanPromptResponded({
    required String action,
    required String trigger,
    required String routineId,
  }) = _AddToPlanPromptResponded;

  const factory AnalyticsEvent.accountDeleted({
    required int workoutCount,
    required int daysSinceSignup,
  }) = _AccountDeleted;

  /// Event name as stored in the `name` column of `analytics_events`.
  String get name => when(
        onboardingCompleted: (_, __) => 'onboarding_completed',
        workoutStarted: (_, __, ___, ____) => 'workout_started',
        workoutDiscarded: (_, __, ___, ____) => 'workout_discarded',
        workoutFinished: (_, __, ___, ____, _____, ______, _______, ________) =>
            'workout_finished',
        prCelebrationSeen: (_, __, ___) => 'pr_celebration_seen',
        weekPlanSaved: (_, __, ___, ____) => 'week_plan_saved',
        weekComplete: (_, __, ___, ____) => 'week_complete',
        addToPlanPromptResponded: (_, __, ___) => 'add_to_plan_prompt_responded',
        accountDeleted: (_, __) => 'account_deleted',
      );

  /// Props as stored in the `props` jsonb column. Keys are snake_case.
  /// Values are primitive JSON types only (String, int, double, bool, List).
  Map<String, Object?> get props => when(
        onboardingCompleted: (fitnessLevel, trainingFrequency) => {
          'fitness_level': fitnessLevel,
          'training_frequency': trainingFrequency,
        },
        workoutStarted: (source, routineId, exerciseCount, hadConflict) => {
          'source': source,
          'routine_id': routineId,
          'exercise_count': exerciseCount,
          'had_active_workout_conflict': hadConflict,
        },
        workoutDiscarded: (elapsed, completedSets, exerciseCount, source) => {
          'elapsed_seconds': elapsed,
          'completed_sets': completedSets,
          'exercise_count': exerciseCount,
          'source': source,
        },
        workoutFinished: (
          durationSeconds,
          exerciseCount,
          totalSets,
          completedSets,
          incompleteSetsSkipped,
          hadPr,
          source,
          workoutNumber,
        ) => {
          'duration_seconds': durationSeconds,
          'exercise_count': exerciseCount,
          'total_sets': totalSets,
          'completed_sets': completedSets,
          'incomplete_sets_skipped': incompleteSetsSkipped,
          'had_pr': hadPr,
          'source': source,
          'workout_number': workoutNumber,
        },
        prCelebrationSeen: (isFirstWorkout, prCount, recordTypes) => {
          'is_first_workout': isFirstWorkout,
          'pr_count': prCount,
          'record_types': recordTypes,
        },
        weekPlanSaved: (routineCount, atSoftCap, usedAutofill, replacedExisting) => {
          'routine_count': routineCount,
          'at_soft_cap': atSoftCap,
          'used_autofill': usedAutofill,
          'replaced_existing': replacedExisting,
        },
        weekComplete: (sessionsCompleted, prCountThisWeek, planSize, weekNumber) => {
          'sessions_completed': sessionsCompleted,
          'pr_count_this_week': prCountThisWeek,
          'plan_size': planSize,
          'week_number': weekNumber,
        },
        addToPlanPromptResponded: (action, trigger, routineId) => {
          'action': action,
          'trigger': trigger,
          'routine_id': routineId,
        },
        accountDeleted: (workoutCount, daysSinceSignup) => {
          'workout_count': workoutCount,
          'days_since_signup': daysSinceSignup,
        },
      );
}
```

- [ ] **Step 4: Run code generation**

```bash
export PATH="/c/flutter/bin:$PATH"
make gen
```

Expected: creates `lib/features/analytics/data/models/analytics_event.freezed.dart` with no errors.

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/unit/features/analytics/data/models/analytics_event_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/analytics/data/models/analytics_event.dart lib/features/analytics/data/models/analytics_event.freezed.dart test/unit/features/analytics/data/models/analytics_event_test.dart
git commit -m "feat(analytics): add typed AnalyticsEvent union for 9 events (PR 5)"
```

---

## Task 3: Implement `AnalyticsRepository`

**Files:**
- Create: `lib/features/analytics/data/analytics_repository.dart`
- Create: `test/unit/features/analytics/data/analytics_repository_test.dart`

- [ ] **Step 1: Write the failing test with hand-rolled Fakes**

Create `test/unit/features/analytics/data/analytics_repository_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/analytics/data/analytics_repository.dart';
import 'package:gymbuddy_app/features/analytics/data/models/analytics_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ---------------------------------------------------------------------------
// Fake Supabase infrastructure — records insert payloads
// ---------------------------------------------------------------------------

class _FakeClient extends Fake implements supabase.SupabaseClient {
  _FakeClient(this.builder);
  final _FakeInsertBuilder builder;

  @override
  supabase.SupabaseQueryBuilder from(String table) {
    builder.lastTable = table;
    return builder;
  }
}

class _FakeInsertBuilder extends Fake implements supabase.SupabaseQueryBuilder {
  _FakeInsertBuilder({this.error});

  String? lastTable;
  final List<Map<String, dynamic>> insertedRows = [];
  Object? error;

  @override
  supabase.PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    supabase.PostgrestQueryOptions? options,
    bool defaultToNull = true,
  }) {
    if (error != null) {
      return _FakeErrorFilterBuilder(error!);
    }
    if (values is Map<String, dynamic>) {
      insertedRows.add(values);
    } else if (values is List) {
      for (final v in values) {
        insertedRows.add(Map<String, dynamic>.from(v as Map));
      }
    }
    return _FakeOkFilterBuilder();
  }
}

class _FakeOkFilterBuilder extends Fake
    implements supabase.PostgrestFilterBuilder<dynamic> {
  @override
  Future<S> then<S>(
    FutureOr<S> Function(dynamic) onValue, {
    Function? onError,
  }) {
    return Future.value(onValue(null));
  }
}

class _FakeErrorFilterBuilder extends Fake
    implements supabase.PostgrestFilterBuilder<dynamic> {
  _FakeErrorFilterBuilder(this._error);
  final Object _error;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(dynamic) onValue, {
    Function? onError,
  }) {
    return Future.error(_error);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AnalyticsRepository.insertEvent', () {
    test('writes to analytics_events table with correct payload', () async {
      final builder = _FakeInsertBuilder();
      final repo = AnalyticsRepository(_FakeClient(builder));

      await repo.insertEvent(
        userId: 'user-abc',
        event: const AnalyticsEvent.workoutFinished(
          durationSeconds: 3420,
          exerciseCount: 6,
          totalSets: 24,
          completedSets: 22,
          incompleteSetsSkipped: 2,
          hadPr: true,
          source: 'planned_bucket',
          workoutNumber: 5,
        ),
        platform: 'android',
        appVersion: '1.2.3+45',
      );

      expect(builder.lastTable, 'analytics_events');
      expect(builder.insertedRows, hasLength(1));
      final row = builder.insertedRows.first;
      expect(row['user_id'], 'user-abc');
      expect(row['name'], 'workout_finished');
      expect(row['platform'], 'android');
      expect(row['app_version'], '1.2.3+45');
      expect(row['props'], isA<Map>());
      expect((row['props'] as Map)['workout_number'], 5);
      expect((row['props'] as Map)['had_pr'], true);
    });

    test('accepts null platform and app_version', () async {
      final builder = _FakeInsertBuilder();
      final repo = AnalyticsRepository(_FakeClient(builder));

      await repo.insertEvent(
        userId: 'user-abc',
        event: const AnalyticsEvent.accountDeleted(
          workoutCount: 0,
          daysSinceSignup: 1,
        ),
        platform: null,
        appVersion: null,
      );

      final row = builder.insertedRows.first;
      expect(row['platform'], null);
      expect(row['app_version'], null);
    });

    test('swallows insert errors without throwing (fire-and-forget)', () async {
      final builder = _FakeInsertBuilder(error: Exception('network down'));
      final repo = AnalyticsRepository(_FakeClient(builder));

      // Should NOT throw — analytics is best-effort.
      await expectLater(
        repo.insertEvent(
          userId: 'user-abc',
          event: const AnalyticsEvent.accountDeleted(
            workoutCount: 0,
            daysSinceSignup: 1,
          ),
          platform: 'android',
          appVersion: '1.0.0',
        ),
        completes,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/unit/features/analytics/data/analytics_repository_test.dart
```

Expected: FAIL with "target of URI doesn't exist: `analytics_repository.dart`"

- [ ] **Step 3: Implement the repository**

Create `lib/features/analytics/data/analytics_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import 'models/analytics_event.dart';

/// Fire-and-forget repository for the first-party product analytics events
/// table. Errors are swallowed — analytics must never break the user's flow.
class AnalyticsRepository extends BaseRepository {
  const AnalyticsRepository(this._client);

  final supabase.SupabaseClient _client;

  /// Inserts a single event. Never throws — all errors are caught and
  /// swallowed so a failed insert cannot break the caller's path.
  Future<void> insertEvent({
    required String userId,
    required AnalyticsEvent event,
    required String? platform,
    required String? appVersion,
  }) async {
    try {
      await _client.from('analytics_events').insert({
        'user_id': userId,
        'name': event.name,
        'props': event.props,
        'platform': platform,
        'app_version': appVersion,
      });
    } catch (_) {
      // Best-effort: analytics failures are silent. We do NOT capture these
      // to Sentry — a Supabase outage would flood the error tracker.
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/unit/features/analytics/data/analytics_repository_test.dart
```

Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/analytics/data/analytics_repository.dart test/unit/features/analytics/data/analytics_repository_test.dart
git commit -m "feat(analytics): add AnalyticsRepository with fire-and-forget insert (PR 5)"
```

---

## Task 4: Platform info helper + analytics providers

**Files:**
- Create: `lib/core/device/platform_info.dart`
- Create: `lib/features/analytics/providers/analytics_providers.dart`

- [ ] **Step 1: Create platform info helper**

Create `lib/core/device/platform_info.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Returns the current platform as a short string: 'android', 'ios', 'web',
/// 'macos', 'windows', 'linux', or 'unknown'.
String currentPlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

/// Cached app version string in "version+build" format.
///
/// Populated once at app boot by `initAppVersion()` reading package_info_plus,
/// or left null if not initialized. Callers should fall back to null gracefully.
String? _cachedAppVersion;

/// Returns the cached app version, or null if `initAppVersion()` has not run.
String? currentAppVersion() => _cachedAppVersion;

/// Sets the cached app version. Call once at app boot.
void setAppVersion(String version) {
  _cachedAppVersion = version;
}
```

- [ ] **Step 2: Create analytics providers**

Create `lib/features/analytics/providers/analytics_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/analytics_repository.dart';

/// Provides the [AnalyticsRepository] singleton.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(Supabase.instance.client);
});
```

- [ ] **Step 3: Run analyze to confirm nothing breaks**

```bash
export PATH="/c/flutter/bin:$PATH"
dart analyze lib/core/device/platform_info.dart lib/features/analytics/providers/analytics_providers.dart
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/core/device/platform_info.dart lib/features/analytics/providers/analytics_providers.dart
git commit -m "feat(analytics): add platform info helper + repository provider (PR 5)"
```

---

## Task 5: Add `sentry_flutter` dep + `.env` keys

**Files:**
- Modify: `pubspec.yaml`
- Modify: `.env.example`
- Modify: `.env`

- [ ] **Step 1: Add sentry_flutter dependency**

```bash
export PATH="/c/flutter/bin:$PATH"
flutter pub add sentry_flutter
```

Expected: pubspec.yaml updated with the latest `sentry_flutter` version compatible with Dart SDK `^3.11.4`. `pubspec.lock` updated.

- [ ] **Step 2: Add SENTRY_DSN to .env.example**

Edit `.env.example`, append:

```
SENTRY_DSN=
```

Final `.env.example`:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SENTRY_DSN=
```

- [ ] **Step 3: Add SENTRY_DSN to local .env**

Edit `.env` (git-ignored), append:

```
SENTRY_DSN=
```

Leave empty for local development — Sentry will be skipped when DSN is empty.

- [ ] **Step 4: Run pub get to confirm**

```bash
flutter pub get
```

Expected: resolves cleanly, no conflicts.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock .env.example
git commit -m "chore(deps): add sentry_flutter + SENTRY_DSN env key (PR 5)"
```

Note: `.env` is git-ignored, do not commit it.

---

## Task 6: `SentryReport` static gating wrapper

**Files:**
- Create: `lib/core/observability/sentry_report.dart`
- Create: `test/unit/core/observability/sentry_report_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/unit/core/observability/sentry_report_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/observability/sentry_report.dart';

void main() {
  setUp(() {
    // Default enabled state
    SentryReport.setEnabled(true);
  });

  group('SentryReport.setEnabled', () {
    test('defaults to enabled', () {
      expect(SentryReport.isEnabled, true);
    });

    test('can be disabled and re-enabled', () {
      SentryReport.setEnabled(false);
      expect(SentryReport.isEnabled, false);
      SentryReport.setEnabled(true);
      expect(SentryReport.isEnabled, true);
    });
  });

  group('SentryReport.captureException', () {
    test('returns without error when disabled', () async {
      SentryReport.setEnabled(false);
      await expectLater(
        SentryReport.captureException(
          Exception('test'),
          stackTrace: StackTrace.current,
        ),
        completes,
      );
    });

    // When enabled, we cannot assert that Sentry.captureException was called
    // without a Sentry mock harness — that is out of scope. The gating
    // behavior is the thing we care about here.
  });

  group('SentryReport.addBreadcrumb', () {
    test('returns without error when disabled', () {
      SentryReport.setEnabled(false);
      expect(
        () => SentryReport.addBreadcrumb(
          category: 'test',
          message: 'x',
        ),
        returnsNormally,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/unit/core/observability/sentry_report_test.dart
```

Expected: FAIL with "target of URI doesn't exist: `sentry_report.dart`"

- [ ] **Step 3: Implement SentryReport**

Create `lib/core/observability/sentry_report.dart`:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

/// Thin static gating wrapper around Sentry. Call sites use this instead of
/// `Sentry.captureException` / `Sentry.addBreadcrumb` directly so the
/// "Send crash reports" opt-out toggle can short-circuit all sends from a
/// single place.
///
/// Initialized to enabled. `main.dart` should call `setEnabled` after reading
/// the persisted flag from Hive, and the Profile screen toggle calls it when
/// the user flips the switch.
class SentryReport {
  SentryReport._();

  static bool _enabled = true;

  /// Whether Sentry sends are currently enabled.
  static bool get isEnabled => _enabled;

  /// Enable or disable Sentry sends at runtime.
  static void setEnabled(bool value) {
    _enabled = value;
  }

  /// Reports an exception to Sentry if enabled, otherwise no-op.
  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
  }) async {
    if (!_enabled) return;
    try {
      await Sentry.captureException(error, stackTrace: stackTrace);
    } catch (_) {
      // Never let Sentry's own failures bubble up.
    }
  }

  /// Adds a breadcrumb if enabled, otherwise no-op.
  static void addBreadcrumb({
    required String category,
    required String message,
    Map<String, Object?>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    if (!_enabled) return;
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: category,
          message: message,
          data: data,
          level: level,
        ),
      );
    } catch (_) {
      // Never let Sentry's own failures bubble up.
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/unit/core/observability/sentry_report_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/observability/sentry_report.dart test/unit/core/observability/sentry_report_test.dart
git commit -m "feat(core): add SentryReport gating wrapper (PR 5)"
```

---

## Task 7: Sentry init helper + `main.dart` restructure

**Files:**
- Create: `lib/core/observability/sentry_init.dart`
- Modify: `lib/main.dart`
- Modify: `lib/core/device/platform_info.dart` (add `initAppVersion`)

- [ ] **Step 1: Add package_info_plus dependency for app version**

```bash
export PATH="/c/flutter/bin:$PATH"
flutter pub add package_info_plus
```

Expected: pubspec.yaml updated with `package_info_plus`.

- [ ] **Step 2: Add initAppVersion to platform_info.dart**

Edit `lib/core/device/platform_info.dart`. Add at the top:

```dart
import 'package:package_info_plus/package_info_plus.dart';
```

Add this function at the bottom of the file:

```dart
/// Reads the app version from the platform and caches it for later retrieval.
/// Call once at app boot, before any analytics insert.
Future<void> initAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    _cachedAppVersion = '${info.version}+${info.buildNumber}';
  } catch (_) {
    _cachedAppVersion = null;
  }
}
```

- [ ] **Step 3: Create sentry_init.dart**

Create `lib/core/observability/sentry_init.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regex matching UUID-like segments in paths, for route sanitization.
final _uuidInPath = RegExp(
  r'/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// Initializes Sentry if `SENTRY_DSN` is set in dotenv. Otherwise runs
/// `appRunner` directly (dev builds, tests, and any build where the DSN
/// has not been injected by CI).
///
/// Strict PII posture:
/// - `sendDefaultPii: false` — no IP, no auto-captured user info
/// - `tracesSampleRate: 0.0` — no performance tracing for MVP
/// - `beforeSend` sets only the Supabase user_id on the event
/// - `beforeBreadcrumb` drops breadcrumbs containing email-like strings
Future<void> initSentryAndRun(Future<void> Function() appRunner) async {
  final dsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (dsn.isEmpty) {
    // No DSN — skip init entirely. Dev builds and tests take this path.
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.environment = kReleaseMode ? 'prod' : 'dev';
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0.0;
      options.attachScreenshot = false;
      options.enableAutoPerformanceTracing = false;

      options.beforeSend = (event, hint) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          return event.copyWith(user: SentryUser(id: userId));
        }
        return event.copyWith(user: null);
      };

      options.beforeBreadcrumb = (crumb, hint) {
        if (crumb == null) return null;
        final msg = crumb.message ?? '';
        if (msg.contains('@')) return null;
        return crumb;
      };
    },
    appRunner: () async {
      await appRunner();
    },
  );
}

/// Route name extractor for [SentryNavigatorObserver] that replaces UUIDs in
/// paths with `:id` so user/workout/routine IDs don't leak into breadcrumbs.
RouteSettings sanitizeRouteName(RouteSettings? settings) {
  final name = settings?.name;
  if (name == null) return settings ?? const RouteSettings();
  final scrubbed = name.replaceAll(_uuidInPath, '/:id');
  if (scrubbed == name) return settings!;
  return RouteSettings(name: scrubbed, arguments: settings!.arguments);
}
```

- [ ] **Step 4: Restructure main.dart**

Replace the contents of `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/device/platform_info.dart';
import 'core/local_storage/hive_service.dart';
import 'core/observability/sentry_init.dart';
import 'core/observability/sentry_report.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await const HiveService().init();
  await initAppVersion();

  // Seed the Sentry opt-out flag from Hive BEFORE init. If the user has
  // disabled crash reports in a prior session, we respect that immediately.
  final prefs = Hive.box(HiveService.userPrefs);
  final crashReportsEnabled =
      prefs.get('crash_reports_enabled', defaultValue: true) as bool;
  SentryReport.setEnabled(crashReportsEnabled);

  await initSentryAndRun(() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    runApp(const ProviderScope(child: App()));
  });
}
```

- [ ] **Step 5: Run analyze**

```bash
dart analyze lib/main.dart lib/core/observability/
```

Expected: no issues.

- [ ] **Step 6: Run full test suite to confirm nothing regressed**

```bash
flutter test
```

Expected: all tests pass (no Sentry DSN in test env → initSentryAndRun takes the skip path).

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/core/observability/sentry_init.dart lib/core/device/platform_info.dart pubspec.yaml pubspec.lock
git commit -m "feat(core): wire SentryFlutter.init with strict PII scrubbing (PR 5)"
```

---

## Task 8: Wire Sentry capture into `BaseRepository`

**Files:**
- Modify: `lib/core/data/base_repository.dart`

- [ ] **Step 1: Read base_repository.dart to locate the catch site**

```bash
cat lib/core/data/base_repository.dart
```

Find the `mapException<T>` method's catch block where `AppException`s are either re-thrown or mapped via `ErrorMapper.mapException(e)`.

- [ ] **Step 2: Add SentryReport.captureException at the catch site**

In `lib/core/data/base_repository.dart`, add at the top:

```dart
import '../observability/sentry_report.dart';
```

Modify the `mapException<T>` method. The pattern should be: after catching a non-AppException (i.e. a raw Supabase/network/system error) and just before mapping/re-throwing it, call:

```dart
} catch (e, st) {
  if (e is AppException) {
    // AppExceptions are expected business errors — do not report.
    rethrow;
  }
  // Unexpected error from the data layer — capture before mapping.
  unawaited(SentryReport.captureException(e, stackTrace: st));
  throw ErrorMapper.mapException(e);
}
```

Add the `dart:async` import if not already present (for `unawaited`):

```dart
import 'dart:async';
```

The full catch block now reads:
1. Catch the error
2. If it's already an `AppException`, rethrow unchanged (avoids double-reporting bubbled domain errors)
3. Otherwise fire-and-forget `SentryReport.captureException` and throw the mapped `AppException`

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/core/data/base_repository.dart
```

Expected: no issues.

- [ ] **Step 4: Run all base_repository tests**

```bash
flutter test test/unit/core/data/
```

Expected: existing tests still pass. `SentryReport.captureException` is a no-op in the test environment (DSN empty, or Sentry not initialized), so tests don't need updates.

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/base_repository.dart
git commit -m "feat(core): capture unexpected repo errors to Sentry (PR 5)"
```

---

## Task 9: Add `SentryNavigatorObserver` to GoRouter

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/core/router/app_router.dart`, add:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

import '../observability/sentry_init.dart' show sanitizeRouteName;
```

- [ ] **Step 2: Add observers to GoRouter constructor**

Find the `GoRouter(...)` constructor call (around line 35 per the explorer report). Insert an `observers:` argument between `refreshListenable:` and `redirect:`:

```dart
return GoRouter(
  // ... existing args (initialLocation, navigatorKey, etc.) ...
  refreshListenable: refreshListenable,
  observers: [
    SentryNavigatorObserver(
      enableAutoTransactions: false,      // no performance tracing
      setRouteNameAsTransaction: false,
      routeNameExtractor: sanitizeRouteName,
    ),
  ],
  redirect: (context, state) { /* ... */ },
  routes: [ /* ... */ ],
);
```

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/core/router/app_router.dart
```

Expected: no issues.

- [ ] **Step 4: Run existing router/widget tests**

```bash
flutter test test/widget/
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(core): add SentryNavigatorObserver with UUID scrubbing (PR 5)"
```

---

## Task 10: Crash reports opt-out provider (Hive-backed)

**Files:**
- Create: `lib/features/profile/providers/crash_reports_enabled_provider.dart`
- Create: `test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/core/observability/sentry_report.dart';
import 'package:gymbuddy_app/features/profile/providers/crash_reports_enabled_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../helpers/fake_path_provider.dart';

void main() {
  setUpAll(() async {
    // Use a fake path provider so Hive can init in tests.
    PathProviderPlatform.instance = FakePathProviderPlatform();
    await Hive.initFlutter();
    await Hive.openBox(HiveService.userPrefs);
  });

  setUp(() async {
    // Clear the prefs box before every test.
    await Hive.box(HiveService.userPrefs).clear();
    SentryReport.setEnabled(true);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('default value is true when Hive has no entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(crashReportsEnabledProvider), true);
  });

  test('reads persisted false from Hive', () async {
    await Hive.box(HiveService.userPrefs).put('crash_reports_enabled', false);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(crashReportsEnabledProvider), false);
  });

  test('setting to false persists and updates SentryReport', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(crashReportsEnabledProvider.notifier)
        .setEnabled(false);

    expect(container.read(crashReportsEnabledProvider), false);
    expect(
      Hive.box(HiveService.userPrefs).get('crash_reports_enabled'),
      false,
    );
    expect(SentryReport.isEnabled, false);
  });

  test('setting to true persists and updates SentryReport', () async {
    await Hive.box(HiveService.userPrefs).put('crash_reports_enabled', false);
    SentryReport.setEnabled(false);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(crashReportsEnabledProvider.notifier)
        .setEnabled(true);

    expect(container.read(crashReportsEnabledProvider), true);
    expect(SentryReport.isEnabled, true);
  });
}
```

- [ ] **Step 2: Create the fake path provider helper (if not already present)**

Check if `test/helpers/fake_path_provider.dart` exists:

```bash
ls test/helpers/fake_path_provider.dart 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

If MISSING, create `test/helpers/fake_path_provider.dart`:

```dart
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.dart_tool/test/hive_test_temp';
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return '.dart_tool/test/hive_test_temp';
  }

  @override
  Future<String?> getTemporaryPath() async {
    return '.dart_tool/test/hive_test_temp';
  }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
flutter test test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart
```

Expected: FAIL with "target of URI doesn't exist: `crash_reports_enabled_provider.dart`"

- [ ] **Step 4: Implement the provider**

Create `lib/features/profile/providers/crash_reports_enabled_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/local_storage/hive_service.dart';
import '../../../core/observability/sentry_report.dart';

const _hiveKey = 'crash_reports_enabled';

/// Notifier for the "Send crash reports" user preference. Backed by the
/// `user_prefs` Hive box. Defaults to `true` (opt-out, not opt-in).
///
/// Setting the value persists immediately and updates [SentryReport] so the
/// change takes effect for all subsequent captures and breadcrumbs.
class CrashReportsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box(HiveService.userPrefs);
    final value = box.get(_hiveKey, defaultValue: true) as bool;
    return value;
  }

  Future<void> setEnabled(bool enabled) async {
    final box = Hive.box(HiveService.userPrefs);
    await box.put(_hiveKey, enabled);
    SentryReport.setEnabled(enabled);
    state = enabled;
  }
}

final crashReportsEnabledProvider =
    NotifierProvider<CrashReportsEnabledNotifier, bool>(
  CrashReportsEnabledNotifier.new,
);
```

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/providers/crash_reports_enabled_provider.dart test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart test/helpers/fake_path_provider.dart
git commit -m "feat(profile): add crash reports opt-out provider (PR 5)"
```

---

## Task 11: Crash reports toggle UI in Profile screen

**Files:**
- Modify: `lib/features/profile/ui/profile_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/features/profile/ui/profile_screen.dart`, add:

```dart
import '../providers/crash_reports_enabled_provider.dart';
```

- [ ] **Step 2: Add PRIVACY section before the Logout button**

Find the existing section layout (DATA MANAGEMENT, LEGAL per explorer report). Between LEGAL and the logout button, add a new PRIVACY section:

```dart
// ----- PRIVACY SECTION -----
Text(
  'PRIVACY',
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.55),
        letterSpacing: 1.2,
      ),
),
const SizedBox(height: 8),
Material(
  color: Theme.of(context).colorScheme.surfaceContainerLow,
  borderRadius: BorderRadius.circular(12),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Send crash reports'),
      subtitle: const Text(
        'Help improve GymBuddy by sending anonymous crash data.',
      ),
      value: ref.watch(crashReportsEnabledProvider),
      onChanged: (value) {
        ref
            .read(crashReportsEnabledProvider.notifier)
            .setEnabled(value);
      },
    ),
  ),
),
const SizedBox(height: 24),
```

Match the exact card surface color and border radius used in the existing DATA MANAGEMENT / LEGAL sections (the explorer noted the pattern). If the existing sections use a different color constant, use that instead of `surfaceContainerLow`.

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/features/profile/ui/profile_screen.dart
```

Expected: no issues.

- [ ] **Step 4: Run existing profile widget tests**

```bash
flutter test test/widget/features/profile/
```

Expected: all pass (no new widget test for this toggle — verified manually on the device).

- [ ] **Step 5: Manual smoke check**

```bash
flutter run -d chrome
```

Navigate to Profile → scroll to PRIVACY → toggle "Send crash reports" off and on. Kill the app and re-run; verify the toggle state persists.

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/ui/profile_screen.dart
git commit -m "feat(profile): add Send crash reports toggle in Privacy section (PR 5)"
```

---

## Task 12: Privacy policy edits (both files)

**Files:**
- Modify: `assets/legal/privacy_policy.md`
- Modify: `docs/privacy_policy.md`

- [ ] **Step 1: Update assets/legal/privacy_policy.md**

Edit `assets/legal/privacy_policy.md`:

**Change 1** — Line 3 (date):
```
**Last updated: 2026-04-10**
```
Bump to today's date (the PR merge date — use today's calendar date in YYYY-MM-DD).

**Change 2** — Line 13 (Section 2 opening claim): Replace

```
We collect only the information you provide directly. GymBuddy does not use tracking SDKs, advertising identifiers, or analytics services that share data with third parties.
```

with:

```
We collect only the information you provide directly and a small number of in-app events used to improve the App (see "Usage Events" below). GymBuddy does not use advertising SDKs, ad networks, or analytics services that share your data with advertisers. We use Sentry to receive crash reports when the App encounters an unhandled error — see Section 5.
```

**Change 3** — Add new "Usage Events" subsection after the "Fitness Data" subsection (around line 30). Insert:

```
### Usage Events

To understand how the App is used and improve reliability, we log a small set of in-app events (for example: when you sign up, finish a workout, or set a personal record) to our own database alongside your other data. These events record the action and its basic parameters (e.g. workout duration, exercise count). They never contain your email address, display name, workout notes, or any free-text input. These events are tied to your account and deleted when you delete your account.
```

**Change 4** — Section 3 line 33, soften:

From:

```
All information is collected directly from the App based on actions you take (signing up, logging workouts, editing your profile, etc.). We do not track your location, device activity, or usage patterns outside of the features required to provide the service.
```

To:

```
All information is collected directly from the App based on actions you take (signing up, logging workouts, editing your profile, etc.). We do not track your location or device activity. The usage events described in Section 2 are collected to improve the App and are the only form of usage tracking.
```

**Change 5** — Section 5 "Third Parties", add Sentry as a processor. Replace:

```
GymBuddy uses the following third-party services:

- **Supabase** — hosting, authentication, and database.
- **Google** — OAuth authentication only, if you choose to sign in with Google.

We do **not** use advertising networks. We do **not** sell your data. We do **not** share your fitness data with insurers, employers, or anyone else.
```

with:

```
GymBuddy uses the following third-party services:

- **Supabase** — hosting, authentication, and database.
- **Google** — OAuth authentication only, if you choose to sign in with Google.
- **Sentry** — crash reporting only. When the App encounters an unhandled error, a stack trace, the environment (OS, app version), and your account ID (no email, no name, no IP address) are sent to sentry.io so we can diagnose and fix the bug. You can disable this at any time in **Profile → Privacy → Send crash reports**. For Sentry's own policies, see [sentry.io/privacy](https://sentry.io/privacy/).

We do **not** use advertising networks. We do **not** sell your data. We do **not** share your fitness data with insurers, employers, or anyone else.
```

- [ ] **Step 2: Apply the same edits to docs/privacy_policy.md**

Mirror the 5 changes above to `docs/privacy_policy.md`. **IMPORTANT:** preserve the Jekyll front-matter at the top of the file (the `---\ntitle: ...\nlayout: ...\n---` block). Do NOT remove or modify it.

- [ ] **Step 3: Run a diff sanity check**

```bash
diff <(sed -n '/^# Privacy Policy/,$p' docs/privacy_policy.md) assets/legal/privacy_policy.md
```

Expected: no differences in the body content (everything after `# Privacy Policy` in docs/ should match assets/).

- [ ] **Step 4: Commit**

```bash
git add assets/legal/privacy_policy.md docs/privacy_policy.md
git commit -m "docs(core): disclose Sentry + usage events in privacy policy (PR 5)"
```

---

## Task 13: Event wire — `onboarding_completed`

**Files:**
- Modify: `lib/features/auth/ui/onboarding_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/features/auth/ui/onboarding_screen.dart`, add:

```dart
import '../../../core/device/platform_info.dart';
import '../../analytics/data/models/analytics_event.dart';
import '../../analytics/providers/analytics_providers.dart';
```

- [ ] **Step 2: Fire event in _finishOnboarding after successful save**

In `_finishOnboarding()`, after the call to `saveOnboardingProfile(...)` succeeds and before `context.go('/home')`, add:

```dart
// Fire analytics — best-effort, not awaited so it can't block navigation.
final userId = ref.read(authRepositoryProvider).currentUser?.id;
if (userId != null) {
  unawaited(
    ref.read(analyticsRepositoryProvider).insertEvent(
          userId: userId,
          event: AnalyticsEvent.onboardingCompleted(
            fitnessLevel: _fitnessLevel,
            trainingFrequency: _trainingFrequency,
          ),
          platform: currentPlatform(),
          appVersion: currentAppVersion(),
        ),
  );
}
```

Add `import 'dart:async';` at the top if not already present (for `unawaited`). Add `import '../providers/auth_providers.dart';` if not already imported (for `authRepositoryProvider`).

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/features/auth/ui/onboarding_screen.dart
```

Expected: no issues.

- [ ] **Step 4: Run existing onboarding tests**

```bash
flutter test test/widget/features/auth/
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/ui/onboarding_screen.dart
git commit -m "feat(auth): fire onboarding_completed analytics event (PR 5)"
```

---

## Task 14: Event wire — workout lifecycle (3 events + breadcrumbs)

**Files:**
- Modify: `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`

This task wires `workout_started` (2 entry points), `workout_discarded`, `workout_finished`, and lifecycle breadcrumbs into the ActiveWorkoutNotifier.

- [ ] **Step 1: Add imports**

At the top of `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`, add:

```dart
import '../../../../core/device/platform_info.dart';
import '../../../../core/observability/sentry_report.dart';
import '../../../analytics/data/models/analytics_event.dart';
import '../../../analytics/providers/analytics_providers.dart';
```

Add `import 'dart:async';` if not already present.

- [ ] **Step 2: Add a private analytics helper**

Add this private method near the bottom of the notifier class (before the closing brace):

```dart
/// Fire-and-forget analytics event + Sentry breadcrumb for this workout.
///
/// Takes the event, an optional breadcrumb message + data for Sentry, and
/// returns nothing. Never throws — both calls are guarded.
void _trackWorkoutEvent({
  required AnalyticsEvent event,
  required String breadcrumbMessage,
  Map<String, Object?>? breadcrumbData,
}) {
  // Analytics (always sent — first-party, no opt-out)
  unawaited(
    ref.read(analyticsRepositoryProvider).insertEvent(
          userId: _userId,
          event: event,
          platform: currentPlatform(),
          appVersion: currentAppVersion(),
        ),
  );
  // Sentry breadcrumb (gated by SentryReport.isEnabled)
  SentryReport.addBreadcrumb(
    category: 'workout',
    message: breadcrumbMessage,
    data: breadcrumbData,
  );
}
```

Note: `_userId` is the notifier's existing private field for the current Supabase user id. If the field name differs, match the existing field.

- [ ] **Step 3: Fire workout_started in startWorkout (empty path)**

Find `startWorkout([String? name])` (around line 64). After `final workout = await _repo.createActiveWorkout(...)` succeeds, and before `state = ...`, add:

```dart
_trackWorkoutEvent(
  event: const AnalyticsEvent.workoutStarted(
    source: 'empty',
    routineId: null,
    exerciseCount: 0,
    hadActiveWorkoutConflict: false,
  ),
  breadcrumbMessage: 'started empty workout',
  breadcrumbData: {'workout_id': workout.id},
);
```

- [ ] **Step 4: Fire workout_started in startFromRoutine**

Find `startFromRoutine(RoutineStartConfig config)` (around line 82). After `final workout = await _repo.createActiveWorkout(...)` succeeds and before applying the prefilled sets, add:

```dart
_trackWorkoutEvent(
  event: AnalyticsEvent.workoutStarted(
    source: config.fromWeeklyPlan == true ? 'planned_bucket' : 'routine_card',
    routineId: config.routineId,
    exerciseCount: config.exercises.length,
    hadActiveWorkoutConflict: false,
  ),
  breadcrumbMessage: 'started workout from routine',
  breadcrumbData: {
    'workout_id': workout.id,
    'routine_id': config.routineId,
  },
);
```

NOTE: If `RoutineStartConfig` does not have a `fromWeeklyPlan` field, use `'routine_card'` unconditionally for this task and open a follow-up to add the `planned_bucket` source in a future PR. Do NOT invent a field that doesn't exist — check the config model first (`lib/features/workouts/models/routine_start_config.dart`).

- [ ] **Step 5: Fire workout_discarded in discardWorkout**

Find `discardWorkout()` (around line 501). At the very start of the method (before any state mutation), capture the current values for the event:

```dart
final current = state.active;
if (current != null) {
  final elapsed = DateTime.now().difference(current.startedAt).inSeconds;
  final completedSets = current.exercises
      .expand((e) => e.sets)
      .where((s) => s.completed)
      .length;
  final source = current.routineId != null ? 'routine_card' : 'empty';
  _trackWorkoutEvent(
    event: AnalyticsEvent.workoutDiscarded(
      elapsedSeconds: elapsed,
      completedSets: completedSets,
      exerciseCount: current.exercises.length,
      source: source,
    ),
    breadcrumbMessage: 'discarded workout',
    breadcrumbData: {'workout_id': current.id},
  );
}
```

NOTE: field names (`startedAt`, `exercises`, `sets`, `completed`, `routineId`) must match the actual `ActiveWorkoutState` model. If any differs, use the real field name — verify against `lib/features/workouts/models/active_workout_state.dart` before coding.

- [ ] **Step 6: Fire workout_finished in finishWorkout**

Find `finishWorkout({String? notes})` (around line 514). Per the explorer report, `workoutCount` is already computed around line 562 for PR detection — reuse it. After `workoutCount` is computed and before the method returns, add:

```dart
// Analytics — fire after save succeeds, reuse workoutCount from PR detection.
final completedSets =
    sets.where((s) => s.completed).length; // `sets` and completion field
final incompleteSetsSkipped = sets.length - completedSets;
final hadPr = prResult.newRecords.isNotEmpty;
final source = current.routineId != null
    ? 'routine_card'   // TODO post-PR: differentiate planned_bucket
    : 'empty';
_trackWorkoutEvent(
  event: AnalyticsEvent.workoutFinished(
    durationSeconds: durationSeconds,
    exerciseCount: exercises.length,
    totalSets: sets.length,
    completedSets: completedSets,
    incompleteSetsSkipped: incompleteSetsSkipped,
    hadPr: hadPr,
    source: source,
    workoutNumber: workoutCount,
  ),
  breadcrumbMessage: 'finished workout',
  breadcrumbData: {
    'workout_id': current.id,
    'workout_number': workoutCount,
    'had_pr': hadPr,
  },
);
```

Adapt the variable names (`sets`, `exercises`, `prResult`, `durationSeconds`, `current`, `workoutCount`) to match the actual in-scope variables of `finishWorkout` based on the explorer's notes. The explorer confirmed:
- `workoutCount` is already available after line 562
- `exercises.length`, `sets.length`, `durationSeconds` are in scope
- `current.routineId` is accessed at line 595

- [ ] **Step 7: Run analyze**

```bash
dart analyze lib/features/workouts/providers/notifiers/active_workout_notifier.dart
```

Expected: no issues. If there are name mismatches, fix them using the real field names.

- [ ] **Step 8: Run existing workout notifier tests**

```bash
flutter test test/unit/features/workouts/
flutter test test/widget/features/workouts/
```

Expected: all pass. Existing tests don't mock the analytics provider, but since `insertEvent` is fire-and-forget (try/catch) and `SentryReport` is a no-op when disabled, the extra calls should not break anything. If any test DOES break, it's because the test constructs the notifier without a proper `ref` — in that case, override `analyticsRepositoryProvider` in the test's `ProviderContainer` with a no-op fake.

- [ ] **Step 9: Commit**

```bash
git add lib/features/workouts/providers/notifiers/active_workout_notifier.dart
git commit -m "feat(workouts): fire workout lifecycle analytics + breadcrumbs (PR 5)"
```

---

## Task 15: Event wire — `pr_celebration_seen` + `add_to_plan_prompt_responded`

**Files:**
- Modify: `lib/features/personal_records/ui/pr_celebration_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/features/personal_records/ui/pr_celebration_screen.dart`, add:

```dart
import 'dart:async';

import '../../../core/device/platform_info.dart';
import '../../analytics/data/models/analytics_event.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
```

- [ ] **Step 2: Fire pr_celebration_seen in initState**

In the State class's `initState()` method (around line 47 per the explorer), at the very end (after the existing animation + haptic setup), add:

```dart
// Fire pr_celebration_seen — once per mount.
WidgetsBinding.instance.addPostFrameCallback((_) {
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return;
  final recordTypes = widget.result.newRecords
      .map((r) => _recordTypeToString(r.recordType))
      .toList();
  unawaited(
    ref.read(analyticsRepositoryProvider).insertEvent(
          userId: userId,
          event: AnalyticsEvent.prCelebrationSeen(
            isFirstWorkout: widget.result.isFirstWorkout,
            prCount: widget.result.newRecords.length,
            recordTypes: recordTypes,
          ),
          platform: currentPlatform(),
          appVersion: currentAppVersion(),
        ),
  );
});
```

Add the enum-to-string helper at the bottom of the State class (before the closing brace):

```dart
static String _recordTypeToString(RecordType type) {
  switch (type) {
    case RecordType.maxWeight:
      return 'max_weight';
    case RecordType.maxReps:
      return 'max_reps';
    case RecordType.maxVolume:
      return 'max_volume';
  }
}
```

If the `RecordType` enum is not yet imported in this file, add the import:

```dart
import '../models/personal_record.dart';
```

- [ ] **Step 3: Fire add_to_plan_prompt_responded in _onContinue**

Find `_onContinue()` (around line 84). After the `await showAddToPlanPrompt(...)` call resolves (`shouldAdd` is `true | false | null`), and BEFORE the existing `if (shouldAdd == true)` branch, add:

```dart
// Fire analytics — measure the prompt's conversion funnel.
if (widget.planPromptRoutineId != null) {
  final action = shouldAdd == true
      ? 'added'
      : shouldAdd == false
          ? 'skipped'
          : 'dismissed';
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId != null) {
    unawaited(
      ref.read(analyticsRepositoryProvider).insertEvent(
            userId: userId,
            event: AnalyticsEvent.addToPlanPromptResponded(
              action: action,
              trigger: 'pr_celebration_continue',
              routineId: widget.planPromptRoutineId!,
            ),
            platform: currentPlatform(),
            appVersion: currentAppVersion(),
          ),
    );
  }
}
```

- [ ] **Step 4: Run analyze**

```bash
dart analyze lib/features/personal_records/ui/pr_celebration_screen.dart
```

Expected: no issues.

- [ ] **Step 5: Run existing PR tests**

```bash
flutter test test/unit/features/personal_records/
flutter test test/widget/features/personal_records/
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/personal_records/ui/pr_celebration_screen.dart
git commit -m "feat(personal_records): fire pr_celebration_seen + add_to_plan_prompt_responded (PR 5)"
```

---

## Task 16: Event wire — `week_plan_saved` with context

**Files:**
- Modify: `lib/features/weekly_plan/ui/plan_management_screen.dart`

The explorer flagged that `_savePlan()` is context-free. This task refactors it to accept a reason + autofill + replaced flag, and fires `week_plan_saved` from inside with the context.

- [ ] **Step 1: Add imports**

At the top of `lib/features/weekly_plan/ui/plan_management_screen.dart`, add:

```dart
import 'dart:async';

import '../../../core/device/platform_info.dart';
import '../../analytics/data/models/analytics_event.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../auth/providers/auth_providers.dart';
```

- [ ] **Step 2: Refactor _savePlan to accept context + fire analytics**

Replace the existing `_savePlan()` method with:

```dart
void _savePlan({
  required bool usedAutofill,
  required bool replacedExisting,
}) {
  ref.read(weeklyPlanProvider.notifier).upsertPlan(_bucketRoutines);

  // Fire analytics after initiating the save. We do not await the upsert —
  // analytics is best-effort and the UI must remain responsive.
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return;
  final trainingFrequency =
      ref.read(profileProvider).valueOrNull?.trainingFrequencyPerWeek ?? 3;
  unawaited(
    ref.read(analyticsRepositoryProvider).insertEvent(
          userId: userId,
          event: AnalyticsEvent.weekPlanSaved(
            routineCount: _bucketRoutines.length,
            atSoftCap: _bucketRoutines.length >= trainingFrequency,
            usedAutofill: usedAutofill,
            replacedExisting: replacedExisting,
          ),
          platform: currentPlatform(),
          appVersion: currentAppVersion(),
        ),
  );
}
```

- [ ] **Step 3: Update all call sites of _savePlan**

Find every call to `_savePlan()` in the file (explorer listed `_onReorder`, `_removeRoutine`, `_showAddSheet`, `_autoFill`). Update each:

- In `_onReorder`: `_savePlan(usedAutofill: false, replacedExisting: false);`
- In `_removeRoutine` (both the call and the undo callback): `_savePlan(usedAutofill: false, replacedExisting: false);`
- In `_showAddSheet` (after adding): `_savePlan(usedAutofill: false, replacedExisting: false);`
- In `_autoFill`: `_savePlan(usedAutofill: true, replacedExisting: _bucketRoutines.isNotEmpty);`
  - Capture `_bucketRoutines.isNotEmpty` BEFORE the autofill mutation, so `replacedExisting` reflects the prior state. Example:
    ```dart
    final wasNotEmpty = _bucketRoutines.isNotEmpty;
    setState(() {
      _bucketRoutines = ...autofilled;
    });
    _savePlan(usedAutofill: true, replacedExisting: wasNotEmpty);
    ```

- [ ] **Step 4: Run analyze**

```bash
dart analyze lib/features/weekly_plan/ui/plan_management_screen.dart
```

Expected: no issues.

- [ ] **Step 5: Run existing weekly plan tests**

```bash
flutter test test/unit/features/weekly_plan/
flutter test test/widget/features/weekly_plan/
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/weekly_plan/ui/plan_management_screen.dart
git commit -m "feat(weekly_plan): fire week_plan_saved with source context (PR 5)"
```

---

## Task 17: Event wire — `week_complete` on transition

**Files:**
- Modify: `lib/features/weekly_plan/providers/weekly_plan_provider.dart`

The explorer flagged that `WeekReviewSection` is stateless and firing from `build()` would double-fire. The right hook is `markRoutineComplete` in the notifier, which has `ref` access and knows the before/after state.

- [ ] **Step 1: Add imports**

At the top of `lib/features/weekly_plan/providers/weekly_plan_provider.dart`, add:

```dart
import '../../../core/device/platform_info.dart';
import '../../analytics/data/models/analytics_event.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../personal_records/providers/personal_records_providers.dart' show prListProvider;
```

NOTE: The `prListProvider` (or equivalent) must return the current user's personal records so we can count PRs for this week. If the name differs, use the real provider from `lib/features/personal_records/providers/`.

- [ ] **Step 2: Fire week_complete in markRoutineComplete after success**

In `WeeklyPlanNotifier.markRoutineComplete(...)`, after the `state = await AsyncValue.guard(...)` assignment, add:

```dart
// Detect transition to all-complete and fire week_complete event once.
final newPlan = state.valueOrNull;
if (newPlan == null) return;
final wasAllComplete = plan.routines.isNotEmpty &&
    plan.routines.every((r) => r.completedWorkoutId != null);
final isNowAllComplete = newPlan.routines.isNotEmpty &&
    newPlan.routines.every((r) => r.completedWorkoutId != null);
if (!wasAllComplete && isNowAllComplete) {
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId != null) {
    // Count PRs this week from the PR list (current user).
    final prsAsync = ref.read(prListProvider);
    final weekStart = newPlan.weekStart;
    final weekEnd = weekStart.add(const Duration(days: 7));
    final prCountThisWeek = prsAsync.valueOrNull
            ?.where((pr) =>
                pr.achievedAt.isAfter(weekStart) &&
                pr.achievedAt.isBefore(weekEnd))
            .length ??
        0;
    // Week number = ISO weeks since user's signup (derive from created_at
    // in auth.users; if not cheaply available, fallback to 0 and let the
    // SQL query compute it later).
    const weekNumber = 0; // TODO post-PR: compute from currentUser.createdAt
    unawaited(
      ref.read(analyticsRepositoryProvider).insertEvent(
            userId: userId,
            event: AnalyticsEvent.weekComplete(
              sessionsCompleted: newPlan.routines
                  .where((r) => r.completedWorkoutId != null)
                  .length,
              prCountThisWeek: prCountThisWeek,
              planSize: newPlan.routines.length,
              weekNumber: weekNumber,
            ),
            platform: currentPlatform(),
            appVersion: currentAppVersion(),
          ),
    );
  }
}
```

Add `import 'dart:async';` at the top if not present (for `unawaited`).

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/features/weekly_plan/providers/weekly_plan_provider.dart
```

Expected: no issues. If `prListProvider` has a different name, use the real name. If no PR provider exists at the right granularity, set `prCountThisWeek = 0` with a TODO and proceed — we can compute PR counts in SQL from the `pr_celebration_seen` events later.

- [ ] **Step 4: Run existing tests**

```bash
flutter test test/unit/features/weekly_plan/
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/weekly_plan/providers/weekly_plan_provider.dart
git commit -m "feat(weekly_plan): fire week_complete on all-routines-completed transition (PR 5)"
```

---

## Task 18: Event wire — `account_deleted` + auth breadcrumbs

**Files:**
- Modify: `lib/features/auth/providers/notifiers/auth_notifier.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/features/auth/providers/notifiers/auth_notifier.dart`, add:

```dart
import 'dart:async';

import '../../../../core/device/platform_info.dart';
import '../../../../core/observability/sentry_report.dart';
import '../../../analytics/data/models/analytics_event.dart';
import '../../../analytics/providers/analytics_providers.dart';
```

- [ ] **Step 2: Add breadcrumbs to signUpWithEmail**

In `signUpWithEmail(...)` (around line 20), after the call to the repo succeeds and before the state assignment, add:

```dart
SentryReport.addBreadcrumb(
  category: 'auth',
  message: 'sign_up_email',
);
```

- [ ] **Step 3: Add breadcrumbs to signInWithEmail**

In `signInWithEmail(...)` (around line 38), after the repo call succeeds, add:

```dart
SentryReport.addBreadcrumb(
  category: 'auth',
  message: 'sign_in_email',
);
```

- [ ] **Step 4: Add breadcrumbs to signInWithGoogle**

In `signInWithGoogle(...)` (around line 52), after the guard resolves, add:

```dart
SentryReport.addBreadcrumb(
  category: 'auth',
  message: 'sign_in_google',
);
```

- [ ] **Step 5: Add breadcrumbs to signOut**

In `signOut(...)` (around line 61), after the `_repo.signOut()` call succeeds and before the state assignment, add:

```dart
SentryReport.addBreadcrumb(
  category: 'auth',
  message: 'sign_out',
);
```

- [ ] **Step 6: Fire account_deleted in deleteAccount before sign-out**

In `deleteAccount()` (around line 100), the flow per the explorer is:
1. Call `_repo.deleteAccount()`
2. If it succeeds, call `_repo.signOut()` (swallowing errors)
3. Set state to `const AsyncData(null)`

Insert the event fire between steps 1 and 2, ONLY if the delete succeeded (check `state.hasError` is false — per the explorer, the notifier already does this check around line 107):

```dart
// Fire account_deleted BEFORE the sign-out so we still have a valid session.
final user = _repo.currentUser;
if (user != null) {
  // Compute days since signup from the user's created_at timestamp.
  final daysSinceSignup =
      DateTime.now().difference(user.createdAt).inDays;
  // Compute workout count — read from the workout repo if cheap; else 0.
  // The explorer report confirmed getFinishedWorkoutCount exists.
  int workoutCount = 0;
  try {
    final workoutRepo = ref.read(workoutRepositoryProvider);
    workoutCount = await workoutRepo.getFinishedWorkoutCount(user.id);
  } catch (_) {
    // Best-effort — if we can't count, ship a 0.
  }
  // Insert event synchronously (await) — the row must land before the
  // CASCADE DELETE from auth.users drops it.
  try {
    await ref.read(analyticsRepositoryProvider).insertEvent(
          userId: user.id,
          event: AnalyticsEvent.accountDeleted(
            workoutCount: workoutCount,
            daysSinceSignup: daysSinceSignup,
          ),
          platform: currentPlatform(),
          appVersion: currentAppVersion(),
        );
  } catch (_) {
    // Best-effort — never block deletion on analytics.
  }
  SentryReport.addBreadcrumb(
    category: 'auth',
    message: 'account_deleted',
  );
}
```

NOTE: this is the ONE event we must AWAIT (not fire-and-forget), because `ON DELETE CASCADE` on `analytics_events.user_id` will drop the row if we don't land it before the auth.users row is removed. The `try/catch` wraps the await so a failed insert still allows deletion to proceed.

NOTE: `workoutRepositoryProvider` must be imported if not already. If `AuthNotifier` doesn't have easy access to it, add `import '../../../workouts/providers/workout_providers.dart';` or equivalent.

- [ ] **Step 7: Run analyze**

```bash
dart analyze lib/features/auth/providers/notifiers/auth_notifier.dart
```

Expected: no issues. If `_repo.currentUser` doesn't exist, use `Supabase.instance.client.auth.currentUser`. If `user.createdAt` isn't a DateTime, parse it.

- [ ] **Step 8: Run existing auth tests**

```bash
flutter test test/unit/features/auth/
flutter test test/widget/features/auth/
```

Expected: all pass.

- [ ] **Step 9: Commit**

```bash
git add lib/features/auth/providers/notifiers/auth_notifier.dart
git commit -m "feat(auth): fire account_deleted + auth lifecycle breadcrumbs (PR 5)"
```

---

## Task 19: Final verification gate + PR

- [ ] **Step 1: Run full CI locally**

```bash
export PATH="/c/flutter/bin:$PATH"
make ci
```

Expected: format clean, analyze 0 issues, all tests pass. Read the full output; do NOT accept warnings as green.

- [ ] **Step 2: Apply the migration to the local Supabase instance**

```bash
npx supabase db reset  # or `npx supabase db push` if you don't want to wipe
```

Expected: migration `00015_create_analytics_events.sql` applies cleanly. Verify the table exists:

```bash
npx supabase db remote dump --schema public | grep -i analytics_events
```

Expected: the table definition is printed.

- [ ] **Step 3: Verify E2E smoke still works**

Per CLAUDE.md E2E section:

```bash
# 1. Build web from the current branch
flutter build web

# 2. Run smoke suite
cd test/e2e
FLUTTER_APP_URL= npx playwright test --project=smoke --reporter=list
cd ../..
```

Expected: all smoke tests pass. If any failed due to the `weekly_plan_provider` refactor or the `_savePlan` signature change, fix the selectors and re-run.

- [ ] **Step 4: Manual chrome smoke — fire a sample event**

```bash
flutter run -d chrome
```

1. Sign in to your test account
2. Complete a workout (any exercise, 1 set, finish)
3. In a new terminal, query the local Supabase:
   ```bash
   npx supabase db remote commit  # or use the SQL editor at http://localhost:54323
   ```
   Run: `SELECT name, props, platform, app_version FROM analytics_events ORDER BY created_at DESC LIMIT 5;`
4. Verify `workout_started` and `workout_finished` rows exist with correct props.
5. Toggle `Profile → Privacy → Send crash reports` off. Verify `SentryReport.isEnabled` is false (if you can't check in-app, verify by grepping Hive state).

- [ ] **Step 5: Run verification-before-completion skill**

```
Use superpowers:verification-before-completion
```

Re-read PLAN.md B2 + B3 acceptance criteria and check each item against the diff. List any unchecked items and fix before proceeding.

- [ ] **Step 6: Push branch and open PR**

```bash
git push -u origin feature/phase13a-sprintA-pr5-observability
gh pr create --title "feat(observability): Sentry crash reporting + Supabase analytics (PR 5)" --body "$(cat <<'EOF'
## Summary

- Adds first-party product analytics via a new `analytics_events` table (9 must-have events — schema ratified via PO + UX critic review in `tasks/WIP.md`)
- Adds Sentry crash reporting with strict PII scrubbing (`sendDefaultPii: false`, user_id only, email-filter breadcrumbs, UUID-scrubbed route names)
- Adds "Send crash reports" opt-out toggle in Profile → Privacy (Hive-backed, defaults ON)
- Updates privacy policy (both `assets/legal/` and `docs/`) to disclose Sentry + usage events
- Closes PLAN.md Phase 13a Sprint A items B2 and B3

## Event list

onboarding_completed, workout_started, workout_discarded, workout_finished, pr_celebration_seen, week_plan_saved, week_complete, add_to_plan_prompt_responded, account_deleted

## Test plan

- [ ] Unit: `flutter test test/unit/features/analytics/`
- [ ] Unit: `flutter test test/unit/features/profile/providers/crash_reports_enabled_provider_test.dart`
- [ ] Unit: `flutter test test/unit/core/observability/`
- [ ] Full: `make ci`
- [ ] E2E smoke: `FLUTTER_APP_URL= npx playwright test --project=smoke`
- [ ] Manual: fire a workout, verify `workout_started` + `workout_finished` rows land in local Supabase
- [ ] Manual: toggle crash reports off, restart app, verify `SentryReport.isEnabled == false`
- [ ] Privacy policy: both `assets/legal/privacy_policy.md` and `docs/privacy_policy.md` updated in sync

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7: Post-merge (do NOT do during this PR)**

After the PR merges to main per the CLAUDE.md workflow:
1. Apply migration to hosted Supabase: `npx supabase db push`
2. Inject `SENTRY_DSN` into CI release pipeline secrets
3. Install Sentry's GitHub integration + configure alert rule "seen 25+ times AND 5+ users in 24h → create GitHub issue with labels bug, sentry, triage"
4. Update `tasks/WIP.md` (remove PR 5 section)
5. Condense PLAN.md B2 + B3 entries

---

## Self-review checklist (do this before running Task 19)

**1. Spec coverage (tasks/WIP.md PR 5 design decisions):**
- [x] Q1 — Supabase-native analytics_events table (Task 1, Task 3)
- [x] Q2 — `.env` with empty-DSN-skips-init (Task 5, Task 7)
- [x] Q3a — Strict Sentry scrubbing (Task 7: sendDefaultPii false, beforeSend user_id only, beforeBreadcrumb @ filter)
- [x] Q3b — One opt-out toggle for Sentry, default ON (Task 10, Task 11)
- [x] Q3c — Targeted privacy policy edits both files (Task 12)
- [x] Q4 — 9 events with typed props (Task 2 + Tasks 13-18)
- [x] Q4a — platform + app_version as table columns (Task 1 migration, Task 3 repo, Task 4 platform helper)
- [x] Q5 — Tier 1 foundation (Task 7), Tier 2 BaseRepository (Task 8), Tier 3 breadcrumbs (Tasks 9, 14, 18)
- [x] Q5a — Route sanitization via routeNameExtractor + beforeBreadcrumb (Task 7, Task 9)

**2. Placeholder scan:**
- Several NOTE blocks in Tasks 14, 17, 18 flag fields that may not match exactly (`fromWeeklyPlan`, `prListProvider`, `_repo.currentUser`). These are guarded reads — the task tells the implementer to verify against the real file before coding. Not placeholders, but conditional branches the implementer must resolve.
- Task 17 step 2 has `const weekNumber = 0; // TODO post-PR` — this is a deliberate scope-reducer: week_number can be derived from SQL later. Documented, not a placeholder bug.
- Task 14 step 4 has `'routine_card'` fallback + `TODO post-PR: differentiate planned_bucket` — same rationale.

**3. Type consistency:**
- `AnalyticsEvent.workoutStarted` `source` values used in Tasks 14 (`empty`, `routine_card`, `planned_bucket`), 15 (N/A), 16 (N/A) — consistent
- `AnalyticsEvent.workoutDiscarded` `source` same enum — consistent
- `AnalyticsEvent.workoutFinished` `source` same enum — consistent
- `AnalyticsEvent.addToPlanPromptResponded` `action` values used: `added`, `skipped`, `dismissed` — consistent with Task 2 test
- `AnalyticsEvent.addToPlanPromptResponded` `trigger` values used: `pr_celebration_continue` only (no `direct_prompt` call site in this PR) — matches schema
- `SentryReport` method names (`setEnabled`, `isEnabled`, `captureException`, `addBreadcrumb`) consistent across Tasks 6, 7, 8, 10, 14, 18
- `currentPlatform()`, `currentAppVersion()` consistent across all event-firing tasks
- Field on Hive box: `crash_reports_enabled` used in Tasks 7 (main.dart seed) and 10 (provider). Consistent.

**4. Task ordering:**
- Task 1 (migration) → Task 3 (repo) — repo depends on the table ✓
- Task 2 (model) → Task 3 (repo) — repo depends on the model ✓
- Task 5 (Sentry dep) → Task 6 (SentryReport) — SentryReport imports sentry_flutter ✓
- Task 6 (SentryReport) → Task 7 (main.dart) — main.dart seeds SentryReport ✓
- Task 7 (main.dart + sentry init) → Task 8 (BaseRepository) — BaseRepository uses SentryReport ✓
- Task 7 → Task 9 (GoRouter observer) — observer lives in app_router, depends on sentry_flutter (Task 5) and sanitizeRouteName (Task 7) ✓
- Task 10 (provider) → Task 11 (UI) — UI watches the provider ✓
- Tasks 13-18 (event wires) — each depends on Task 3 (repo) and Task 4 (providers + platform helper) ✓
- Task 19 is the verification gate — runs last ✓

---

## Execution notes

**Fire-and-forget pattern:** Every event insert is wrapped in `unawaited(...)` except `account_deleted` (which must land before CASCADE DELETE). Analytics must never block the user's flow, and a Supabase outage should not break the app.

**Why analytics isn't gated by the opt-out toggle:** per Q3b, the toggle controls Sentry only. Analytics is first-party (data stays in GymBuddy's own Supabase) and is disclosed in the updated privacy policy as part of the existing processor relationship.

**Test environment:** no `SENTRY_DSN` is set, so `initSentryAndRun` takes the skip path and `Sentry.captureException` calls inside `SentryReport` are never made. All existing tests pass without mocking Sentry.

**Post-merge action items:** recorded at the bottom of Task 19, Step 7. Do NOT confuse these with in-PR work.
