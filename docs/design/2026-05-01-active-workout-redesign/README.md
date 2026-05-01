# Active Workout Set-Row Redesign — Design Brief (2026-05-01)

The active workout screen is the single most-used surface in RepSaga — lifters
spend more time here than anywhere else in the product. The current set-row
block has been flagged as "overly generic": a Material data table wearing a
purple coat, indistinguishable from Hevy or Google Fit if you strip the colors.

This brief contains:

1. **[Naming research — `Rotinas` → `Treinos`?](naming-treinos-vs-rotinas.md)**
   Brazilian gym culture vocabulary, competitor labeling, and the
   template-vs-session ambiguity. Recommendation + l10n keys impacted.
2. **[Critique + product pillars](critique.md)** — what's wrong with today's
   set-row, the emotional brief for the screen, and three product-level
   pillars (target-state-first, row-level state diff, spatial separation of
   adjustment vs completion).
3. **Three design directions** (HTML mockups — open in a browser):
   - [Direction A — Runic Codex](direction-a-runic-codex.html) — RPG scroll
     entries; tap-to-numpad input; full-row sealing; mythic identity wins.
   - [Direction B — Tactile Data Table](direction-b-tactile-data-table.html)
     — high information density; full-column tap zones; all sets visible.
     **(designer recommendation)**
   - [Direction C — One-Thumb Focus](direction-c-one-thumb-focus.html) —
     radical simplification; one set hero at a time; swipe-to-adjust;
     impossible-to-miss complete button.

## Quick recommendation summary

The ui-ux-critic recommends **Direction B**:

> Direction B does the thing that matters most: it makes the input targets
> physically impossible to miss. The PR badge above the reps value is
> scannable in under a second. The completed-row left border gives state
> legibility from two meters away. It preserves all-sets-visible density,
> which is what lifters actually want. The trade-off you accept: it leans
> closer to Hevy's vocabulary than to pure Arcane Ascent mythos. The RPG
> identity lives in the color palette and typography, not the layout. That
> is the right trade-off for the most-used screen in the app — identity
> belongs in celebrations and character progression, not in the friction of
> basic data entry.

The product-owner pillars (target-state-first, row-level state diff, spatial
separation) all map cleanly onto Direction B and partially onto A.
Direction C is the most ambitious but fragments muscle memory for
intermediate-to-advanced lifters used to scanning all sets at once.

## How to evaluate

1. Open all three HTML files in a browser at desktop width — the phone frame
   renders at 390×844 (iPhone 14 dimensions).
2. Read the critique to ground yourself in why today's design fails.
3. Read each direction's thesis (in `critique.md` and at the top of each HTML
   comment block).
4. Pick a direction (or hybrid). Implementation work is a separate PR.

## Adjacent work this redesign should resolve

- **BUG-018** — set-number cell 40dp tap target (below 48dp Material minimum)
- **BUG-019** — weight stepper compresses to 32dp on 360dp Brazilian-mid-market screens
- **BUG-020** — Finish button anchored AppBar-only, breaks one-handed reach

All three directions structurally fix these or make them trivially fixable.

## Out of scope

- Implementation work (separate PR after direction is chosen)
- Naming rename rollout (separate PR — touches 18+ pt-BR + en l10n keys)
- Other bugs in BUGS.md Cluster 4 not directly tied to the set-row block
