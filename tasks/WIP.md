# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 14a PR 2: Repository Read-Through Caching

**Branch:** `feature/14a-repo-read-cache`
**Source:** PLAN.md Phase 14a, PR 2

### Checklist

- [ ] `ExerciseRepository` — add CacheService param, cache `getExercises()` by composite filter, offline `searchExercises()` fallback
- [ ] `ExerciseRepository` provider — pass `cacheServiceProvider`
- [ ] `RoutineRepository` — add CacheService param, cache `getRoutines()` with `{routines, exercises}` envelope
- [ ] `RoutineRepository` provider — pass `cacheServiceProvider`
- [ ] `PRRepository` — add CacheService param, cache `getRecordsForUser()` + `getRecordsForExercises()`
- [ ] `PRRepository` provider — pass `cacheServiceProvider`
- [ ] `WorkoutRepository` — add CacheService param, cache `getWorkoutHistory()` (exerciseSummary custom field), `getLastWorkoutSets()`, `getFinishedWorkoutCount()`
- [ ] `WorkoutRepository` provider — pass `cacheServiceProvider`
- [ ] Create `cache_refresh_provider.dart` — background refresh all caches on app open
- [ ] Mount `cacheRefreshProvider` in `_ShellScaffold`
- [ ] Update ALL existing repo tests to pass CacheService constructor param
- [ ] New cache-specific unit tests per repo
- [ ] `make ci` green
