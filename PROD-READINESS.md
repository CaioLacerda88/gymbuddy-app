# GymBuddy — Production Readiness Plan

> Companion to [`PLAN.md`](./PLAN.md). All 10 implementation steps are complete. This document covers what's needed to ship on Google Play.

## Current State

The app is functional on Android with: auth (email + Google), exercise library (~60 seeded), full workout logging with offline crash recovery, routines, personal records with celebrations, home dashboard with stat cards, profile with data management, and CI/CD with E2E tests. Architecture is solid (repository pattern, sealed exceptions, RLS on all tables, atomic saves, 400+ tests).

**What's missing is the productionization layer — not the core logic.**

---

## Phase 1: Store Blockers (must fix before submission)

These prevent uploading to Google Play or violate mandatory store policies.

### B1. Release Signing
- `android/app/build.gradle.kts` line 37 uses `signingConfigs.debug` — Play Store rejects debug-signed APKs
- Create release keystore, configure `key.properties`, wire into Gradle
- Store keystore password in GitHub Secrets for CI release builds
- **Effort:** 1-2h

### B2. Crash Reporting
- Zero production crash visibility today
- Integrate Sentry Flutter SDK (or Firebase Crashlytics)
- Wire into `AppException` hierarchy so caught errors also report
- Add breadcrumbs for key user actions (start workout, finish workout, save routine)
- **Effort:** 2-3h

### B3. Analytics (Basic Events)
- Cannot measure retention, feature usage, or funnel drop-off
- Minimum events: `signup`, `login`, `first_workout_completed`, `workout_finished`, `routine_started`, `pr_broken`, `app_opened`, `data_reset`
- Options: Supabase Analytics, Amplitude, PostHog, or Mixpanel free tier
- **Effort:** 3-4h

### B4. Privacy Policy & Terms of Service
- Play Store requires a hosted privacy policy URL
- Must cover: data collected (email, name, workout logs, fitness metrics), storage (Supabase/Postgres), retention, user rights (deletion, export)
- Terms of Service: acceptable use, account termination, liability
- Link both from Profile screen and Play Store listing
- "Manage Data" screen (Step 10c) already covers deletion — good foundation
- **Effort:** 1 day (writing + hosting)

### B5. Account Deletion
- Google Play requires full account deletion since Dec 2023
- Current "Reset All Account Data" clears content but auth account persists
- Add "Delete Account" option that calls Supabase Admin API (via Edge Function) to delete the `auth.users` row
- Show confirmation, sign out, navigate to login
- **Effort:** 3-4h

### B6. ProGuard/R8 & APK Optimization
- No `minifyEnabled`, no `shrinkResources`, no `proguard-rules.pro`
- Release APK ships dead code from all dependencies (currently 19.7MB, could be ~12-14MB)
- Add R8 config, test that nothing breaks (Supabase + Hive reflection needs keep rules)
- **Effort:** 2-3h

### B7. Offline Workout Save & Retry
- Hive queue (`offlineQueue` box) is initialized but no sync worker exists
- Gyms have notoriously bad cellular signal — a user could lose an entire workout session
- Implement: detect connectivity failure on `finishWorkout()` → queue in Hive → retry on next app open or connectivity change
- Consider `connectivity_plus` package for network state monitoring
- **Effort:** 1-2 days

---

## Phase 2: Product Gaps (blocks retention, not submission)

These won't prevent Play Store approval but will cause poor reviews and high churn.

### P1. Progress Charts per Exercise
- **The #1 retention driver in gym apps.** Every competitor has this.
- QA-012 notes the exercise detail chart area is broken/empty
- Minimum: line chart showing weight over time for any exercise
- Library options: `fl_chart` (lightweight) or `syncfusion_flutter_charts`
- Data source: query `sets` joined with `workouts` by exercise_id, ordered by date
- Show on exercise detail screen (replace broken chart area)
- **Effort:** 2-3 days

### P2. Exercise Library Expansion
- 60 seeded exercises is barely enough for a first session
- Missing standard movements: Bulgarian Split Squat, Hack Squat, Face Pull, Lateral Raise, Preacher Curl, Nordic Curl, Cable Fly, etc.
- Target: 150-200 exercises covering all common gym movements
- Source: [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) has 800+ — select the most common
- New seed migration + update image URLs
- **Effort:** 1 day

### P3. Forgot Password Flow (QA-006)
- Currently triggers reset email immediately with no confirmation — guaranteed 1-star path
- Add confirmation screen before sending, dedicated reset flow
- **Effort:** 2-3h

### P4. Exercise Images Fix (QA-005)
- GitHub-hosted image URLs return 404
- Migrate to Supabase Storage or a CDN (Cloudflare R2, etc.)
- Update seed data with new URLs
- **Effort:** 3-4h

### P5. 1RM Estimation
- Single Epley formula: `weight * (1 + reps / 30)`
- Display on exercise detail screen and PR cards
- Widely expected by intermediate+ lifters, shared on social media constantly
- **Effort:** 2-3h

### P6. App Branding
- App label is "gymbuddy_app" in AndroidManifest — should be "GymBuddy"
- Default Flutter launcher icon — needs custom icon
- Default splash screen — should match app branding
- Play Store assets: icon (512x512), feature graphic (1024x500), 3-5 screenshots
- **Effort:** 1 day (design + implementation)

