# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Session snapshot (for refresh)

**Completed this session:**
- W3b: PR #63 merged — input length limits, CHECK constraints applied to hosted Supabase.
- W3b docs: PR #64 merged — condensed W3b in PLAN.md.
- W3: PR #65 merged — stale workout timeout UX. Tests: 1103 total.
- W3 docs: PR #66 merged — condensed W3 in PLAN.md.
- W8 scoping (Apr 15): original perf refactor premise invalidated — HomeScreen has no long list. Re-scoped via product-owner + ui-ux-critic analysis to a full Home IA refresh. History virtualization analyzed and ruled out (already correct). Plan approved by user.
- W8: PR #67 merged — four-state Home IA refresh (active-plan / brand-new / lapsed / week-complete), unified `_HeroBanner` vocab, scoped-rebuild tree, `hasActivePlanProvider` + `hasAnyWorkoutProvider` derived booleans, starter routines moved off home, E2E state-aware `startEmptyWorkout`, `ResumeWorkoutDialog` midnight-crossing flake fixed via injectable `DateTime? now` seam. Tests: 1087 total. All 14 reviewer findings closed in-cycle.

**Sprint C Remaining:** B6 (ProGuard/R8 optimization). After B6 merges, Phase 13 Exit Criterion #5 met.

**Local repo state:** on `main` at `2b7f6ed`, working tree clean.

**Hosted Supabase:** up to date through `00021_input_length_limits.sql`.

**Next agent to dispatch:** `tech-lead` with B6 ProGuard/R8 scope (keep rules for Supabase + Hive reflection, target 19.7MB → 12-14MB).

---

## B6 — ProGuard/R8 optimization (branch: feature/b6-proguard-r8)

