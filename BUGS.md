# BUGS.md — Multi-Agent Audit Findings (2026-04-30)

Output of a parallel sweep across UX/visual, QA stress simulation, DB schema/perf,
and codebase/test audits triggered by two production bugs surfaced on a Galaxy
S25 Ultra:

1. **Workout-save sync error:** `type 'Null' is not a subtype of type 'String' in type cast`
2. **Personal-records sync error:** `DatabaseException: insert or update on table "personal_records" violates foreign key constraint "..."`

Both items showed in the home-screen "Sincronização Pendente" sheet with retry
counters incrementing toward terminal failure (data loss).

Prioritization: **P0** = user-blocking / data-loss / security. **P1** = significant
UX or correctness. **P2** = polish, missing indexes, brand alignment. **P3** =
nice-to-have. Items are clustered so the tech-lead can batch related fixes into
single PRs.

PR **#122** (chore/phase18-followups) is already in flight and addresses none of
the items below — it is a separate debt-cleanup branch.

---

## Cluster 1 — Offline sync replay & related — FULLY RESOLVED (PR #124 + leftovers PR)

The two production bugs are both in this cluster. Three independent agents
converged on the same root causes. Recommend a single PR fixing all of Cluster 1
with paired unit tests.

**P0 data-loss subset status (2026-05-01):** BUG-001/002/004/042 resolved in PR #124
([01eec28](https://github.com/CaioLacerda88/repsaga/commit/01eec28e96572e8c5bc0a887ceea4a26686a990d)).
The fix introduced `ExerciseSet.toRpcJson()` as the DRY single-source serializer
shared by online + offline paths (BUG-001), a `dependsOn: List<String>` mechanism
on queued actions to gate child PR upserts on parent saveWorkout commit (BUG-002),
a typed `DatabaseException(code: 'rpc_null_result')` null guard on the RPC return
(BUG-004), and a `SyncErrorMapper` that classifies exceptions by class and renders
locale-aware user messages — never raw `e.toString()` — at the pending-sync sheet
boundary (BUG-042, opened mid-cluster after the user flagged information
disclosure on screenshots).

### BUG-001 [P0] — ~~Offline `setsJson` omits `created_at`, breaks `ExerciseSet.fromJson` on replay~~ ✅ RESOLVED in PR #124

**What:** When a workout is saved offline, `_enqueueOfflineWorkout` builds a
`setsJson` map for the queued `PendingSaveWorkout` action. The map serializes
every `ExerciseSet` field **except `created_at`**. When the queue later replays,
`ExerciseSet.fromJson` calls `DateTime.parse(json['created_at'] as String)` —
`json['created_at']` is `null`, the cast throws, the action moves to retry, and
after 6 attempts the entire workout becomes terminal data loss.

**Where:**
- `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:758-771` — the JSON construction missing `'created_at'`
- `lib/features/workouts/models/exercise_set.g.dart:21` — generated `_$ExerciseSetFromJson` that does the unguarded cast
- Replay path: `lib/core/offline/pending_sync_provider.dart:96-98` calls `ExerciseSet.fromJson(setsJson[i])`

**Fix:** Add `'created_at': s.createdAt.toIso8601String()` to the map literal at
`active_workout_notifier.dart:758-771`. While here, extract a static
`ExerciseSet.toRpcJson()` so the offline path and the online `WorkoutRepository.saveWorkout`
path share one serializer (eliminates the DRY drift that caused this bug).

**Test gap to close:** Add a unit pin in
`test/unit/features/workouts/providers/active_workout_notifier_test.dart` that
extracts the queued `setsJson` and round-trips it through `ExerciseSet.fromJson`
without throwing.

---

### BUG-002 [P0] — ~~FIFO queue replay drains `PendingUpsertRecords` before its `PendingSaveWorkout` parent~~ ✅ RESOLVED in PR #124

**What:** `OfflineQueueService` is FIFO across action types. When a workout is
saved offline, the queue contains `PendingSaveWorkout(W)` followed by
`PendingUpsertRecords([{set_id: S1, ...}])` for the PRs detected during that
workout. Replay drains FIFO, but with backoff each item retries independently.
If `PendingSaveWorkout` fails transiently (e.g., it hits BUG-001 above) and goes
to backoff, `PendingUpsertRecords` may attempt before its parent workout is
committed. The `personal_records.set_id` FK references a `sets.id` that doesn't
exist server-side yet → FK violation.

**Where:**
- `lib/core/offline/sync_service.dart` (queue drain logic)
- `lib/features/personal_records/data/pr_repository.dart:297-308` (upsert that fires the FK)
- Schema: `00001_initial_schema.sql:108` (`personal_records.exercise_id` and `set_id` FKs)
- `lib/features/personal_records/domain/pr_detection_service.dart:153,193` — `setId: bestSet.id` is always set even on the offline path; if BUG-001 is fixed in isolation but ordering isn't, this still fires.

**Fix (recommended):** Dependency-order the queue drain — `PendingUpsertRecords`
for set IDs `[S1, S2]` cannot drain until the `PendingSaveWorkout` carrying
those set IDs has committed. Implementation: tag each pending action with a
`dependsOn: List<String>` field (action UUIDs) and gate the drain.

**Alternative fix:** Set `setId: null` on the PR entries when they're enqueued
offline (the FK is already `ON DELETE SET NULL` per migration `00008`). Less
ideal — loses the set→PR linkage permanently for offline workouts.

**Test gap:** Add a `sync_service_test.dart` test that queues `saveWorkout` then
`upsertRecords`, asserts ordering on drain, and verifies the upsert is held
when its parent saveWorkout is in backoff.

---

### BUG-003 [P0] — ~~No `PendingCreateExercise` queue variant~~ ✅ RESOLVED in PR #127

**What:** A user can create a custom exercise while offline and log sets against
it in the same offline session. There is no `PendingCreateExercise` action; the
exercise exists only in local Hive. When `PendingSaveWorkout` replays, the RPC
fails (`exercise_id` references a row not on the server). Same FK violation
class as BUG-002, but a permanently latent bug — even with dependency-ordering
fixed, this path still breaks.

**Where:**
- `lib/core/offline/pending_action.dart` — sealed class missing `PendingCreateExercise`
- `lib/features/exercises/data/` — exercise creation repository
- `personal_records.exercise_id` FK at `00001_initial_schema.sql:108` (no `ON DELETE CASCADE`)

**Fix:** Add `PendingCreateExercise(exerciseId, name, locale, ...)` action.
Enqueue on offline custom-exercise creation. Drain before any
`PendingSaveWorkout` that references the new `exerciseId`. Reuses the
dependency-ordering work from BUG-002.

**Test gap:** Offline E2E spec — create custom exercise offline, log sets
against it, reconnect, verify sync drains successfully.

---

### BUG-004 [P0] — ~~`WorkoutRepository.saveWorkout` hard-casts RPC result without null guard~~ ✅ RESOLVED in PR #124

**What:** `result as Map<String, dynamic>` assumes Supabase always returns a
non-null map. PostgREST can return `null` for RPCs that hit a `RAISE
EXCEPTION` inside a `DO` block or on certain partial-commit error paths. When
that happens, the cast throws the exact error string the user reported. This
is a secondary path to the same surface symptom as BUG-001 (different root,
same user-visible message).

**Where:** `lib/features/workouts/data/workout_repository.dart:89`

**Fix:** `if (result is! Map<String, dynamic>) throw const app.DatabaseException('save_workout returned null');` before the cast. Apply the same defensive pattern to every repository's RPC return-cast (see Cluster 2 for the audit list).

---

### BUG-005 [P1] — ~~Sync drain doesn't invalidate RPG/PR providers after success~~ ✅ RESOLVED in PR #127

**What:** After `PendingSaveWorkout` drains successfully, the sync service
collects user IDs only for `PendingUpsertRecords` reconciliation
(`reconciledUserIds` in `sync_service.dart:69`). It never invalidates
`rpgProgressProvider`, `characterSheetProvider`, `earnedTitlesProvider`,
`exerciseProgressProvider`, `workoutHistoryProvider`, or `weeklyPlanProvider`.
The user trains hard offline, syncs, opens the character sheet — sees no
rank/level progression until they kill and relaunch the app. Severe degradation
of the RPG motivational loop, which is the entire premise of Phase 17–18.

**Where:**
- `lib/core/offline/sync_service.dart:69-131` — drain handler missing invalidations after `PendingSaveWorkout` success

**Fix:** Track which action types completed in the drain; for each, invalidate
the appropriate provider set. Pattern:
```dart
if (drainedSaveWorkouts.isNotEmpty) {
  ref.invalidate(rpgProgressProvider);
  ref.invalidate(characterSheetProvider);
  ref.invalidate(earnedTitlesProvider);
  ref.invalidate(exerciseProgressProvider);
  ref.invalidate(workoutHistoryProvider);
  ref.invalidate(weeklyPlanProvider);
}
```

---

### BUG-006 [P1] — ~~PR cache key mismatch between reconcile and detection~~ ✅ RESOLVED in PR #127

**What:** `SyncService._reconcilePrCache` writes to `prCache` under key
`'<userId>:<locale>'`. `ActiveWorkoutNotifier.detectPRs` reads from `prCache`
under key `'exercises:<sorted_exercise_ids>'`. These are two different cache
namespaces. Reconciliation writes one key; offline PR detection reads another.
Result: after a successful sync drain, the next offline workout uses the
pre-reconciliation exercise-specific cache, falsely earning PRs for exercises
the user already holds records on.

**Where:**
- `lib/core/offline/sync_service.dart:260-280` (writes `<userId>:<locale>` key)
- `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:837-840` (reads `exercises:<...>` key)

**Fix:** Unify the cache key strategy. Either both use exercise-id-keyed (and
reconcile by clearing all per-exercise cache entries on drain), or both use
user-keyed (and detection re-fetches per exercise from the user-keyed bag).
Recommend the former: clearer cache invalidation semantics.

---

### BUG-007 [P1] — ~~`OfflineQueueService` silently swallows Hive write failures~~ ✅ RESOLVED in PR #127

**What:** Three methods (`enqueue`, `dequeue`, `updateAction`) catch and log
without rethrowing. A failed enqueue means the action is permanently lost (no
queue item, no badge increment, no Sentry capture). A failed dequeue after a
successful remote save means the item replays on next drain, causing a
duplicate upsert. A failed `updateAction` means the retry counter never
increments, so the queue retries forever rather than reaching terminal state.

**Where:**
- `lib/core/offline/offline_queue_service.dart:25-32` (enqueue)
- `lib/core/offline/offline_queue_service.dart:36-44` (dequeue)
- `lib/core/offline/offline_queue_service.dart:73-82` (updateAction)
- `lib/core/offline/offline_queue_service.dart:51-68` (`getAll` silently skips corrupt entries — same class)

**Fix:** Rethrow on Hive failures so callers can surface them. At minimum, add
`Sentry.captureException` in each catch so the team sees production rates.

---

### BUG-008 [P1] — ~~Sync sheet retry CTA shown even for structural errors~~ ✅ RESOLVED in PR #127

**What:** `PendingSyncSheet` renders "Tentar novamente" for every failed item,
including structural errors (FK violations, type-cast crashes) that retry will
never resolve. The error text is the raw Dart exception string
(`type 'Null' is not a subtype of type 'String' in type cast`), opaque to a
Brazilian gym user. Users get stuck in a retry loop with no path out until
the queue auto-terminates after 6 attempts (data loss).

**Where:**
- `lib/shared/widgets/pending_sync_sheet.dart:220-229`

**Fix:** Classify error categories on the action:
- Transient (network, 503) → "Tentar novamente"
- Structural (FK violation, type cast, 4xx) → "Dispensar" + branded copy ("Não foi possível enviar — entre em contato com suporte")
- Capture the error class on the action's `errorReason` so the UI can switch on it.

---

### BUG-009 [P1] — ~~Active workout notifier swallows PR-detection exceptions~~ ✅ RESOLVED in PR #127

**What:** The PR detection catch block in `_finishWorkout` logs and continues.
If `PersonalRecord.fromJson` throws a null cast inside the cache deserializer,
the workout saves but the detection result is silently dropped. This was the
mask that hid BUG-001 from earlier debugging.

**Where:** `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:906-912`

**Fix:** Capture to Sentry inside the catch (don't just `log()`). Decide
whether to surface to the user — ideally not (workout is saved), but the
team needs visibility on production rates.

---

### BUG-042 [P0] — ~~Pending-sync sheet leaks raw exception strings to end users~~ ✅ RESOLVED in PR #124

**What:** The "Sincronização Pendente" sheet rendered `e.toString()` directly
in the per-item error label, exposing raw Dart cast errors
(`type 'Null' is not a subtype of type 'String' in type cast`), Postgres
constraint names (`personal_records_set_id_fkey`), table names, and SQL
codes to end users. This is OWASP A04:2021 information disclosure: the
backend's internal schema bleeds into a consumer surface, gives attackers a
free reconnaissance channel, and produces user-hostile copy that erodes
trust in the worst possible moment (their data is in limbo). Both reported
production crashes (BUG-001 and the FK-violation case) surfaced through
this leak path before they were diagnosed.

**Where:**
- `lib/shared/widgets/pending_sync_sheet.dart` — `_errors[id] = e.toString()`
  in the catch block (pre-fix line ~165)
- `lib/core/offline/pending_action.dart` — `lastError` field stores the same
  raw string and was rendered directly when present

**Fix:** New `lib/core/offline/sync_error_mapper.dart` centralizes error
translation at the UI boundary. It classifies the exception
(`AuthException` / `NetworkException`-shaped / `DatabaseException` +
`PostgrestException` + `TypeError` / fallback) and returns a localized,
user-safe string from the four new ARB keys:
`syncErrorSessionExpired`, `syncErrorOffline`, `syncErrorRetryGeneric`,
`syncErrorUnknown`. The raw exception is logged via `developer.log` and
breadcrumbed to Sentry inside the mapper — the caller never sees it. The
`lastError` field on `PendingAction` is now documented as
**dev-facing only**: it remains populated for diagnostics but UI must read
through `SyncErrorMapper.toUserMessage`.

Pinned by `test/unit/core/offline/sync_error_mapper_test.dart` (one test
per exception class → expected ARB key, plus information-disclosure
assertions that schema/constraint names never appear in the output).

---

## Cluster 2 — Unsafe casts in repository layer (P1)

Multiple `as String` / `as Map` / `!` patterns throughout the repository layer
will throw the same cryptic null-cast error if any DB column shape drifts.

### ~~BUG-010 [P1] — `as String` casts without null guards (audit list)~~ ✅ RESOLVED in PR #129

**Where (high priority — call paths that fire on workout save / PR sync):**
- ~~`lib/features/personal_records/data/pr_repository.dart:261` — `setRows.map<String>((r) => r['id'] as String)`~~
- ~~`lib/features/rpg/data/rpg_repository.dart:25, 315-325` — `CharacterState.fromJson` and `BackfillProgress.fromJson` field casts~~
- ~~`lib/features/rpg/data/titles_repository.dart:43-45` — `earned_titles` view casts~~
- ~~`lib/core/router/app_router.dart:148-151` — `extra['result'] as PRDetectionResult` and `extra['exerciseNames'] as Map<String, String>`~~

**Fix shipped:** Introduced `lib/core/data/json_helpers.dart` with
`requireField<T>` / `optionalField<T>` / `requireInt` / `requireDouble` /
`requireDateTime` / `optionalDateTime`, all throwing `DatabaseException` with
typed codes (`json_missing_field`, `json_wrong_type`, `json_bad_timestamp`)
that name the offending field. Replaced every audit-site `as T` with the
appropriate helper. Router `state.extra` casts moved into a new
`PrCelebrationArgs.fromExtra(extra)` factory that throws `StateError` (a
programmer-error class, not a database-error one) plus a
`validatePrCelebrationExtra` redirect gate that soft-fails to `/home`. Enabled
`avoid_dynamic_calls` in `analysis_options.yaml` to catch future regressions
at compile time. Pinned with unit tests in `test/unit/core/data/json_helpers_test.dart`,
`test/unit/features/rpg/data/rpg_repository_test.dart` (new),
`test/unit/features/rpg/data/titles_repository_test.dart` (extended),
`test/unit/features/personal_records/data/pr_repository_test.dart` (extended),
and `test/unit/core/router/pr_celebration_args_test.dart` (new).

---

## Cluster 3 — RPG progression UX gaps (P1)

The RPG system is the retention moat (per PLAN.md Phase 17–18 framing). Several
gaps blunt the motivational loop.

### ~~BUG-011 [P1] — Class promotion (Initiate → first earned class) silent~~ — RESOLVED in PR #134

**What:** When `maxRank < 5`, `ClassResolver` returns `CharacterClass.initiate`.
On the first rank-5 cross-over, the resolver returns a dominant class (e.g.
Bulwark for chest-dominant) and the badge silently changes on the character
sheet. There is no `ClassChangeEvent` in the celebration system. A user who
earns their first class above Initiate has no idea anything happened — the
badge just changes quietly.

**Where:**
- `lib/features/rpg/domain/class_resolver.dart:94`
- `lib/features/rpg/domain/celebration_event_builder.dart` — no class-change event type

**Fix:** Add `ClassChangeEvent(fromClass, toClass)` to the celebration union.
Detect on the workout-finish RPG snapshot diff. Render a branded class-up
overlay (one-time, not on every workout). High-priority for retention.

---

### ~~BUG-012 [P1] — Saga intro overlay collides with rank-up celebration~~ — RESOLVED in PR #134

**What:** Saga intro fires after the first XP is earned. If the user's first
workout produces a rank-up overlay AND the saga intro is gated on first XP,
both overlays compete for the screen at workout-finish. There is no E2E
coverage for this scenario; ordering depends on widget-tree paint order and
provider invalidation timing.

**Where:**
- `lib/features/rpg/ui/saga_intro_gate.dart` (gate logic)
- `lib/features/workouts/ui/active_workout_screen.dart:253-456` (`_onFinish`)

**Fix:** Sequence the overlays explicitly — saga intro must complete before
celebration overlays render. Add a `SagaIntroController.shouldShowAt(post-workout)` check
in the celebration orchestrator and queue.

**Test gap:** New E2E spec exercising "first workout that produces a rank-up".

---

### ~~BUG-013 [P1] — Cap-at-3 celebration logic drops all rank-ups when 3+ closers fire~~ — RESOLVED in PR #134

**What:** `celebration_event_builder.dart:103-104` calculates
`closersCount = levelUps.length + titles.length`, then
`rankUpCapacity = clamp(3 - closersCount, 0, N)`. A workout producing 1
level-up + 2 titles silently demotes ALL rank-ups to the overflow card (just
"{N} more rank-ups" with no enumeration). Rank-up overlays are the most
viscerally satisfying moment in the loop; losing them entirely to a numeric
card is anticlimactic.

**Where:** `lib/features/rpg/domain/celebration_event_builder.dart:103-104`

**Fix:** Always reserve at least one slot for the highest rank-up event, even
when closers fill the queue. Rebalance: `rankUpCapacity = clamp(3 - closersCount, 1, N)`.
Trade off one closer if needed to make room.

---

### ~~BUG-014 [P1] — Cross-build titles are hidden cheevos with no progress hint~~ — RESOLVED in PR #134

**What:** `_pillarWalker`, `_broadShouldered`, `_evenHanded`, `_ironBound`,
`_sagaForged` are binary unlocks with no in-app surface that reveals trigger
conditions. Brazilian gym-goers motivated by visible progress will not know
Iron-Bound exists until they accidentally unlock it. No codex entry shows
"you need X more rank in Y body part". This kills the retention hook these
titles are supposed to provide.

**Where:**
- `lib/features/rpg/domain/cross_build_title_evaluator.dart`
- `lib/features/rpg/ui/titles_screen.dart` — Distinction section shows earned only

**Fix:** Render unearned cross-build titles in the Distinction section with
locked iconography + a "next milestone" progress hint. Spec the predicate
descriptions in pt-BR (`"Aumente Costas e Pernas para 60 — falta {N} no Peito"`).

---

### ~~BUG-015 [P1] — `_broadShouldered` predicate is effectively unreachable for balanced lifters~~ — RESOLVED in PR #134

**What:** The predicate requires `Chest+Back+Shoulders >= 2*(Legs+Core)`. Any
lifter who does serious leg day cannot hit this — chest=50, back=50,
shoulders=50 (upper=150) requires legs+core ≤75, meaning legs ≤65 if core=10.
A dedicated upper-body-only build. The title is invisible to most users.

**Where:** `lib/features/rpg/domain/cross_build_title_evaluator.dart:128-133`

**Fix (product call):** Either re-spec the threshold (e.g., upper >= 1.5x
lower instead of 2x) or rename the title to something that matches the
extreme-imbalance reality (e.g., "Sky-Reacher" / "Above the Belt"). Coordinate
with PO before changing math.

---

### ~~BUG-016 [P1] — Class names hardcoded English (likely; verify)~~ — RESOLVED in PR #134

**What:** `ClassBadge` displays the class name. If the class names are
hardcoded English in `CharacterClass` enum without ARB l10n, switching to
pt-BR leaves "Bulwark" or "Sentinel" on the badge. Brazilian users seeing
English class names on a pt-BR UI is jarring.

**Where:**
- `lib/features/rpg/models/character_class.dart`
- `lib/features/rpg/ui/widgets/class_badge.dart`
- `lib/l10n/app_pt.arb` — verify `classNameBulwark`, `classNameSentinel`, etc. keys exist

**Fix:** Add per-class l10n keys; resolve in the badge widget via
`AppLocalizations.of(context).classNameForSlug(slug)`.

---

### BUG-017 [P2] — Vitality state stale on workout finish (cron-driven)

**Deferred — P2 nice-to-have, cron architecture is deliberate.** Audit
explicitly notes the nightly recompute is a spec choice, not a bug. Surface
a "last updated" timestamp on the vitality widget if/when user complaints
materialise; revisit on-demand recompute in a later cluster.

**What:** Vitality is computed by a nightly pg_cron job. A user who trains
heavily in the morning sees the same green radar they had when they last
trained — until the next cron tick. There's no on-demand recalculation on
workout finish.

**Where:** `00042_vitality_cron.sql`, `lib/features/rpg/domain/vitality_state_mapper.dart`

**Fix:** Add a "last updated" timestamp to the vitality widget. Optionally,
trigger an Edge Function call on workout finish to recompute that user's
vitality immediately. Low priority — the cron architecture is a deliberate
spec choice.

---

## Cluster 4 — Tap-target & sweat-proof UX (P1)

Core gym-context interactions below the 48dp Material minimum. High impact
because they're on the primary logging flow.

### BUG-018 [P1] — ~~Set-row number cell is 40dp (below 48dp tap target)~~ ✅ RESOLVED in PR #132

**Where:** `lib/features/workouts/ui/widgets/set_row.dart:236-241`
**Fix:** Bump `minWidth: 48, minHeight: 48`.

### BUG-019 [P1] — ~~Weight stepper buttons can render at 32dp on 360dp screens~~ ✅ RESOLVED in PR #132

**Where:** `lib/shared/widgets/weight_stepper.dart:141,186` (audit also covered
the structurally-identical sibling `lib/shared/widgets/reps_stepper.dart:117,153`)
**Fix:** Raised stepper button constraints to `minWidth: 40, minHeight: 48` on
both steppers; pinned with widget tests at a 360dp viewport.

### BUG-020 [P1] — ~~Workout "Finish" button is AppBar-only (one-handed reach hard)~~ ✅ RESOLVED in PR #132

**What:** Comment in code calls this "intentional friction" — but the issue
isn't the friction (a confirmation dialog gates it), it's the discoverability
+ reach. First-time users will hunt for how to end a workout; on 360dp
devices the AppBar trailing area is a precise micro-tap.

**Where:** `lib/features/workouts/ui/active_workout_screen.dart:592-627`
**Fix:** Moved the button to a persistent `_FinishBottomBar`
(`Scaffold.bottomNavigationBar`); same `Semantics(identifier:
'workout-finish-btn')` so E2E selectors continue to resolve. Hidden on the
empty body. Confirmation dialog kept untouched as the safety gate — reverses
the Phase 18c §13 placement decision.

---

## Cluster 5 — Localization & accessibility (P1/P2)

### BUG-021 [P1] — ~~`PendingSyncBadge` Semantics label hardcoded English~~ ✅ RESOLVED in PR #130

**Where:** `lib/shared/widgets/pending_sync_badge.dart:36`
**Fix:** Add `pendingSyncBadgeSemantics` ARB key; localize the
`'$label. Tap to manage.'` string.

### BUG-022 [P2] — ~~`equipmentBands` not localized (one of seven equipment chips)~~ ✅ RESOLVED in PR #130

**Where:** `lib/l10n/app_pt.arb:103` — `"equipmentBands": "Bands"` (English)
**Fix:** Change to `"Elásticos"` (or `"Faixas"` per BR gym vocabulary).

### BUG-023 [P2] — ~~Home status line fails WCAG AA contrast (2.8:1)~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/workouts/ui/widgets/home_status_line.dart:68-87`
**What:** `titleLarge` at alpha 0.55 over `abyss` background ≈ 2.8:1 ratio
(WCAG AA requires 4.5:1 for normal text).
**Fix:** Increase dim portion to alpha 0.75 minimum.

### BUG-024 [P2] — ~~`ActiveTitlePill` lacks max-width / overflow handling~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/rpg/ui/widgets/active_title_pill.dart:34-39`
**What:** Long pt-BR titles will overflow.
**Fix:** Add `Text(..., overflow: TextOverflow.ellipsis, maxLines: 1)` plus
a `BoxConstraints(maxWidth: ...)`.

### BUG-025 [P3] — ~~Saga intro overlay has no skip path~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/rpg/ui/saga_intro_overlay.dart:68-107`
**Fix:** Add a "Pular" `TextButton` in the top-right of the step-indicator row
calling `onDismiss` directly.

---

## Cluster 6 — Brand consistency (generic Material smells, P2)

The RPG screens are the most brand-expressive surfaces. Several use vanilla
Material widgets that read as generic-AI default.

### BUG-026 [P2] — ~~Character sheet error state uses `Icons.error_outline`~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/rpg/ui/character_sheet_screen.dart:331`
**Fix:** Replace with `AppIcons.render(AppIcons.hero, ...)` to stay on-brand.
Single most egregious generic-AI smell on a flagship screen.

### BUG-027 [P2] — ~~Titles screen loading uses double `CircularProgressIndicator`~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/rpg/ui/titles_screen.dart:95-96`
**Fix:** Combine `catalogAsync.isLoading || earnedAsync.isLoading` into one
branch; show a branded skeleton (mirror `_CharacterSheetSkeleton`'s pattern).

### BUG-028 [P2] — ~~Onboarding page 2 uses raw `ChoiceChip` widgets~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/auth/ui/onboarding_screen.dart:312-330, 350-369`
**What:** Visual language switches from branded welcome page to generic M3.
**Fix:** Replace `ChoiceChip` with branded pill-buttons matching the
exercise-screen filter chip style.

### BUG-029 [P2] — ~~Routine list empty state is bare `Text`~~ ✅ RESOLVED in PR #130

**Where:** `lib/features/routines/ui/routine_list_screen.dart:74-89`
**Fix:** Add a branded illustration + inline `FilledButton("Criar rotina")`
that calls `context.go('/routines/create')` (rather than pointing to the
hard-to-reach `+` icon in the AppBar).

---

## Cluster 7 — Database integrity & performance (P1/P2)

### BUG-030 [P1] — ~~`evaluate_cross_build_titles_for_user` lacks ownership check~~ ✅ RESOLVED in PR #128

**What:** Authenticated users can pass any `p_user_id` and read another
user's rank distribution via the returned slug list. Not currently exploited
because cross-user UIs don't exist, but should be locked down before any
social surface ships.

**Where:** `00043_cross_build_titles_backfill.sql:152` (GRANT to authenticated)
**Fix:** Add `IF p_user_id != auth.uid() THEN RAISE EXCEPTION USING errcode = '42501'; END IF;`
at the function entry.

**Resolution:** New migration `00045_evaluate_cross_build_titles_ownership_check.sql`
issues `CREATE OR REPLACE FUNCTION` with the original 00043 body reproduced
verbatim, plus an `auth.uid() IS NOT NULL AND auth.uid() != p_user_id`
guard at entry that raises with `ERRCODE = '42501'`. NULL `auth.uid()`
sessions (service_role, postgres role, pg_cron jobs, future server-side
detectors) are intentionally allowed through — they are authenticated at
the infrastructure layer and have legitimate cross-user reasons to invoke
this function (recompute, backfill, audit). The targeted attack surface —
an authenticated end user passing some other user's UUID via PostgREST —
is still rejected. Verified locally with the truth table:
end-user/own-UUID passes, end-user/foreign-UUID rejects, NULL/any-UUID
passes.

### BUG-031 [P2] — ~~Missing index: `workout_exercises.exercise_id`~~ ✅ RESOLVED in PR #128

**Where:** `00001_initial_schema.sql` (only indexes `workout_id`)
**Fix:** `CREATE INDEX workout_exercises_exercise_id_idx ON workout_exercises(exercise_id)` —
hot path for "show workouts containing exercise X".

**Resolution:** Combined into `00046_indexes_workout_exercises_pr_set_id.sql`
alongside BUG-032. Uses `CREATE INDEX IF NOT EXISTS` for replay safety.

### BUG-032 [P2] — ~~Missing index: `personal_records.set_id`~~ ✅ RESOLVED in PR #128

**Where:** `00008_fix_personal_records_set_id_fk.sql` (rewires FK without index)
**Fix:** `CREATE INDEX personal_records_set_id_idx ON personal_records(set_id)`.

**Resolution:** Same migration `00046_indexes_workout_exercises_pr_set_id.sql`.

### BUG-033 [P2] — ~~`personal_records.exercise_id` lacks explicit `ON DELETE` clause~~ ✅ RESOLVED in PR #128

**Where:** `00001_initial_schema.sql:108`
**What:** Defaults to NO ACTION/RESTRICT. A hard `DELETE FROM exercises`
would fail with FK violation rather than CASCADE/SET NULL.
**Fix:** New migration: `ALTER TABLE personal_records ALTER CONSTRAINT personal_records_exercise_id_fkey ON DELETE SET NULL` (matching the pattern from `00008` for `set_id`).

**Resolution:** New migration
`00047_personal_records_exercise_id_on_delete.sql`. Postgres does not allow
mutating an FK's referential action via `ALTER CONSTRAINT`, so the migration
drops the existing auto-named FK via a dynamic `information_schema` lookup
and re-adds it as `personal_records_exercise_id_fkey FOREIGN KEY (exercise_id)
REFERENCES exercises(id) ON DELETE CASCADE`. CASCADE was chosen over SET NULL
(the original spec): a personal record is meaningless without its parent
exercise, and CASCADE keeps the schema in sync with the Dart model's
`required String exerciseId` (non-nullable) without coupling a model
migration to this PR. The analogous 00008 (`set_id` → SET NULL) used SET NULL
because `set_id` was already nullable in 00001 — same reasoning does not
apply here. The ADD CONSTRAINT step is wrapped in an existence guard so
partial-replay scenarios don't raise "constraint already exists".

### BUG-034 [P3] — ~~Cross-build backfill uses `now()` for all `earned_at` rows~~ ✅ RESOLVED in PR #128

**Where:** `00043_cross_build_titles_backfill.sql:167-175`
**What:** Every backfilled user shares the exact same earn timestamp →
"recently earned" UIs look unnatural.
**Fix:** Use a derived timestamp (e.g., the `MAX(earned_at)` of the user's
existing per-body-part titles + 1ms) or accept the cosmetic issue.

**Resolution:** New migration
`00048_cross_build_backfill_derived_timestamps.sql`. Introduces a generic
`public.migration_checkpoints(key, applied_at, notes)` table for future
one-shot data fixes; the migration body is wrapped in a `DO` block guarded
by `pg_advisory_xact_lock` + a sentinel row (key
`'00048_cross_build_backfill_ts'`) so re-runs no-op. The UPDATE replaces
each cross-build row's `earned_at` with the user's
`MAX(earned_at) + 1ms` over their non-cross-build titles, COALESCE'd back
to the original timestamp for users who have no other earned titles. Note:
the original spec referenced `et.title_slug`; the actual column is
`earned_titles.title_id`. Idempotency verified by running the migration
twice — second invocation emits `Migration 00048 already applied` and
exits.

---

## Cluster 8 — Architecture leaks & SOLID violations (P2)

### BUG-035 [P2] — ~~Domain layer imports Flutter framework~~ RESOLVED in PR #136

**Where:** `lib/features/rpg/domain/vitality_state_mapper.dart:1,4` (imports
`package:flutter/painting.dart` and `AppLocalizations`)
**Fix:** Return a `VitalityColorToken` enum + l10n key from the domain;
let the UI layer resolve to `Color` and string. Or move the file to
`lib/features/rpg/ui/utils/`.

**Resolution (Cluster 8 PR A):** Option A applied. Domain mapper stripped
of Flutter + l10n imports — keeps only `fromPercent` / `fromVitality` and
the boundary constants. Color resolution + per-body-part palette +
localized copy moved to a new `lib/features/rpg/ui/utils/vitality_state_styles.dart`,
which also carries the `VitalityStateColor` extension that exposes the
legacy `state.borderColor` shape. The borderColor extension was also
removed from `lib/features/rpg/models/vitality_state.dart` so the model
file is itself Flutter-agnostic. Eight UI files updated to import the
new helper. The domain test file now imports zero Flutter packages —
that's the structural canary preventing regressions.

### BUG-036 [P2] — ~~`active_workout_screen.dart` is 1590 lines, `_onFinish` is 205 lines~~ RESOLVED in PR #138

**Where:** `lib/features/workouts/ui/active_workout_screen.dart`
**Fix:** Extract `_PostWorkoutNavigator`, `_CelebrationOrchestrator`, and
`_FinishWorkoutCoordinator` into separate files. CLAUDE.md mandates < 50-line
build methods.

**Resolution (Cluster 8 PR B):** Decomposed the 1706-line monolith into a
270-line orchestration shell (84% reduction). Four coordinators extracted to
`lib/features/workouts/ui/coordinators/`:
- `discard_workout_coordinator.dart` — discard-dialog flow + instance-field
  guard (also resolves BUG-041 for that flag)
- `finish_workout_coordinator.dart` — full finish-flow orchestration; owns
  `_isFinishHandled` + `_isFinishing` instance fields (resolves BUG-041)
- `celebration_orchestrator.dart` — saga-intro 5s-timeout wait +
  `CelebrationPlayer.play` invocation; provider snapshots captured BEFORE
  the await per the BUG-039 PR #136 defensive pattern
- `post_workout_navigator.dart` — `shouldShowPlanPrompt`,
  `showPlanPromptAndGoHome`, post-celebration nav switch; uses
  `ProviderScope.containerOf` (NOT `ref`) since the State is disposed by
  the time the postFrameCallback fires

Eight inline widgets extracted to `lib/features/workouts/ui/widgets/`
(`exercise_card.dart` with co-located sheet/chip/PR-section/headers,
`active_workout_app_bar_title.dart`, `active_workout_loading_overlay.dart`,
`empty_workout_body.dart`, `finish_bottom_bar.dart`, `add_exercise_fab.dart`,
`elapsed_timer.dart`, `exercise_list.dart`) so every build method drops
under 50 lines per CLAUDE.md mandate.

`ActiveWorkoutScreen` converted to `ConsumerStatefulWidget` so its State
owns the coordinator instances. All five E2E selector contracts
(`workout-discard-btn`, `workout-finish-btn`, `workout-add-exercise` ×2,
`workout-add-set`, `ValueKey('finish-bottom-bar')`) preserved verbatim;
all `mounted` / `rootContext.mounted` guards in original positions; all
provider invalidations preserved; all WHY comments documenting load-bearing
invariants moved with their code. Pure refactor — zero behavior change.
Verified by reviewer (4-position `_isFinishHandled` pattern preserved
bit-for-bit, single-instance discard-coordinator invariant holds, clean
coordinator boundaries with no cross-contamination), 2274 unit/widget
tests, 9 vitality integration tests, and 212 E2E tests all green.

### BUG-037 [P2] — ~~`profile_settings_screen.dart` is 801 lines, mixes 5 responsibilities~~ RESOLVED in PR #140

**Where:** `lib/features/profile/ui/profile_settings_screen.dart`
**Fix:** Extract per-section widgets (language picker, crash report toggle,
account deletion, social links).

**Resolution (Cluster 8 PR C):** Decomposed the 801-line monolith into a
169-line orchestration shell (79% reduction). Nine section widgets extracted
to `lib/features/profile/ui/widgets/`:
- `identity_card.dart` — `IdentityCard` + `_LoadingPlaceholder` + the public
  `showEditDisplayNameDialog` helper (was top-level `_showEditNameDialog`)
- `stats_row.dart` — `StatsRow` + `_StatCard`
- `weight_unit_toggle.dart` — `WeightUnitToggle` (kg/lbs SegmentedButton)
- `weekly_goal_row.dart` — `WeeklyGoalRow` with private `_showFrequencySheet`
- `profile_language_row.dart` — `ProfileLanguageRow` triggering the existing
  `LanguagePickerSheet`
- `manage_data_tile.dart` — `ManageDataTile` (extracted from inline build)
- `legal_tile.dart` — `LegalTile` (the reusable legal/privacy/TOS row)
- `crash_reports_toggle.dart` — `CrashReportsToggle` (extracted from inline)
- `logout_button.dart` — `LogoutButton` with private `_confirmLogout`

All 10 E2E selector contracts (`profile-heading`, `profile-kg`, `profile-lbs`,
`profile-goal-label`, `profile-goal-sheet-title`, `profile-manage-data`,
`profile-language-row`, `profile-logout-btn`, `profile-logout-dialog`,
`profile-cancel-btn`) preserved verbatim. Provider read patterns unchanged
(each widget keeps its prior `ConsumerWidget` vs `StatelessWidget` type;
`ref.watch(profileProvider)` stays at screen-level for sections that need
the value, with `StatsRow`'s self-contained watch documented inline as
intentional). Pure refactor — zero behavior change. 2283/2283 unit/widget
tests pass; 16/16 E2E (`profile.spec.ts` + `manage-data.spec.ts`) pass.

### BUG-038 [P2] — `plan_management_screen.dart` is 752 lines

**Where:** `lib/features/weekly_plan/ui/plan_management_screen.dart`
**Fix:** Extract `_WeekDayBucket`, `_RoutineSlot`, `_EmptyPlanCta`.

### BUG-039 [P2] — ~~`ActiveWorkoutNotifier.savedOffline` is a public field, not in state~~ RESOLVED in PR #136

**Where:** `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:47-98`
**What:** UI reads `notifier.savedOffline` via `ref.read` — breaks
unidirectional Riverpod data flow.
**Fix:** Fold `savedOffline` into `ActiveWorkoutState` (Freezed) or return as
part of `finishWorkout`'s result.

**Resolution (Cluster 8 PR A):** Both options applied. `savedOffline` is
now a Freezed field on `ActiveWorkoutState` (default `false`) so the
in-flight state snapshot carries the flag — restoring unidirectional
data flow. Additionally, `finishWorkout` now returns a
`FinishWorkoutResult` record (`prResult`, `savedOffline`) rather than a
bare `PRDetectionResult?`. The screen reads the flag from the explicit
return value instead of poking at notifier internals; this also covers
the post-finish window where `state.value` is `null` and a state-only
field would be unreachable. The public notifier field was deleted; a
test pins that `(notifier as dynamic).savedOffline` throws
`NoSuchMethodError` so any future regression that re-introduces the
field fails immediately.

### BUG-040 [P2] — ~~Provider keepAlive with no logout invalidation~~ RESOLVED in PR #136

**Where:** `lib/features/workouts/providers/workout_history_providers.dart`,
`workout_providers.dart` (`workoutCountProvider`)
**What:** Stale data for user A shown to user B after sign-out → sign-in.
**Fix:** Listen on `authStateProvider` and invalidate on user-id change.

**Resolution (Cluster 8 PR A):** New private helper
`_invalidateOnUserIdChange(Ref)` in `workout_history_providers.dart`
listens to `authStateProvider` and calls `ref.invalidateSelf()` when the
session's user-id slice transitions (skipping unchanged emissions so
token refreshes don't re-issue COUNT/SELECT queries). Wired into both
`workoutHistoryProvider.build()` and `workoutCountProvider`'s body. New
unit test pins the contract by driving a synthetic `authStateProvider`
stream and asserting per-user repository calls. **Follow-up note:**
`exerciseProgressProvider` (in `lib/features/exercises/providers/`) also
uses `ref.keepAlive()` and is user-scoped — it carries the same latent
bug but lives outside the audit's named files. Flagged for a follow-up
PR; not bundled here to keep this PR strictly within the audit's scope.

### BUG-041 [P2] — ~~File-level mutable state on active workout screen~~ RESOLVED in PR #138

**Where:** `lib/features/workouts/ui/active_workout_screen.dart:45-59` —
`_isShowingDiscardDialog`, `_isFinishHandled`
**What:** Survives widget disposal; could interfere with re-mount paths.
**Fix:** Move to `_ActiveWorkoutBodyState` instance fields.

**Resolution (Cluster 8 PR B):** Both file-level globals deleted. The two
flags now live as instance fields on coordinator classes (`_isShowingDialog`
on `DiscardWorkoutCoordinator`, `_isFinishHandled` + `_isFinishing` on
`FinishWorkoutCoordinator`). Coordinators are owned by the new
`_ActiveWorkoutScreenState` (`ActiveWorkoutScreen` was promoted to
`ConsumerStatefulWidget` for this), so the flags' lifetimes are now tied
to the screen's lifecycle — disposed cleanly when the route is replaced,
no leakage across re-mount paths. The single shared
`DiscardWorkoutCoordinator` instance is passed by reference into
`_ActiveWorkoutBody`'s constructor so both call sites (PopScope handler at
the screen level, AppBar close button at the body level) hit the same
guard, preserving the original "no stacked dialogs" invariant. The same
single-instance design applies to `FinishWorkoutCoordinator`, where
`_ActiveWorkoutScreenState.build` consults `coordinator.isFinishHandled`
in its postFrameCallback to yield navigation ownership during celebration
playback. Bundled into PR #138 with BUG-036.

---

## Test gaps to close

The fixes above include test specs for each. Consolidated list:

- **`active_workout_notifier_test.dart`** — pin that queued `setsJson` round-trips through `ExerciseSet.fromJson` (BUG-001)
- **`sync_service_test.dart`** — pin FIFO ordering: `PendingUpsertRecords` waits for parent `PendingSaveWorkout` (BUG-002)
- **`pr_detection_service_test.dart`** — assert `setId: null` policy or document the FK-race avoidance (BUG-002)
- **`workout_repository_test.dart`** — pin null-RPC-result handling throws typed exception (BUG-004)
- **`offline_queue_service_test.dart`** — pin Hive failure paths surface to caller (BUG-007)
- **`test/e2e/specs/offline-sync.spec.ts`** — assert character sheet reflects new XP/rank after offline drain (BUG-005)
- **`test/e2e/specs/saga.spec.ts`** — class change celebration spec (BUG-011)
- **`test/e2e/specs/gamification-intro.spec.ts`** — saga-intro + rank-up overlay collision (BUG-012)
- **`workout_history_providers_test.dart`** — invalidation on logout (BUG-040)
- **ARB completeness test extension** — assert all class-name keys exist in en + pt (BUG-016)

### Tests to consolidate / delete

- `test/widget/features/workouts/ui/home_screen_*.dart` — 8 separate files testing the same screen with duplicated scaffolding. Consolidate into `home_screen_test.dart` with `group()` blocks sharing setup.
- `test/unit/features/workouts/providers/active_workout_notifier_test.dart:766-830` — six near-identical "saveActiveWorkout-was-called" tests. Collapse to two: "mutations call save" / "no-op mutations don't".
- `test/integration/rpg_backfill_resume_test.dart:129`, `rpg_backfill_test.dart:145` — `expect(x, isNotNull)` followed by `x!` access. Replace with assertions on a meaningful field.

### Lint config gaps (`analysis_options.yaml`)

Enable these to catch the bug classes above at compile time:
- `unawaited_futures` — surfaces dropped `Future`s
- `avoid_dynamic_calls` — surfaces every untyped `(row as Map<...>)['key']` access
- `cancel_subscriptions` — `_RouterRefreshListenable` and others
- `close_sinks` — auth/connectivity providers

---

## Strengths to preserve in fixes

Findings the agents flagged as "do not gut these" while fixing:

- **Arcane Ascent color system** is genuinely distinctive (abyss/surface/surface2 three-tier, scarcity-enforced `heroGold`, Rajdhani/Inter pairing).
- **Rank-up overlay choreography** (1100ms multi-stage gold→violet, haptic at peak gold, FittedBox overflow guard for long pt-BR names) is the anti-generic model to copy elsewhere.
- **`ClassBadge` two-tier prestige design** (Initiate primaryViolet vs. earned hotViolet, asymmetric BorderRadius "struck mark") is smart brand differentiation.
- **`SetRow` sweat-proof patterns** — 600ms lock on new sets, swipe-to-delete with undo, dotted underline for copy-last-set.
- **`SECURITY DEFINER` RPC pattern** consistently applied across XP/vitality/exercise paths. Owner-only SELECT on data tables; writes via DEFINER fns is correct authz.
- **`character_state` view with `security_invoker = true`** — uncommon and correct.
- **Reversal pattern in `save_workout`** cleanly avoids double-counting on edits.
- **Idempotent backfill design** with `pg_advisory_xact_lock` + checkpoint table.
- **Vault-sourced secrets with graceful no-op** prevents pg_cron auto-disable on misconfigured envs.
- **`mapException` repository wrapper** consistently keeps Supabase exceptions out of the UI.
- **`AsyncNotifier` adopted everywhere** — zero legacy `StateNotifier` in new code.
- **`mounted` checks present** on all async UI callbacks.
- **ARB completeness test exists** — catches en/pt drift automatically.

---

## Suggested implementation order

Single PR per cluster to keep diffs reviewable.

1. **Cluster 1 — Sync replay** (BUG-001 through BUG-009) — closes the data-loss bug. Highest leverage; ship first. Will need DB-side coordination if BUG-002 introduces queue dependency tagging.
2. **Cluster 2 — Unsafe casts sweep** (BUG-010) — defensive depth-in-defense after Cluster 1. Enable `avoid_dynamic_calls` lint in the same PR to prevent regressions.
3. **Cluster 4 — Tap-target fixes** (BUG-018 through BUG-020) — small, isolated, immediate UX win.
4. **Cluster 7 — DB integrity** (BUG-030 through BUG-034) — security fix BUG-030 first; index additions can ride along.
5. **Cluster 3 — RPG progression UX** (BUG-011 through BUG-017) — coordinate with PO; rebalances are spec changes.
6. **Cluster 5 — Localization & a11y** (BUG-021 through BUG-025) — medium-scope sweep, easy review.
7. **Cluster 6 — Brand consistency** (BUG-026 through BUG-029) — UI polish PR; coordinate with ui-ux-critic.
8. **Cluster 8 — Architecture refactors** (BUG-035 through BUG-041) — medium-effort cleanup; can be split into per-feature PRs.

Test gaps and lint config land alongside their corresponding cluster fixes.