### P7. Volume Unit Display (PO-030)
- Volume displayed as "kg" instead of proper volume unit (weight x reps)
- Embarrassing on a core metric for data-oriented users
- **Effort:** 30min

---

## Phase 3: Warnings (should fix before or shortly after launch)

### W1. OAuth Deep Link Registration
- `AndroidManifest.xml` has no `<intent-filter>` for `io.supabase.gymbuddy://login-callback/`
- Google sign-in may fail on real Android devices (works in debug but not release)
- Need `app_links` or `uni_links` dependency + manifest registration
- **Effort:** 1-2h

### W2. Wakelock During Active Workout
- Phone screen dims and locks during rest periods
- Users must wake + unlock before next set — major gym-floor friction
- Add `wakelock_plus` package, activate when workout is active
- **Effort:** 1h

### W3. Input Length Limits
- Exercise names, workout names, notes have no `maxLength` on TextField or server-side CHECK
- A user could submit a 10MB exercise name
- Add `maxLength: 100` on name fields, `maxLength: 500` on notes, server-side CHECK constraints
- **Effort:** 1-2h

### W4. Push Notifications
- Zero re-engagement hooks today
- Minimum: workout reminder ("You haven't trained in 3 days"), rest timer (backgrounded)
- Consider Firebase Cloud Messaging (FCM)
- **Effort:** 1-2 days

### W5. Data Export
- Power users and privacy-conscious users expect CSV/JSON export
- Increasingly expected by GDPR regulations
- Export workout history + PRs as CSV download
- **Effort:** 3-4h

### W6. Direct Supabase Access in UI
- `create_exercise_screen.dart` and `profile_providers.dart` bypass repository pattern
- Access `Supabase.instance.client.auth` directly — harder to test, violates architecture
- Route through `authRepositoryProvider` instead
- **Effort:** 30min

### W7. Supabase Free Tier Scaling
- Free tier: 500MB DB, 1GB storage, 2GB bandwidth, 50K MAU
- At ~500 DAU the `sets` table growth will hit DB size limit
- Plan: upgrade to Supabase Pro ($25/month) before hitting 500 DAU
- Monitor with Supabase dashboard metrics

### W8. HomeScreen Performance
- `SingleChildScrollView` materializes entire widget tree
- Should migrate to `CustomScrollView` with slivers at scale (50+ routines)
- **Effort:** 2-3h

---

## Phase 4: Nice-to-Have (v1.1+)

| Feature | Notes |
|---------|-------|
| Plate calculator | Intermediate lifters think in plates. Strong has this. |
| Social / friends feed | Hevy's differentiator. Major effort. |
| Push notification — streak preservation | Highest-impact retention feature after charts |
| Dark/Light mode toggle | Some users prefer light in bright gyms |
| WearOS integration | Not critical for launch |
| Body weight tracking | Correlate workout volume with weight changes |
| Localization (i18n) | English-only for launch is fine |
| App review prompt | Ask happy users for a store review |
| Forced app update mechanism | Handle breaking backend changes gracefully |
| In-app rate limiting | Prevent auth brute force via Supabase config |

---

## Competitive Context

| Feature | Strong | Hevy | GymBuddy |
|---------|--------|------|----------|
| Progress charts | Yes | Yes | **No** (broken) |
| 1RM estimation | Yes | Yes | **No** |
| Plate calculator | Yes | No | **No** |
| Social / friends | No | Yes | **No** |
| Exercise library | ~350 | ~650 | **~60** |
| Volume analytics | Yes | Yes | Partial |
| Offline support | Yes | Yes | **No** (Hive crash recovery only) |
| Rest timer | Yes | Yes | Yes |
| Routines / templates | Yes | Yes | Yes |
| PR detection | Yes | Yes | Yes |

GymBuddy matches on core logging, routines, PRs, and rest timer. The gaps are progress visualization, library size, and offline resilience.

---

## Suggested Sprint Order

**Sprint A (1 week) — Store-ready:**
B1 (signing), B2 (crash reporting), B3 (analytics), B5 (account deletion), B6 (ProGuard), P3 (forgot password), P6 (branding), P7 (volume fix), W1 (OAuth deep link), W2 (wakelock), W6 (architecture fix)

**Sprint B (1 week) — Retention-ready:**
P1 (progress charts), P2 (exercise library expansion), P4 (image fix), P5 (1RM), W3 (input limits)

**Sprint C (1 week) — Resilience + compliance:**
B4 (privacy policy + ToS), B7 (offline save), W4 (push notifications), W5 (data export)

**After Sprint C:** Submit to Google Play. Monitor crash reports and analytics for 1-2 weeks, then iterate on Phase 4.

---

## Monetization Path (for reference)

Market-proven model is **freemium subscription** ($5-8/month or $40/year).

**Free forever:** Core logging, routines, exercise library, basic PRs, rest timer.

**Pro tier:** Progress charts & analytics, advanced stats (volume per muscle group, weekly tonnage), CSV export, unlimited custom exercises (cap free at 5-10), plate calculator, 1RM calculator, themes.

The most compelling paid features (charts, analytics) need to exist before monetization makes sense.
