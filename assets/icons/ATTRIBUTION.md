# Icon pack attribution

RepSaga ships a single icon pack: **v3-silhouette** (`assets/icons/v3-silhouette/`),
assembled from two open-source libraries via the [Iconify](https://iconify.design/)
CDN during authoring. All licenses permit commercial use.

## Sources actually shipped

### Game-Icons.net — CC BY 3.0 (attribution required)
- Site: https://game-icons.net/
- License: [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/)
- Artists: **Lorc** (back-pain, magnifying-glass, quill-ink, cog, heart-plus,
  scroll-unfurled, cancel, rope-coil, progression, crystal-shine, flame,
  house, spring, spawn-node, checkered-flag, acrobatic, pulley-hook) and
  **Delapouite** (abdominal-armor, breastplate, check-mark, funnel, leg,
  shoulder-armor, trash-can, weight, weight-lifting-up, strong, muscle-up)
- Used for 32 of 33 icons.
- **Credit line (shipped via `LicenseRegistry.addLicense` in `lib/main.dart`;
  surfaces through `showLicensePage`):**
  > Some icons from game-icons.net, by Lorc and Delapouite, licensed under
  > CC BY 3.0.

### Material Design Icons (MDI) — Apache 2.0 (no attribution required)
- Site: https://pictogrammers.com/library/mdi/
- License: [Apache 2.0](https://github.com/Templarian/MaterialDesign/blob/master/LICENSE)
- Used for 1 icon: `kettlebell` — Game-Icons has no kettlebell in its vocabulary.

## How attribution ships in the app

The Game-Icons credit line is registered at app startup via
`LicenseRegistry.addLicense(...)` in `lib/main.dart`. Flutter's standard
`showLicensePage(context)` enumerates every registered license (including
all transitive MIT / Apache / BSD entries from our package tree) and surfaces
them in a scrollable list. When a profile / about menu lands, linking to
`showLicensePage` satisfies the CC BY 3.0 in-app credit requirement.

Per-icon source mapping is documented in `COVERAGE.md` (same directory) for
future maintainers.

## Packs evaluated but not adopted

During the authoring phase (2026-04-24), candidate icons were also fetched
from Tabler, Phosphor, Solar, and Healthicons for a three-version comparison.
None of those shipped. The v3-silhouette pack was chosen for its stylistic
cohesion (82% from a single artist pair on Game-Icons). Previous iterations
of this document described that exploration; this version reflects what the
app actually ships.
