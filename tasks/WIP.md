# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 14a PR 1: Connectivity + Cache Infrastructure

**Branch:** `feature/14a-connectivity-cache-infra`
**Source:** PLAN.md Phase 14a, PR 1

### Checklist

- [ ] Add `connectivity_plus: ^6.1.0` to pubspec.yaml
- [ ] Create `lib/core/connectivity/connectivity_provider.dart` — `onlineStatusProvider` (StreamProvider<bool>, 500ms debounce) + `isOnlineProvider` (sync read)
- [ ] Create `lib/core/local_storage/cache_service.dart` — generic `read<T>`, `write`, `delete`, `clearBox` + `cacheServiceProvider`
- [ ] Modify `lib/core/local_storage/hive_service.dart` — 5 new box constants + open in `init()` + clear in `clearAll()`
- [ ] Create `lib/shared/widgets/offline_banner.dart` — 48dp strip, errorContainer color, cloud_off icon
- [ ] Modify `lib/core/router/app_router.dart` — watch `onlineStatusProvider` in `_ShellScaffold`, show `OfflineBanner` when offline
- [ ] Tests: CacheService unit tests
- [ ] Tests: HiveService box tests
- [ ] Tests: connectivity provider tests
- [ ] Tests: OfflineBanner widget test
- [ ] `make ci` green
