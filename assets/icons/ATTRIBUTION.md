# Icon pack attribution

RepSaga's candidate icon set is assembled from four open-source icon libraries
via the [Iconify](https://iconify.design/) CDN. All licenses permit commercial
use. Game-Icons.net requires attribution in our credits screen; the others
don't, but we credit them anyway out of courtesy.

## Sources

### Game-Icons.net — CC BY 3.0
- Site: https://game-icons.net/
- License: [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/)
- Artists used: **Lorc** (back-pain, magnifying-glass, muscle-up, quill-ink,
  strong, cog, heart-plus, scroll-unfurled, cancel, rope-coil,
  finish-line/related, progression, crystal-shine, flame, house, body-balance)
  and **Delapouite** (abdominal-armor, chest, check-mark, funnel, leg,
  shoulder-armor, trash-can, weight, weight-lifting-up)
- **Credit line (goes in app About / Credits):**
  > Some icons from game-icons.net, by Lorc and Delapouite, licensed under
  > CC BY 3.0.

### Tabler Icons — MIT
- Site: https://tabler.io/icons
- License: [MIT](https://github.com/tabler/tabler-icons/blob/main/LICENSE)
- Attribution not required but encouraged. Consistent outline set,
  used as our v1-line base.

### Phosphor Icons — MIT
- Site: https://phosphoricons.com/
- License: [MIT](https://github.com/phosphor-icons/homepage/blob/master/LICENSE)
- Bold weight used for v2-bold. MIT, no attribution required.

### Material Design Icons (MDI) — Apache 2.0
- Site: https://pictogrammers.com/library/mdi/
- License: [Apache 2.0](https://github.com/Templarian/MaterialDesign/blob/master/LICENSE)
- Used for gym equipment (dumbbell, kettlebell, rowing machine) and body
  anatomy (arm-flex, stomach) where Tabler/Phosphor have no match.

### Solar Icons — CC BY 4.0
- Site: https://solar-icons.com/
- License: [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)
- Used as Phosphor Bold fallback for body/treadmill concepts.

### Healthicons — MIT
- Site: https://healthicons.org/
- License: [MIT](https://github.com/resolvetosavelives/healthicons/blob/main/LICENSE)
- Used for anatomical icons (leg, arm/shoulder) not covered by UI-oriented
  libraries.

## How attribution ships in the app

When we pick a winner pack and integrate, the About / Credits screen will
include the Game-Icons.net attribution line verbatim. The MIT/Apache licenses
don't require in-app credit but we'll keep the full attribution list in
`ATTRIBUTION.md` shipped with source.

## Why these four (+2) libraries

- **Game-Icons.net** is the only free library with real game/fantasy/weapon/
  anatomy silhouette vocabulary. Irreplaceable for muscle icons and the
  Arcane Ascent thematic voice.
- **Tabler + Phosphor** provide the cleanest consistent UI utility sets
  (plus, check, x, filter, search, settings) in line and bold weights.
- **MDI** fills gym equipment gaps (dumbbell, kettlebell) that neither
  Tabler nor Phosphor have.
- **Solar + Healthicons** are gap-fillers for the ~5 icons where the above
  four don't cover.

No single library covered all 33 concepts on its own. Pack mixing is
unavoidable at our scope; we minimized it and documented every source.
