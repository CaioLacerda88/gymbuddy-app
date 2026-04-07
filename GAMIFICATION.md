# GymBuddy RPG Gamification Spec

**Date:** April 2026
**Basis:** Competitor analysis, academic research (2023-2025), Reddit/forum user synthesis, UX design review

---

## Table of Contents

1. [Design Position](#1-design-position)
2. [Market Analysis](#2-market-analysis)
3. [User Personas](#3-user-personas)
4. [RPG System Design](#4-rpg-system-design)
5. [Feature Prioritization](#5-feature-prioritization)
6. [UX Design Spec](#6-ux-design-spec)
7. [Anti-Patterns](#7-anti-patterns)
8. [MVP Phases](#8-mvp-phases)
9. [Revenue Model](#9-revenue-model)
10. [Sources](#10-sources)

---

## 1. Design Position

The reference aesthetic is Dark Souls III's HUD — stark, purposeful, no decorative chrome — and the stat sheets in classic RPGs like Baldur's Gate: dense information delivered without apology. Every RPG element earns its pixel by connecting to a real training metric. If it cannot be justified by actual workout data, it does not exist.

The existing dark theme (`#0F0F23` / `#232340` / `#00E676`) is already more mature than most fitness apps. The gamification layer must feel like it was always latent in that design language, now surfaced — not bolted on.

### Core Principle

> Gamification only works when it makes the user's real training progress more visible, more legible, and more celebrated — not when it creates obligations, punishes rest days, or adds a second game on top of the first.

GymBuddy already has the data. Every PR, every set, every completed workout is in Supabase. The gamification system does not require new data collection. It requires better storytelling on top of data that already exists.

---

## 2. Market Analysis

### Competitive Landscape (2026)

**Camp A — Pure Trackers (no gamification): Strong, FitNotes**
Dominate among serious lifters on r/weightroom and r/fitness. Zero friction — open, log, close. Hevy recently added consistency streaks and volume milestones but keeps them invisible unless you seek them out. Lesson: gamification features are only safe when they do not interrupt the core logging flow.

**Camp B — Light gamification on tracking: JEFIT, Hevy**
JEFIT's NSPI scoring (a proprietary workout intensity score) is the most interesting and underappreciated gamification in the market. It turns every workout into a single comparable number tied to real training quality. Their badge system is universally ignored — nobody mentions badges positively. The NSPI score, which users don't even call "gamification," generates actual discussion.

**Camp C — Full RPG systems: Workout Quest, Level Up, FitDM, INFITNITE**
Exploded in 2024-2025. Level Up's rank system (E→D→C→B→A→S→SS→SSS), guild systems, and daily quests are the most coherent implementation. None of these RPG-first apps have broken into the mainstream tracker conversation. App Store reviews cluster around 4.0-4.3 with recurring complaints about the game layer being fun but the tracking being weak.

### The Gap GymBuddy Can Fill

An app where the RPG layer is so tightly coupled to real training data that you can't tell where the tracker ends and the game begins. Not "here's your workout tracker, also here's a game." Instead: **"your strength IS your character."**

### What Competitors Get Wrong

**Habitica** — HP loss mechanic for missed dailies created severe streak anxiety (a meme at this point). Users log completed tasks out of guilt at midnight. October 2023 guild/Tavern removal caused massive churn. Lesson: never build core retention around punishment.

**JEFIT** — Dozens of badges that nobody cares about. App reviews never mention them positively. Significant backend work for near-zero retention benefit.

**FitDM** — Class imbalance (mage overpowered) cited as frustrating. Class systems require ongoing balance work that most teams can't sustain.

---

## 3. User Personas

### Persona 1 — The Beginner (Weeks 1-8, highest churn risk)

Intrinsic motivation is fragile. Does not yet experience progressive overload rewards. Gamification provides a surrogate reward signal while real fitness gains are not yet visible. The first PR needs to feel like an event.

**Risk:** Complexity during onboarding causes immediate dropout. The 2025 Frontiers study found beginners experience cognitive overload significantly earlier when exposed to feature-rich gamification. ~65-70% of fitness app users are lost by day 7.

**Rule:** Show only XP bar and level for the first 30 days. Everything else unlocks through use.

### Persona 2 — The Consistent Lifter (3-18 months, monetization target)

Trains 3-4x per week. Has real progressive overload data. Has an emotional relationship with their PRs. These users write app reviews.

**Risk:** Condescension. They know more about progressive overload than most game designers. If gamification feels like it's for children, they will disable it or switch apps.

**Rule:** Every game mechanic must be defensible with real training logic. "+3 Strength because you hit a bench press PR" is defensible. "+150 XP for logging 3 sets" is not.

### Persona 3 — The Data Nerd (overlaps with consistent lifter)

Uses spreadsheets alongside the app. Tracks e1RM. Compares volume week over week.

**Rule:** The data behind every stat must be queryable and explainable. No black boxes.

---

## 4. RPG System Design

### XP Formula

```
Workout XP = Base + Volume Bonus + Intensity Bonus + PR Bonus + Quest Bonus

Base:           50 XP per completed workout (encourages any training)
Volume Bonus:   floor(total_kg_lifted / 500) XP (rewards volume)
Intensity Bonus: (average_rpe - 5) * 10 XP when RPE tracked (rewards effort)
PR Bonus:       +100 XP per weight PR, +50 XP per reps/volume PR
Quest Bonus:    +75 XP per quest completed this session
```

Uses data already collected: `sets.weight`, `sets.reps`, `sets.rpe`, `personal_records`. No new data collection required.

### Level Progression Curve

`XP needed for Level N = 500 * N^1.5` (square-root curve — fast early levels, meaningful later)

| Level | Total XP | XP to Next | Timeline |
|-------|----------|------------|----------|
| 1 | 500 | 500 | First workout |
| 5 | 5,590 | ~940 | ~4-6 weeks |
| 10 | 15,811 | ~1,528 | ~3-4 months |
| 25 | 62,500 | ~3,278 | ~1.5-2 years |
| 50 | 176,777 | ~6,544 | ~5+ years |

### Rank System

| Rank | XP Range | Who Gets Here |
|------|----------|---------------|
| Rookie | 0-2,499 | First few months |
| Iron | 2,500-9,999 | 3-6 months consistent |
| Bronze | 10,000-24,999 | 6-12 months |
| Silver | 25,000-59,999 | 1-2 years |
| Gold | 60,000-124,999 | 2-4 years |
| Platinum | 125,000-249,999 | 4-7 years |
| Diamond | 250,000+ | 7+ years (genuinely aspirational) |

### Training Stats (RPG Attributes)

Six stats computed from real workout data:

| Stat | Color | Hex | Training Signal |
|------|-------|-----|-----------------|
| Strength | Iron Red | `#FF6B6B` | Max weight lifted (weighted across compound lifts, e1RM via Epley) |
| Endurance | Pulse Blue | `#40C4FF` | Total sets per week sustained over 4+ weeks |
| Power | Volt Orange | `#FF9F43` | Frequency of high-weight (>80% e1RM) sets |
| Consistency | Primary Green | `#00E676` | Rolling 12-week training frequency score |
| Volume | Muted Violet | `#9B8DFF` | Total weekly tonnage (sets x reps x weight) |
| Mobility | Teal | `#26C6DA` | Logged mobility/bodyweight/flexibility movements |

**Key design choice:** Stats are normalized to personal best (0-100 scale), not population norms. A 60kg woman and a 120kg man can both have Strength: 78 — it means "78% of your personal best." Avoids alienating comparisons while keeping numbers meaningful.

### Weekly Quests

3 auto-generated quests per week, each completable in 1-3 sessions:
- One **improvement** quest: "Beat last week's squat volume by 10%"
- One **exploration** quest: "Try one new exercise this week"
- One **consistency** quest: "Complete 3 workouts this week"

Quests never expire with a failure state. Missed quests roll over or are replaced. Completion gives bonus XP — never access to core features.

---

## 5. Feature Prioritization

### Tier 1 — Build First (High Impact, Leverages Existing Data)

| Feature | Why | Effort |
|---------|-----|--------|
| PR celebration overlay | Highest emotional moment in logging. Hevy's PR notification is most-praised feature despite being minimal. Bar is low, ROI is high. | Low |
| Lifetime XP bar + level | Single persistent number. Computed from historical data — existing users get retroactive credit. Never decreases, never paywalled. | Low-Med |
| Non-punitive weekly streak | "Consistent for X weeks" — train 3 times any days to maintain. Comeback bonus (2x XP) instead of shame on miss. | Low |

### Tier 2 — Build Second (Meaningful Differentiation)

| Feature | Why | Effort |
|---------|-----|--------|
| Training stats panel | Strength/Endurance/Consistency from real data. Data nerd persona loves this. Differentiates from every pure tracker. | Med |
| Weekly smart quests | Short, optional goals. Research confirms users want structure + autonomy. | Med |
| Rank system | Medium-term goals beyond "just add weight." | Low |

### Tier 3 — Evaluate for v1.1

| Feature | Why | Effort |
|---------|-----|--------|
| Character classes | Powerlifter/Athlete/Warrior. Cosmetic + stat-weighting only, never XP multipliers. Changeable every 30 days. | Med-High |
| Light social (opt-in) | Friends list, see ranks, monthly challenges. No global feeds, no like counts. | High |
| Achievement milestones | Timeline entries ("lifted 100,000 kg lifetime"), NOT badge collections. | Med |

### Tier 4 — Defer (v2.0+)

Dungeon/boss mechanics, narrative story mode, loot drops, seasonal battle passes, guilds. Only if v1.0 user research shows strong demand.

---

## 6. UX Design Spec

### 6.1 Color System Extension

XP and level use `#00E676` exclusively — the app's core signal.
PR amber (`#FFD54F`) — exclusive color for record events. The only gold in the system.
Stat colors — see table in section 4.

**Color usage discipline:** Stat colors at full opacity only on radar chart dots, stat value numbers, quest card left borders, and post-workout stat bump lines. Never: gradient fills, glowing effects, or text colors beyond the value number.

### 6.2 Profile Screen → Character Sheet

The existing Profile tab becomes the "Character Sheet" — same URL (`/profile`), same nav position. Users who opt out see the screen exactly as today.

**Layout — top to bottom:**

**Identity Block** (replaces current `_IdentityCard`):
- Avatar circle 56dp with initials at w700 48sp
- Name at `titleLarge` w700, email dimmed at 0.55 opacity
- Level badge inline: `LVL 12` in `labelLarge` (14sp w700 letterSpacing 1.2) `#00E676`
- Separated by `#FFFFFF1A` divider from class designation: `POWERLIFTER` in same style at 0.55 opacity
- XP bar: full width, **6dp height** (thin = precision, thick = kids' game). Background `#FFFFFF1A`, fill `#00E676` solid. No gradient. Right-aligned: `2,340 / 3,000 XP` in `bodySmall` at 0.7 opacity
- Bar animates with single linear tween (300ms, ease-out) on mount

**RPG Stats Hexagon** (signature element):
- `CustomPaint` hexagonal radar chart, 6 axes
- Outer diameter: `min(screenWidth - 64dp, 280dp)`
- Background grid: 3 concentric hexagons at 33/66/100% scale, stroke `#FFFFFF12` 1dp
- Axis labels: 10sp Inter w600, stat color at 0.85 opacity, 12dp outside outermost ring
- Fill polygon: `#00E67618` fill (very low opacity green), `#00E676` 1dp stroke
- Stat dots: 8dp diameter circles at each vertex, filled with stat-specific color
- Section label above: `ATTRIBUTES` in `labelLarge` at 0.55 opacity
- Below chart: 2x3 grid of stat chips — name in 11sp w600 at 0.7 opacity, value in 20sp w800 in stat color
- Animates once on mount: polygon scales from 0→1 over 500ms ease-out. Then static.

**Weekly Consistency Band** (see 6.4)

**Active Quests** — max 2 visible, "View all" link

**Legacy Metadata Row** — `{n} Workouts | {n} PRs | Since {Mon YYYY}` in 0.55 opacity, no card

### 6.3 Post-Workout Celebration

Full-screen overlay above `Scaffold` (not a dialog, not a bottom sheet). Dismissible with single tap anywhere.

**Background:** `#0F0F23` at 0.96 opacity. Subtle concentric rings from center `#00E67608`.

**XP Animation (center of screen):**
- Start: `+0 XP` at `displayLarge` (48sp w900) `#FFFFFF60`
- Tween to final value over 600ms (fast acceleration, long ease-out)
- Color transitions `#FFFFFF60` → `#00E676`
- Below: workout name in `titleMedium` at 0.7 opacity, duration as `1h 14m`

**Stat Bumps (below XP):**
- Stat color 8x8dp bullet, stat name `labelLarge`, `+{delta}` in stat color bold
- Staggered cascade: 100ms delay between items, 200ms per item fade+slide-up
- Max 3 shown, `+2 more` overflow

**PR Section (if any, animates FIRST):**
- Horizontal band, amber `#FFD54F` bg at 0.1 opacity, 1dp amber border
- `NEW RECORD` in `labelLarge` letterSpacing 2.0 amber
- Exercise name `titleLarge` w700 white, new value `headlineLarge` amber

**Level Up (supersedes normal flow):**
- Subtle `#00E676` vignette glow (radial, max 0.06 opacity)
- New level at `displayLarge` (48sp) `#00E676`, scale punch: 0.8→1.05→1.0 over 400ms
- `LEVEL UP` in `labelLarge` letterSpacing 3.0 at 0.55 opacity
- Class change if applicable: `→ POWERLIFTER` in `titleMedium` w600

**Dismiss:** Tap anywhere. `TAP TO CONTINUE` at bottom in `labelLarge` letterSpacing 1.5 at 0.3 opacity. No pulse, no animation.

### 6.4 Home Screen Integration

**One line of gamification. Nothing else changes structurally.**

Replace the date subtitle with a status line:

```
[LVL 12]  ·  [14d streak]  ·  [Mon, Apr 7]
```

- `LVL 12`: `labelLarge` `#00E676`, tappable → `/profile`
- Separator: 4dp circle `#FFFFFF20`
- Streak: `bodyMedium` 0.7 opacity. No active streak → just the date. No red warnings.
- Date: `bodyMedium` 0.55 opacity

**Daily Quest Chip** (between stat cards and routine list):
- Height 44dp, background `#232340`, left accent 3dp in quest's stat color
- Quest name truncated 1 line `bodyMedium` w600, right: `3/5` in stat color, 32dp progress bar
- Dismissible via swipe-left, doesn't reappear until next launch
- Completed: shows `QUEST COMPLETE` in `#00E676` for one session
- No active quests: chip doesn't render

### 6.5 Streak System UX

**Weekly consistency meter (primary):**
- 7 segments (Mon-Sun), 32dp wide, 8dp tall, 4dp border radius, 4dp gap
- Trained today: `#00E676` fill
- Trained this week, not today: `#00E676` at 0.45 opacity
- Not trained: `#FFFFFF10` (neutral, NOT red)
- Today not yet trained: `#FFFFFF20` with 1dp `#00E67640` border
- Above: `THIS WEEK` `labelLarge` 0.45 opacity
- Below: `{n} of {goal} sessions` `bodySmall` 0.55 opacity (goal user-set, default 3)

**Streak number (secondary):**
- Consecutive weeks meeting goal: `{n} WEEK STREAK` `labelLarge` w700 `#00E676`
- Resets only if entire weekly goal missed, not for one missed day
- Miss one week → "comeback bonus" (2x XP next workout), no shame

**What does NOT exist:**
- Red coloring for any streak state
- "Your streak is at risk!" messaging
- Daily reminders tied to streak anxiety
- Visual degradation when progress slows

### 6.6 Quest Cards (Profile Screen)

Card: `#232340`, left accent 4dp in stat color. Padding 16dp horizontal, 12dp vertical.
- Left: name `titleMedium` w600, description `bodySmall` 0.55 opacity, 4dp progress bar
- Right: `3/5` — numerator `headlineSmall` in stat color, denominator `bodyMedium` 0.4 opacity
- Fixed 72dp height. Max 3 quests = 216dp total.
- Completed: `#00E67608` green tint bg, checkmark replaces fraction, `COMPLETE` replaces description
- Expired: 0.4 opacity, `--/--`, auto-archives after 48h

---

## 7. Anti-Patterns

### Explicitly Banned

| Pattern | Why | Alternative |
|---------|-----|-------------|
| **Confetti animations** | Birthday party app aesthetic. If you need particles, the design is weak. | Number animation with typography and color |
| **Streak flames / emoji** | No fire icon. No emoji as data. | Clean text: "14 week streak" |
| **Badge walls** | Grid of 64 badges = wall of shame for everything undone | Milestone timeline entries |
| **Multiple progress bars on home** | Gamification inflation — each bar reduces all bars' signal | One weekly bar only |
| **Level-gated features** | Users explicitly reject grinding for basic features | Gamification is always additive |
| **Push notification streak anxiety** | "You're about to lose your streak!" = churn trigger | Opt-in, positive framing only |
| **XP in persistent header/app bar** | App is a workout tool, not an idle RPG | XP shows post-workout and on profile only |
| **Animated level badges** | Spinning/pulsing = attention-seeking, not earned | Static badges |
| **Global leaderboards** | Motivation crowding at large gaps (Frontiers 2023) | Opt-in friends-only leaderboard |
| **Punitive daily streaks** | Habitica's core mistake. Anxiety → abandonment | Weekly streaks with comeback bonuses |
| **Class XP multipliers** | Creates imbalance that requires perpetual tuning | Classes affect cosmetics + stat weights only |
| **Social infrastructure** | Habitica guild removal caused massive churn | Light social only until v2.0 |

### Gamification Fatigue Prevention

Post-workout overlay is the only mandatory gamification surface. Everything else is:
- Dismissible (quest chip on home)
- Opt-in at profile level (users can collapse RPG stats)
- Tertiary to the core logging loop

A user who trains for six months without looking at stats still gets all value from the app.

---

## 8. MVP Phases

### Phase 1 — Foundation (single sprint)

- **PR celebration overlay** — full-screen animation on personal record
- **Lifetime XP counter** — computed server-side from historical data, retroactive for existing users
- Display on home screen and profile. No level yet — just accumulating XP.

No schema changes required. XP computed from existing tables. Presentation layer only.

### Phase 2 — Level System (second sprint)

- Level from XP using square-root curve
- Level badge on profile
- Rank assignment from XP ranges
- Level-up animation mid-workout

One new Supabase function/view to compute level. Minimal schema change.

### Phase 3 — Weekly Quests (third sprint)

- 3 auto-generated quests per week
- Quest completion → bonus XP
- Quest display on home (collapsible)

New schema: `quests` table (`user_id`, `week`, `type`, `target`, `completed_at`).

### Phase 4 — Training Stats Panel (fourth sprint)

- Strength, Endurance, Consistency, Power, Volume, Mobility stats
- Hexagonal radar chart on profile
- Historical stat charts

This is where the data nerd persona engages and GymBuddy differentiates from every pure tracker.

### What does NOT belong in MVP

Character classes, social features, guilds, seasonal events, battle passes, dungeon/boss mechanics, full achievement/badge systems. The 2025 Frontiers S-curve finding: feature richness beyond the optimal threshold actively harms adherence.

---

## 9. Revenue Model

### Free (non-negotiable)

- All core tracking (log workouts, sets, history)
- XP accumulation and level
- PR tracking and celebration
- Weekly streak counter
- 3 weekly quests

The XP/level system is the retention loop. Paywalling it = removing the save system behind a subscription.

### Premium (monthly/annual)

- **Training stats panel** with historical charts (premium anchor — genuine analytical value for the most loyal users)
- Expanded quest variety (>3/week, custom quests)
- Class selection (cosmetic + stat-weighting)
- PR history charts with e1RM trends
- Priority support + early access

Teaser at level 5: stats panel viewable but watermarked. Full access requires premium.

### Cosmetic (one-time purchases)

- Avatar cosmetics, rank icons, XP bar color themes
- Never implies free users are inferior

### Never paywalled

- Historical workout data
- Personal records and PR history
- Core level progression
- The ability to see your own training data

---

## 10. Sources

- [Top Gamified Fitness Apps of 2025 — Workout Quest](https://www.workoutquestapp.com/top-gamified-fitness-apps-of-2025)
- [Level Up - Gamified Fitness (App Store)](https://apps.apple.com/us/app/level-up-gamified-fitness/id6754510739)
- [Top 10 Gamification in Fitness Apps — Yu-kai Chou](https://yukaichou.com/gamification-analysis/top-10-gamification-in-fitness/)
- [S-shaped impact of gamification feature richness — Frontiers 2025](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1671543/full)
- [Motivation crowding in gamified fitness apps — Frontiers 2023](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1286463/full)
- [Habitica Review 2025 — HabitNoon](https://habitnoon.app/habit-tracker-app/habitica)
- [Zombies, Run! User Engagement — PubMed](https://pubmed.ncbi.nlm.nih.gov/34813376/)
- [How Gamification Affects Physical Activity — arXiv 2017](https://arxiv.org/abs/1702.07437)
- [Personalized Gamification Effects in Gym — arXiv 2021](https://arxiv.org/abs/2107.12597)
- [Gamification in Fitness Apps: Does It Work? — Stubbs](https://stubbs.pro/blog/article/gamification-in-fitness-apps)
- [RPG stat progression for workout consistency — Reddit r/gamification](https://www.reddit.com/r/gamification/comments/1rnl4xb/)
- [Gamified gym tracker: 500 users later — Reddit r/gamification](https://www.reddit.com/r/gamification/comments/1rp7g1f/)
- [Fitness app with XP, Streaks, Levels — Reddit r/alphaandbetausers](https://www.reddit.com/r/alphaandbetausers/comments/1rkq2cg/)
- [Runescape-inspired fitness web app — Reddit r/gamification](https://www.reddit.com/r/gamification/comments/1pf181a/)
- [RPG Character Classes — FitDM](https://fitdm.io/classes)
