# RepSaga RPG System — Brainstorm Proposal

Synthesis of two parallel research streams (competitor/market + game-design)
into a concrete v1 proposal with surfaced decisions.

---

## TL;DR

The user's proposal — body-part levels + cardio + resistance/speed — is
**structurally sound and partially proven**. It's RuneScape-for-gyms, which
has 20 years of retention data, and has live but buggy competition (GymLevels,
Ascend Fitness RPG). The biggest risk is **XP math calibration**: serious
lifters will rage-quit if "deadlift" gives Back XP but no Hamstring XP.

**Recommended v1 scope:** 6 body-part levels + Cardio track + Harmony
meta-rating. **Resistance/Speed axis → defer to v2** as Power/Endurance
sub-tracks (orthogonal, not a single slider — the single slider is reductive).

---

## Competitive landscape (key findings)

| App | Mechanic | Status | Lesson for us |
|---|---|---|---|
| **Fitocracy** | Flat XP for logged exercises | Dead (2011–2022) | Gamification disconnected from real performance = novelty grind, then churn |
| **GymLevels** | 17 muscle groups, Bronze→Mythic ranks | Live, small, buggy (2024+) | **Direct competitor with our exact mechanic**; executional quality is wide-open |
| **Ascend Fitness RPG** | Muscle Matrix + 4 abstract stats (STR/INT/END/STA) | Live, mixed reviews | Users like RPG framing; abstract stats feel less grounded than per-part |
| **RPG Fitness / FitDM / INFITNITE** | Character classes (Warrior/Mage/Rogue) | Live, fragmented | Class-based is the "safe" path; body-part is the sharper wedge |
| **Zombies, Run!** | Narrative overlay, no stats | 13 yrs, sustained | Narrative transportation outlasts novelty-of-leveling for cardio |
| **Habitica** | Self-defined task RPG | Live, 3.93★ | Self-reported tasks → self-honesty breakdown → churn |
| **Strong / Hevy** | Zero gamification | Dominant among serious lifters | Serious lifters actively resist bloat; our RPG must not add friction to logging |
| **Zwift** | 100 levels, watts-anchored | Retention gold standard | **The game state is anchored to real performance** — no way to fake XP without real watts. This is the pattern to copy. |

**Two key take-aways:**
1. Body-part-as-attribute is **validated as a concept** (GymLevels exists) but **unclaimed as a polished product**. Wide-open executional moat.
2. **Never let XP be farmable without real performance.** Fitocracy died from this; Zwift won because of it.

---

## Game-design principles that translate

1. **"Use it to level it" (Skyrim)** — XP comes from the actual work, never menus. Perfect fit: squatting is the only way to level Legs.
2. **Per-skill levels 1–99 (RuneScape)** — 20-year retention proves per-skill identity works. User's proposal literally IS this.
3. **Permanent progression (Diablo II)** — **Never reset levels.** A user's level IS their physical progress. Resetting = emotional catastrophe.
4. **Let imbalance exist (Old WoW talents, not modern)** — don't homogenize the XP curve across body parts. Let leg-mains be leg-mains.
5. **Numbers tied to reality (Zwift)** — XP formula must produce numbers that *feel right* to a lifter. This is the hardest engineering problem in the whole system.

---

## Proposed v1 system

### Core mental model
> You don't "level up your character." You level up your **body** — six body-part
> tracks + one cardio track, each earned through actual training.

### Attributes (tracked as levels 1–99)

| Attribute | Levels from | Notes |
|---|---|---|
| **Chest** | Pressing movements | bench, push-ups, dips, flyes |
| **Back** | Pulling movements | rows, pull-ups, deadlifts (partial), lat pulldowns |
| **Legs** | Lower-body compounds + isolation | squats, deadlifts (partial), lunges, leg press, calves |
| **Shoulders** | Overhead + deltoid work | OHP, lateral/front/rear raises, shrugs |
| **Arms** | Bicep/tricep isolation + supporting | curls, pushdowns, dips (partial), chin-ups (partial) |
| **Core** | Direct ab/oblique work + compound stabilization | planks, leg raises, hanging, compound-movement bonus |
| **Cardio** | Heart-rate-weighted effort | running, cycling, rowing, HIIT; requires HR data or RPE |

