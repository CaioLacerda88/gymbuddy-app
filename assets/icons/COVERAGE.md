# Icon pack — per-icon source map

33 icons × 3 candidate packs = 99 SVGs. All fetched via Iconify API.

| # | Icon | v1-line (Tabler base) | v2-bold (Phosphor base) | v3-silhouette (Game-Icons base) |
|---|------|------------------------|--------------------------|----------------------------------|
| 1 | `home`       | `tabler:home`              | `ph:house-bold`              | `game-icons:house`              |
| 2 | `lift`       | `tabler:barbell`           | `ph:barbell-bold`            | `game-icons:weight-lifting-up`  |
| 3 | `plan`       | `tabler:list-details`      | `ph:list-checks-bold`        | `game-icons:scroll-unfurled`    |
| 4 | `stats`      | `tabler:chart-bar`         | `ph:chart-bar-bold`          | `game-icons:progression` †      |
| 5 | `hero`       | `tabler:user`              | `ph:user-bold`               | `game-icons:muscle-up`          |
| 6 | `xp`         | `tabler:star`              | `ph:star-bold`               | `game-icons:crystal-shine` †    |
| 7 | `levelUp`    | `tabler:trending-up`       | `ph:trend-up-bold`           | `game-icons:upgrade`            |
| 8 | `streak`     | `tabler:flame`             | `ph:flame-bold`              | `game-icons:flame`              |
| 9 | `check`      | `tabler:check`             | `ph:check-bold`              | `game-icons:check-mark`         |
| 10 | `add`       | `tabler:plus`              | `ph:plus-bold`               | `game-icons:spawn-node`         |
| 11 | `edit`      | `tabler:pencil`            | `ph:pencil-simple-bold`      | `game-icons:quill-ink`          |
| 12 | `delete`    | `tabler:trash`             | `ph:trash-bold`              | `game-icons:trash-can`          |
| 13 | `filter`    | `tabler:filter`            | `ph:funnel-bold`             | `game-icons:funnel`             |
| 14 | `search`    | `tabler:search`            | `ph:magnifying-glass-bold`   | `game-icons:magnifying-glass`   |
| 15 | `settings`  | `tabler:settings`          | `ph:gear-bold`               | `game-icons:cog`                |
| 16 | `play`      | `tabler:player-play`       | `ph:play-bold`               | `game-icons:play-button`        |
| 17 | `pause`     | `tabler:player-pause`      | `ph:pause-bold`              | `game-icons:pause-button`       |
| 18 | `resume`    | `tabler:player-play`       | `ph:play-bold`               | `game-icons:play-button`        |
| 19 | `finish`    | `tabler:flag`              | `ph:flag-checkered-bold`     | `game-icons:checkered-flag`     |
| 20 | `close`     | `tabler:x`                 | `ph:x-bold`                  | `game-icons:cancel`             |
| 21 | `chest`     | `mdi:weight-lifter` ‡      | `ph:barbell-bold` ‡          | `game-icons:breastplate`        |
| 22 | `back`      | `tabler:arrow-back-up`     | `ph:arrow-bend-up-left-bold` | `game-icons:back-pain`          |
| 23 | `legs`      | `healthicons:leg` ‡        | `healthicons:leg` ‡          | `game-icons:leg`                |
| 24 | `shoulders` | `healthicons:arm` ‡        | `healthicons:arm` ‡          | `game-icons:shoulder-armor`     |
| 25 | `arms`      | `mdi:arm-flex` ‡           | `mdi:arm-flex` ‡             | `game-icons:strong`             |
| 26 | `core`      | `tabler:body-scan`         | `solar:body-bold` ‡          | `game-icons:abdominal-armor`    |
| 27 | `cardio`    | `tabler:heartbeat`         | `ph:heartbeat-bold`          | `game-icons:heart-plus`         |
| 28 | `dumbbell`  | `mdi:dumbbell` ‡           | `mdi:dumbbell` ‡             | `game-icons:weight`             |
| 29 | `cable`     | `mdi:cable-data` ‡         | `ph:gas-can-bold` ‡          | `game-icons:rope-coil`          |
| 30 | `machine`   | `mdi:rowing` ‡             | `ph:gas-pump-bold` ‡         | `game-icons:pulley-hook`        |
| 31 | `bodyweight`| `tabler:stretching`        | `ph:person-simple-bold`      | `game-icons:acrobatic`          |
| 32 | `bands`     | `mdi:sine-wave` ‡          | `ph:waves-bold` ‡            | `game-icons:spring`             |
| 33 | `kettlebell`| `mdi:kettlebell` ‡         | `mdi:kettlebell` ‡           | `mdi:kettlebell` ‡              |

Legend:
- † — gap-fill within the primary pack (game-icons didn't have the literal slug; used a thematic sibling)
- ‡ — fallback to a secondary pack (Tabler/Phosphor don't have anatomy or gym equipment vocabulary)

## Coverage stats
- **v1-line:** 22/33 from Tabler, 5 MDI, 4 Healthicons, 1 Solar, 1 Phosphor
- **v2-bold:** 19/33 from Phosphor, 9 MDI, 3 Healthicons, 1 Solar, 1 Tabler
- **v3-silhouette:** 32/33 from Game-Icons, 1 MDI (`kettlebell`)

### Post-fix changes (critic-flagged 5 icons replaced)
- `bodyweight`: was `game-icons:muscle-up` (duplicated `hero`) → **`game-icons:acrobatic`** (distinct dynamic pose)
- `finish`: was `game-icons:finish-line` (heart-plus = healing) → **`game-icons:checkered-flag`**
- `machine`: was `solar:treadmill-bold` (24×24 aesthetic mismatch) → **`game-icons:pulley-hook`**
- `bands`: was `game-icons:body-balance` (yoga semantic) → **`game-icons:spring`** (elastic coil)
- `add`: was `ph:plus-square-bold` (generic SaaS) → **`game-icons:spawn-node`** (fantasy "create new")

### Anatomy audit outcome (user review)
- `chest`: was `game-icons:chest` (treasure-box, not pectorals) → **`game-icons:breastplate`**
- Other body parts (back, legs, shoulders, arms, core, cardio) kept as-is:
  anatomy vocabulary in free icon packs is too sparse; no cohesive alternative
  read as clearly-anatomical without introducing a second style pack just for
  7 icons. Decision logged 2026-04-24. Options reviewed spanned icon-park,
  healthicons, fluent-emoji-high-contrast, mdi, and solar packs (exploratory
  HTML audit tooling was deleted with this migration; fresh audits can be
  regenerated via Iconify API probes if revisiting).

## Style-consistency risk per version

- **v1-line:** Most mixed — Tabler has a 2px round-cap signature, Healthicons is flatter,
  MDI has its own weight. Gym/anatomy icons will look visibly different from UI icons.
- **v2-bold:** Medium mix — Phosphor Bold is visually dominant but MDI fills gym
  equipment with lighter weight. Could normalize by picking only Phosphor wherever possible
  and using Solar Bold (not MDI) for gaps.
- **v3-silhouette:** Most cohesive — 27/33 are Game-Icons (Lorc + Delapouite have
  compatible silhouette style). Only 6 fallbacks, mostly UI-utility icons (add, machine)
  that don't exist in game-icons vocabulary.

## Recommendation for integration

If the user picks **v3-silhouette**, we have the strongest stylistic cohesion (82% one-source).
If they pick **v1** or **v2**, we'll need a second pass to reduce pack mixing — possibly
commission 3-5 custom SVGs for the anatomy icons where Tabler/Phosphor can't match.