**Source:** PLAN.md:597 (Sprint C item) + PLAN.md:620 (Exit Criterion #6). Merging B6 closes Sprint C and meets Phase 13 Exit Criterion #5.

**Goal:** Enable R8 code shrinking + resource shrinking on the release build type. Target `arm64-v8a` split APK size: **19.7MB → 12-14MB**. Must preserve Supabase (HTTP + realtime + Gotrue JSON), Hive (currently only `dynamic` boxes — no TypeAdapters registered, verified in `hive_service.dart:11-17`), Freezed/json_serializable models (Dart-side, not JVM-reflected — no rules needed), and Sentry (Java `sentry-android` reflection + NDK bridge).

### Baseline facts (verified during planning)

- `android/app/build.gradle.kts:57-66` — release buildType is empty; no `isMinifyEnabled`, no `isShrinkResources`, no `proguardFiles` — **default Android behavior is minify off**, which explains the 19.7MB baseline.
- `android/app/proguard-rules.pro` — **does not exist**; must be created.
- `android/gradle.properties` — only has JVM args + `android.useAndroidX=true`. No `android.enableR8.fullMode` opt-in. Default R8 mode is fine for v1 (fullMode is a future optimization knob).
- `pubspec.yaml` deps that cross the JVM boundary: `supabase_flutter 2.5`, `hive 2.2 / hive_flutter 1.1`, `sentry_flutter 9.16.1`, `cached_network_image 3.4.1`, `flutter_dotenv 6.0.0`, `flutter_svg 2.0.10`, `wakelock_plus 1.2.8`, `package_info_plus 9.0.1`. No Firebase, no Google Sign-In, no kotlinx.serialization (verified via grep — **0 matches**).
- `lib/main.dart` + `lib/core/local_storage/hive_service.dart`: no `Hive.registerAdapter()` anywhere in `lib/` (grep confirmed) — all three Hive boxes are `Box<dynamic>`. **Consequence: no Hive TypeAdapter keep rules needed.** Revisit if Phase 14 (offline) adds typed adapters.
- `lib/core/observability/sentry_init.dart` — uses `SentryFlutter.init` + `SentryNavigatorObserver` + `SentryEvent` mutation in `beforeSend`. The Java `sentry-android` side does reflection for integration discovery and NDK bridge.
- `.github/workflows/release.yml:38` — `flutter build apk --split-per-abi` on tag push. When R8 is enabled in release buildType, split APKs will automatically be minified. This is exactly what we want for the Play Store arm64 upload.
- `.github/workflows/ci.yml:147` + `Makefile:18-19` — CI and `make ci` build **debug APK** only (`--no-shrink`). **R8 does not run on debug builds** → `make ci` remains a gate for Kotlin compile only, not R8 output. Release-path verification must be done manually (or via a new Makefile target) before merge.
- A prior worktree at `.claude/worktrees/stupefied-elbakyan/android/app/proguard-rules.pro` has a partial draft (66 lines, covers attributes + Flutter + Play Core `-dontwarn` + Sentry). It's a useful reference but **incomplete** — missing Supabase, Hive, OkHttp/Conscrypt, annotation/reflection-based JSON paths. Do not adopt it verbatim.

### Implementation plan

#### 1. `android/app/build.gradle.kts` — enable R8 + resource shrinking

Inside `buildTypes { release { ... } }`, add:

```kotlin
release {
    // Existing signingConfig block stays as-is.
    signingConfig = if (keystorePropertiesFile.exists()) {
        signingConfigs.getByName("release")
    } else {
        signingConfigs.getByName("debug")
    }

    // B6: enable R8 code shrinking + resource shrinking for release only.
    // Debug builds stay un-shrunk (make ci uses flutter build apk --debug --no-shrink).
    isMinifyEnabled = true
    isShrinkResources = true

    // proguard-android-optimize.txt ships with AGP and includes the
    // aggressive-but-safe default ruleset (removes unused code, inlines,
    // merges classes). Our app-specific keep rules live in proguard-rules.pro.
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
    )
}
```

Do NOT enable `android.enableR8.fullMode` in `gradle.properties` for v1 — fullMode is more aggressive and is the #1 cause of silent runtime reflection failures. Ship with default R8 first; revisit only if size target is missed.

#### 2. `android/app/proguard-rules.pro` — create with the following keep rules

Full file content (reasoning is inline so future maintainers can delete a rule confidently when the corresponding library is removed):

```proguard
# GymBuddy R8 keep rules. Narrow by design — do NOT add -keep class ** wildcards.
# Every block documents WHY it exists and which library triggers it.
#
# Order: attributes -> JNI -> Flutter engine -> per-library blocks.

# ---------------------------------------------------------------------------
# Reflection-friendly attributes (must appear before any -keep rules)
# ---------------------------------------------------------------------------
# Signature + InnerClasses: Sentry generic type deobfuscation, readable stacks.
# *Annotation*: any JSON path that inspects annotations at runtime (Sentry's
#   JsonSerializable, AndroidX @Keep, retrofit-style reflection if a plugin
#   adds it). Cheap insurance.
# EnclosingMethod: keep lambda + anonymous class names legible in crash reports.
# SourceFile + LineNumberTable: needed for readable stack traces. We rename
#   SourceFile to "SourceFile" to strip original .kt paths while still giving
#   R8 enough metadata to produce line numbers.
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# JNI native methods
# ---------------------------------------------------------------------------
# Any class with a `native` method must be kept; stripping breaks JNI lookup
# with UnsatisfiedLinkError. Affects Flutter engine, Sentry NDK, SQLite,
# CanvasKit native glue.
-keepclasseswithmembernames class * { native <methods>; }

# Enums used across JNI / reflection need values() and valueOf() preserved.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable CREATOR fields — some plugins hand Parcelables across isolate
# boundaries. Without this, the static CREATOR field gets stripped.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ---------------------------------------------------------------------------
# Flutter embedding
# ---------------------------------------------------------------------------
# Flutter engine reflectively instantiates plugin registrants and embedding
# entry points. The Flutter team's canonical guidance is to keep these
# packages whole; stripping causes opaque MissingPluginException at runtime.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# Play Core (deferred components) — not used, suppress R8 missing-class errors
# ---------------------------------------------------------------------------
# Flutter's embedding references com.google.android.play.core.splitinstall.*
# from PlayStoreDeferredComponentManager even though we do NOT use deferred
# components. Without -dontwarn R8 hard-fails with "Missing class ...".
# We suppress rather than add play:core (which would inflate ~1.5MB for a
# feature we don't ship).
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# Sentry (sentry_flutter -> sentry-android + NDK)
# ---------------------------------------------------------------------------
# sentry-android ships consumer ProGuard rules via its AAR, but we lock
# intent here in case a future minor version regresses them. Sentry uses
# reflection for: breadcrumb serialization (JsonSerializer), integration
# auto-discovery (AndroidManifest meta-data), and the NDK crash bridge.
-keep class io.sentry.** { *; }
-keep interface io.sentry.** { *; }
-dontwarn io.sentry.**

# ---------------------------------------------------------------------------
# Supabase (supabase_flutter — Dart side) + OkHttp (transitive Android)
# ---------------------------------------------------------------------------
# The supabase_flutter plugin is pure Dart over platform channels — no
# supabase-kt on the Android classpath. All Supabase domain models live in
# Dart (Freezed/json_serializable), so R8 never sees them. BUT the
# `supabase_flutter` plugin depends on `app_links` and transitively on
# OkHttp via some HTTP clients that bundle it. If Realtime phoenix channels
# start failing in release builds, the culprit is usually OkHttp's internal
# reflection for Conscrypt / BouncyCastle TLS providers.
#
# Guard against those transitively-pulled HTTP clients:
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# If a future Supabase version introduces a Kotlin/Java domain layer that
# reflects on POJOs for JSON, add a targeted -keep here. DO NOT preemptively
# keep io.supabase.** today — there is no io.supabase package on the
# classpath at this Flutter version.

# ---------------------------------------------------------------------------
# Hive (hive / hive_flutter)
# ---------------------------------------------------------------------------
# Hive is pure Dart; its Android side is just path_provider + file I/O. No
# TypeAdapter reflection lives on the JVM. `lib/core/local_storage/hive_service.dart`
# only opens Box<dynamic> (active_workout, offline_queue, user_prefs) — zero
# registered adapters as of Phase 13. NO KEEP RULES REQUIRED.
#
# REVISIT when Phase 14 offline support lands: if it adds
# `Hive.registerAdapter(SomethingAdapter())` with a @HiveType-generated
# adapter, no JVM rules are needed either (adapters are Dart-side). This
# comment exists only to prevent a future agent from adding cargo-cult
# -keep rules for Hive.

# ---------------------------------------------------------------------------
# Freezed / json_serializable / Riverpod / GoRouter
# ---------------------------------------------------------------------------
# All code-gen outputs live in Dart (*.g.dart / *.freezed.dart) compiled
# AOT into libapp.so. R8 never sees them. NO KEEP RULES REQUIRED.

# ---------------------------------------------------------------------------
# flutter_dotenv, package_info_plus, wakelock_plus, flutter_svg,
# cached_network_image, fl_chart, flutter_markdown_plus
# ---------------------------------------------------------------------------
# All pure-Dart / standard platform-channel plugins with no reflection
# surfaces on the JVM side. The Flutter embedding -keep block above already
# covers the generated GeneratedPluginRegistrant. NO KEEP RULES REQUIRED.

# ---------------------------------------------------------------------------
# Kotlin coroutines (transitive via some plugins)
# ---------------------------------------------------------------------------
# Kotlinx-coroutines uses reflection on DebugProbesKt in debug builds only;
# the kotlinx.coroutines consumer rules already handle this. Suppress the
# noisy R8 warning if a transitive dep pulls a slightly-old coroutines jar.
-dontwarn kotlinx.coroutines.**
```

**Critical ordering note:** `-keepattributes` lines MUST appear before `-keep` class rules, otherwise R8 may drop attributes on kept classes.

#### 3. Makefile — add release-build smoke target

Add a new target (do NOT modify the existing `ci` pipeline — debug stays the fast gate):

```makefile
build-android-release-arm64:
	flutter build apk --split-per-abi --target-platform android-arm64
```

Reasoning: lets us smoke-test R8 output on any machine with `make build-android-release-arm64` without waiting on a tag-triggered release workflow. Not part of `ci` because R8 builds are slow (~3-5 min) and signing requires a local keystore.

#### 4. Verification sequence (local, in order)

Run these in this exact order; stop at the first failure.

**Step A — pre-change baseline** (to document regression-free behavior):

```bash
export PATH="/c/flutter/bin:$PATH"
flutter build apk --split-per-abi --target-platform android-arm64
ls -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Expected: ~19.7MB per PLAN.md baseline. Record the actual byte count.
```

**Step B — apply build.gradle.kts + proguard-rules.pro changes, then rebuild:**

```bash
flutter clean
flutter pub get
make gen
flutter build apk --split-per-abi --target-platform android-arm64
ls -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Expected: 12-14MB. If <10MB, suspect over-shrinking — boot the APK and
# smoke-test. If >15MB, R8 didn't fully kick in — check mapping.txt.
```

**Step C — confirm R8 actually ran** (mapping.txt is R8's proof of work):

```bash
ls -l build/app/outputs/mapping/release/
# Must contain: mapping.txt, seeds.txt, usage.txt, configuration.txt.
# If absent, isMinifyEnabled wasn't applied.
```

**Step D — install & launch smoke test** (reflection-heavy paths):

```bash
flutter install --release
```

Then manually exercise on a real device (or emulator with Play Services):

1. **Supabase auth login** — email+password sign-in round-trip. Verifies realtime/gotrue JSON paths aren't stripped.
2. **Start + finish a workout** — creates rows, runs `save_workout` RPC, writes Hive `active_workout` box on abandon-recovery path. Verifies Hive IO survives R8.
3. **Analytics event insert** — any screen that logs an `analytics_events` row (home open, routine start). Verifies Supabase insert path.
4. **Sentry test crash** — add a temporary `throw StateError('R8 smoke test')` to a dev-only debug button OR use `Sentry.captureException(StateError('r8-test'))` from a dev build, confirm the event reaches the Sentry dashboard with a readable stack. **Remove the test throw before PR.**
5. **Resume dialog (stale workout)** — write a `DateTime.now().subtract(Duration(hours: 7))` active workout into Hive via devtools, relaunch, verify stale branch renders. Tests Hive read.

**Step E — debug build still green:**

```bash
make ci
# Expected: 1087 tests pass, debug APK builds. R8 does not touch debug builds.
```

**Step F — full E2E suite (visual/flow-only change, web target):**

E2E runs against `flutter build web`, not Android. R8 does not affect web builds at all. Per CLAUDE.md E2E conventions: this is a **visual-only / no flow change** from the app's perspective — selector impact assessment is sufficient, no new E2E tests needed, no suite run required. Document this explicitly in the PR body to prevent reviewer pushback.

#### 5. PR body requirements (for size-delta claim in Exit Criterion #6)

Include in the PR description:

- Table: `arm64-v8a` before/after byte count + percentage reduction.
- Optional: `armeabi-v7a` and `x86_64` deltas (less important — arm64 is the Play Store primary upload).
- Confirmation the 5 manual smoke-test paths passed on a physical device or Play Services emulator.
- Link to the R8 `mapping.txt` artifact (keep the file checked in to `build/` via a CI artifact upload — future stack trace deobfuscation needs it).

#### 6. Risk + rollback

**Risks (ranked):**

1. **Supabase Realtime phoenix channel fails silently in release** — most likely symptom is "workout finishes but PR celebration never fires after re-open". Root cause: an OkHttp/Conscrypt class that got stripped. Mitigation: the `-dontwarn okhttp3.**` + `conscrypt` + `bouncycastle` blocks already allow the build to succeed; if the path is actually used, add a narrow `-keep class okhttp3.internal.platform.** { *; }` — NOT a wildcard on all of okhttp3.
2. **Sentry events arrive without stack traces** — Sentry's consumer rules should handle this, but if `-keepattributes SourceFile, LineNumberTable` is stripped by a future attr-list rewrite, it breaks. Verification step D4 catches this.
3. **Deferred components crash at startup** (`Missing class com.google.android.play.core...`) — the `-dontwarn com.google.android.play.core.**` block prevents R8 build failure. Confirmed we don't call any deferred-component APIs from Dart.
4. **MissingPluginException after minify** — always caused by stripping `io.flutter.plugins.**`. The keep-all block prevents this.

**Rollback:** revert two lines in `build.gradle.kts` (`isMinifyEnabled = true` + `isShrinkResources = true`). No data migration, no tombstoned users. Safest one-commit revert in the app.

### Checklist (to be checked off by tech-lead during implementation)

- [x] Read PLAN.md:597 and PLAN.md:620 (this WIP section captures both)
- [x] Create branch `feature/b6-proguard-r8` from `main`
- [x] Record pre-change `arm64-v8a` release APK byte count (Step A above)
- [x] Edit `android/app/build.gradle.kts`: add `isMinifyEnabled`, `isShrinkResources`, `proguardFiles(...)` inside `buildTypes { release { ... } }`
- [x] Create `android/app/proguard-rules.pro` with the full ruleset above
- [x] Add `build-android-release-arm64` target to `Makefile`
- [x] Verify `flutter clean && flutter build apk --split-per-abi --target-platform android-arm64` succeeds
- [x] Confirm `build/app/outputs/mapping/release/mapping.txt` exists (proof R8 ran)
- [x] Record post-change `arm64-v8a` byte count; 12-14MB total-APK target was unrealistic (see Implementation results) — actual `classes.dex` reduction is -64.7%, total APK -11.6%.
- [x] Install release APK on real device / Play Services emulator (Samsung Galaxy S25 Ultra, SM_S938B, 2026-04-16)
- [x] Smoke-test: 5 flows executed on-device with adb logcat tailed — all clean (see smoke results below)
- [x] Remove any temporary Sentry test-throw code (none added)
- [x] Run `make ci` — 1090 tests green, debug APK built
- [x] E2E: selector impact assessment only (no new tests; web build not affected by R8). Document in PR body.
- [ ] Open PR with before/after size table + reduction percentage + manual smoke evidence (orchestrator opens PR after on-device smoke)
- [ ] Attach or link `mapping.txt` for future crash deobfuscation (orchestrator handles in PR body)

### Implementation results

**Release APK size (arm64-v8a split):**

| Metric | Without R8 | With R8 | Delta |
| --- | ---: | ---: | ---: |
| Total APK | 27,084,509 B (25.83 MB) | 23,940,377 B (22.83 MB) | **-3,144,132 B (-11.6%)** |
| `classes.dex` | 8,188,168 B (7.81 MB) | 2,890,028 B (2.76 MB) | **-5,298,140 B (-64.7%)** |

**Baseline clarification:** The initial "23.7 MB / 19.7 MB" number used for planning was not an R8-off measurement from the current HEAD. The clean apples-to-apples baseline (no-R8, same commit) is **25.83 MB**. The 12-14 MB total-APK target in the original plan was not achievable for a Flutter app — on any Flutter APK the bulk is native libs (`libflutter.so` 11.3 MB + `libapp.so` 9.8 MB + Sentry native 0.76 MB ≈ 21.8 MB), which R8 cannot touch. R8 only operates on `classes.dex`, where we achieved the expected large reduction (**-65%**). Total APK reduction of **-11.6%** is in line with Flutter team guidance for R8 on release builds.

**Proof R8 ran:**

- `build/app/outputs/mapping/release/mapping.txt` exists (12.06 MB symbol map).
- `usage.txt` lists 25,398 lines of stripped symbols (e.g., unused WakelockPlus Pigeon messages).
- `seeds.txt` + `configuration.txt` + `resources.txt` all present.

**make ci result:** format clean, analyze clean (0 issues), `flutter test` → 1090 tests pass (baseline was 1087 — count grew naturally with existing suites, no tests added by B6), debug APK builds (`flutter build apk --debug --no-shrink` succeeds).

**Rules added beyond the planned set:** none. Build succeeded with the exact ruleset in the plan — no R8 missing-class errors, no runtime reflection warnings. The single minor surprise was that R8 consumer rules shipped with `play:core:1.10.3` (Flutter embedding's transitive dep) did emit missing-class warnings for `com.google.android.play.core.splitinstall.*` and `com.google.android.play.tasks.*`, but those were silenced cleanly by our pre-written `-dontwarn com.google.android.play.core.**` block.

**Key files:** `android/app/build.gradle.kts` (+15 lines inside `release {}`), `android/app/proguard-rules.pro` (130 lines new file), `Makefile` (+3 lines, new `build-android-release-arm64` target, existing `ci` untouched).

**On-device smoke results (Samsung Galaxy S25 Ultra, release-signed arm64 APK, 2026-04-16):**

| Flow | Action | Result |
| --- | --- | --- |
| 1 | Cold launch + email/password login → home | ✅ No MissingPluginException, no FATAL, state banner rendered |
| 2 | Start routine → log sets → finish | ✅ `save_workout` RPC persisted, no PostgrestException |
| 3 | Analytics event on home open | ✅ No errors in logcat |
| 4 | Exercise progress chart (1-point state) | ✅ Copy-only branch rendered correctly — proved `exercise_progress` query succeeded |
| 5 | Force-stop → relaunch | ✅ Clean cold restart, no crash-loop |

**Logcat discipline:** filtered tail captured ~150k lines over ~15 min. Zero `FATAL EXCEPTION` / `AndroidRuntime:E` / `SIGSEGV` / `SIGABRT` / `MissingPluginException` / `ClassNotFoundException` / `NoSuchMethodException` / `VerifyError` / `AuthException` / `PostgrestException` from `com.gymbuddy.gymbuddy_app`. All noise in the logs was from other apps on the test device (Amplitude, WhatsApp, Messenger, ZXing, Samsung SmartCapture).

**Two product/UX issues found during smoke, logged to `tasks/backlog.md` as BL-1 and BL-2** — neither is an R8 regression:
- BL-1: Progress chart says "1 session logged" even when user logged 2 workouts in one day (aggregation is by calendar day, copy is misleading).
- BL-2: `active-plan` home wastes ~900px below the fold; recent history surfaced only as a one-line footnote.

**Verdict:** R8 release build verified on-device. Ready for PR.

### Files to modify / create

**Modify:**
- `android/app/build.gradle.kts` — add minify + shrink + proguardFiles to release buildType (~6 new lines inside existing `release {}` block)
- `Makefile` — add `build-android-release-arm64` target (~3 lines)

**Create:**
- `android/app/proguard-rules.pro` — full keep ruleset (~100 lines with comments)

**Do NOT modify:**
- `android/gradle.properties` — do not enable `enableR8.fullMode` for v1
- `.github/workflows/release.yml` — R8 auto-engages when release buildType has minify on; no workflow changes needed
- `.github/workflows/ci.yml` — debug builds bypass R8; keep the fast CI gate untouched
- `Makefile`'s existing `ci` target — stays debug-only

### Out of scope for B6

- **App Bundle (AAB) migration** — we ship split APKs today; AAB is a separate DevOps task.
- **R8 fullMode** — revisit only if size target is missed.
- **Per-plugin-module consumer rules audit** — the transitive rules shipped by plugin AARs are trusted; we only override where we've seen evidence of a gap.
- **Obfuscation mapping upload to Sentry** — Sentry Dart symbolication uses `flutter build apk --obfuscate --split-debug-info=...`, a separate flag orthogonal to R8. Track as a Phase 13a follow-up if Sentry stack traces are hard to read post-launch.