### XP math (v1 — calibrated, not farmable)

Per logged set, XP is calculated as:

```
set_xp = base(exercise) × intensity_mult × progressive_overload_mult × novelty_mult

base(exercise) = volume_load ^ 0.65          // tonnage raised to 0.65 — sub-linear so 10× weight ≠ 10× XP
intensity_mult = f(rep_range, RIR)           // 1.0 for 60-80% 1RM; bonus for 85%+; penalty for <50%
progressive_overload_mult = 1.2 if beats last week's best on this exercise, else 1.0
novelty_mult = exp(-session_volume_for_body_part / 15)  // diminishing returns: 10th set of bench = ~45% of 3rd set
```

Then distributed across body parts via a **proportional attribution map**:
- bench press → 70% Chest, 20% Shoulders, 10% Arms
- barbell row → 70% Back, 20% Arms, 10% Core
- deadlift → 40% Back, 40% Legs, 10% Core, 10% Arms
- (etc. — this map is the most important engineering artifact; serious lifters will grade it)

### Caps (to enforce recovery science)
- **Per-body-part weekly cap:** ~20 "effective sets" worth of XP per week. Training more is allowed, but XP past the cap is halved. Mirrors published training-volume-for-hypertrophy research.
- **Per-session diminishing returns:** novelty_mult above handles this.
- **No same-day back-to-back same-muscle farming:** 6+ hour spacing required for full XP.

### Cardio XP (v1 version)
- If HR data (wearable): zone-minutes weighted by zone (zone 2 = 1x, zone 4 = 2.5x)
- If no HR: RPE input (user rates effort 1–10 after session), weighted against duration + distance if GPS
- Never duration-alone, never distance-alone.

### XP curve
- Geometric: `xp_to_level(n) = 100 × 1.12^(n-1)`
- Level 1→20: ~8 weeks of consistent training (newbie gains honeymoon)
- Level 20→50: ~6 months (intermediate plateau, matches real strength progression)
- Level 50→99: 2–5 years (99 is a lifer's flex, à la RuneScape)

### Harmony meta-rating (soft balance rating, not a level)
- Calculated as: `min(body_part_levels) / max(body_part_levels)` plus a cardio factor
- Displayed as a rune/sigil, not a number on default profile
- Unlocks cosmetics at thresholds (0.6 → bronze rune, 0.8 → silver, 0.9 → gold)
- **Never locks content.** Pure identity reward.

### Identity titles (unlocked at milestones)
- Leg-main: Legs ≥ 40 AND Legs > 2x Arms → "Pillar-Walker"
- Upper-dominant: Chest+Back+Shoulders > 2x (Legs+Core) → "Broad-Shouldered"
- Generalist: all 6 parts within 30% of each other at lv30+ → "Even-Handed"
- Cardio-dominant: Cardio > 1.5x avg strength → "Marathoner"
- Powerlifter: Chest/Back/Legs all ≥ 60, low Cardio → "Iron-Bound"
- (etc. — titles are cheap to ship, high dopamine per unlock)

### What we explicitly DON'T do in v1
- ❌ Seasonal resets (catastrophic)
- ❌ Global leaderboards (toxic for fitness — body dysmorphia driver)
- ❌ Energy/stamina timers (biology already caps input)
- ❌ Raw numbers on shareable profiles (shame vector → dropout; use sigils)
- ❌ Resistance/Speed as a single slider (reductive — see v2)
- ❌ Character classes (Warrior/Mage) — less identity-rich than per-part

---

## v2 roadmap (explicitly not in v1)

### Power / Endurance orthogonal sub-tracks
Replace the user's resistance↔speed single axis with **two independent sub-tracks per body part**:

| Sub-track | Earned from | Profile |
|---|---|---|
| **Power** (per part) | low-rep, high-load (1–5 reps at 80%+ 1RM) | Powerlifter, Oly lifter |
| **Endurance** (per part) | high-rep, moderate load (12+ reps, time under tension) | Bodybuilder, CrossFitter |

This gives a user: `Legs 40 Power / 28 Endurance — "I'm a squatter, not a runner"` — much more texture than a single 40.

Why v2 not v1: attribution complexity doubles (need tempo + load classification per set), and serious lifters will grade it brutally. Calibrate v1 per-part first, then layer this.

### Synergy multipliers (later)
Training Chest+Back+Shoulders consistently → "Upper-Body Mastery" synergy → 10% XP bonus on those three. Internal build coherence rewarded à la D2 skill synergies.

### Rival comparison (explicit opt-in only)
Friend-only, never global. Friend's character sheet visible for motivation, not their raw weights. Opt-in during onboarding with clear warning about comparison anxiety.

### PR as mini-event
Hitting a 1RM PR is already a dopamine spike. Amplify: level-up-scale animation, shareable rune card, entry in personal "legend log."

---

## Hard questions for user decision

These are the calls I can't make alone. Each is load-bearing.

### Q1 — **Attribution map calibration**
The exercise → body-part proportion table is the most important artifact. I can draft it from strength-training literature (Schoenfeld, Helms, Israetel) but it will be graded by serious lifters. Options:
- **A.** I draft it from literature; we ship and iterate from user feedback.
- **B.** We commission a sports-science consultant to sign off before v1 ships.
- **C.** We make it community-editable (dangerous but honest — users flag misattributions).

My recommendation: **A**, with a "this is a draft, feedback welcome" disclaimer in the first release.

### Q2 — **Cardio in v1 or v2?**
Cardio XP requires either (a) wearable HR integration or (b) RPE input flow. Both add scope.
- **A.** Ship v1 strength-only; add Cardio as v1.1 with wearables.
- **B.** Ship v1 with strength + RPE-based cardio (no wearables needed).
- **C.** Ship v1 with all 7 tracks, cardio via wearable AND RPE.

My recommendation: **B**. RPE is free to implement, keeps the 7-track model honest, and wearables are a v2 enhancement.

### Q3 — **Visible numbers on profile?**
The shame vector is real. Leg-main with Arms 12 might quit rather than train arms.
- **A.** Numbers always visible (transparent, could drive improvement or shame).
- **B.** Runes/sigils on default profile, numbers in a "stats" deep-dive screen only.
- **C.** Numbers visible but never shareable/exportable; only identity titles are shareable.

My recommendation: **B**. Preserves self-insight without broadcast humiliation.

### Q4 — **How does this connect to Phase 16 (subscription)?**
The RPG system is retention infrastructure. Should it be premium-gated?
- **A.** Free for all (retention moat, drives free→paid conversion via other features).
- **B.** Basic per-part levels free; Power/Endurance sub-tracks + titles + rune cosmetics premium.
- **C.** Full system premium from day 1.

My recommendation: **A**. The RPG system is the PRODUCT now. Gating it kills the retention story. Subscription should gate advanced analytics, export, coaching — not the core loop.

### Q5 — **Naming**
"Levels" is generic. In Arcane Ascent voice, these should be called something else. Options:
- **"Runes"** — "Chest Rune 42" — ties to the visual direction
- **"Sigils"** — "Back Sigil lv18"
- **"Ranks"** — "Leg Rank III" (D&D-esque)
- **"Ascents"** — "Chest Ascent 42" — ties directly to the app name
- **"Paths"** — "The Path of the Back, mastered to 18"

My recommendation: **Runes** (ties to visuals, single-syllable, game-native). But user call.

---

## Proposed next steps

1. **You react to the Q1–Q5 decisions above.** Anywhere you disagree or want to push further, we pivot.
2. Once decisions settle, I draft `PLAN.md Phase 18 — RPG Progression` with full spec (XP formulas, attribution map, schema changes, UI wireframes).
3. Product-owner validates pricing/gating story against Phase 16.
4. UI-UX critic mocks the profile screen (runes vs numbers question from Q3).
5. Tech-lead stages the migration: Phase 18a = schema + XP engine, 18b = profile screen, 18c = titles + cosmetics, 18d = cardio track.

Want to react to Q1–Q5 now, or should I sleep on this and let you digest first?
