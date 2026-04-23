# RepSaga — ChatGPT Pixel-Art Asset Generation Brief

**Goal:** generate every pixel-art asset the RepSaga Flutter app needs for the
full-pixel-art visual direction (Approach A), with a **consistent palette, pixel
size, and lighting**, using ChatGPT's image tool (GPT-Image / DALL·E 3).

**How to use this document:**

1. Open a fresh ChatGPT conversation. Attach your two reference images (the
   9-icon options sheet + the pixel-icon system sheet).
2. Paste **§1 Master style-lock prompt** once. Wait for the model to acknowledge.
3. For each asset you want, paste the matching **§4 Per-asset prompt**.
   ChatGPT will generate the image in the locked style.
4. Save each generated PNG with the exact filename given (right-click → save
   image as). Drop it into the matching folder under `assets/pixel/` in this
   repo. The filenames + folders are already the paths our Flutter code will
   read.
5. If the style drifts after a few generations, paste **§1** again to re-lock.
6. For any asset that doesn't come out right, re-paste its per-asset prompt
   and add "try again — stricter adherence to the palette and the 1-pixel unit
   size; no anti-aliasing."

**Why this structure:** models drift mid-conversation. A short "remember the
rules" reset every ~10 assets keeps the palette and pixel size coherent. Each
asset prompt is self-contained so you can also start a new chat per asset
without losing the style (just paste §1 + that asset).

---

## §0 · Decision log (update as you generate)

Rules added after assets were already generated, so future regens inherit the
same decisions. Every per-asset prompt below already reflects these.

- **Nav actives share an aura family** (decided after 4.3.1 vs 4.3.2 mismatch):
  every active nav sprite gets a 2-px `#B36DFF` aura hugging the silhouette,
  a looser 1-px `#6A2FA8` halo outside that, four 2×2-px `#B36DFF` corner
  sparkles each with a 1-px `#FFF1B8` hot center, and one small `#FFD54F`
  or `#FFF1B8` interior highlight pixel to draw the eye. Inactives stay
  desaturated gunmetal silhouettes — no aura, no sparkles. All 5 nav icons
  already use this rule.
- **Ranks share one silhouette** (decided after rank v1 regeneration):
  identical shield shape + banner ribbon across all 7. Only fill color,
  glyph, and banner text differ. No corner rune decorations.
- **Rookie glyph is pictorial, not typographic** (decided in rank v2):
  wooden practice sword, not the chemistry symbol "Rk".
- **Iron glyph is an iron dumbbell**, not a pickaxe (decided in rank v2):
  a pickaxe is one layer removed from iron; also collides with other stat
  icons in the app.
- **Iron shield fill is true iron grey** `#4A4560`, not slate-blue.
- **Milestones are backdrop-free** (decided after 4.5.1 v1 cone-backdrop
  pass): no spotlight cones, no parchment washes. Standalone object on
  transparent bg. This lets the 6 milestones read as one coherent family
  when tiled in the character-sheet achievement grid.
- **Milestone sparkle convention** (tightened after 4.5.5 landed with 4
  sparkles while the first few landed with 0–3 — the family was drifting
  toward "whatever felt right"):
  exactly **3 small 4-pointed `#FFD54F` gold sparkles**, each ≤6 px,
  placed in the outer corners around the main object (typically
  top-left, top-right, and bottom-left or bottom-right — pick the 3
  that don't overlap the glyph). **No purple sparkles** — `#B36DFF`
  sparkles belong exclusively to the nav-active aura family (§4.3).
  No diamond-shaped sparkles in milestones.
- **No cross-grid glyph collisions** (decided after 4.5.4 v1 crown/Gold
  rank collision): a milestone's hero glyph must not be the same object
  as any rank badge glyph. Rookie=practice-sword, Iron=iron-dumbbell,
  Copper=hammer, Silver=longsword, Gold=crown, Platinum=five-point-star,
  Diamond=faceted-gem are all reserved. Milestones that needed one of
  those shapes (rank_up) must use a neutral stand-in — gold chevron `▲`,
  generic rising shield silhouette, or banner glyph.
- **Celebration hero-sprite family** (locked by 4.8.1 + refined by 4.8.2):
  every celebration sprite shares these rules. Hero element fills the
  vertical center ~2/3 of canvas with ~1/6 padding top and bottom. A
  radiating accent motif surrounds the hero (lightning bolts on
  level-up, gold rays on PR chest + milestone crown, sparkles/mist on
  comeback shield) — the radiation is the family signature. One
  `#FFF1B8` sparkle sits at the "peak" of the hero element (sword tip,
  crown peak, shield center, chest glow center). Each sprite can lean
  into its moment's hero color — gold for PR/milestone, purple-gold for
  level-up, purple for comeback — so forcing purple everywhere is not
  required; the Flutter overlay scrim is already a purple radial
  gradient and will tie the 4 sprites together at composite time.

---

## §1 · Master style-lock prompt (paste first)

> ```
> You are a senior pixel-art illustrator producing a cohesive asset set for
> RepSaga, a mobile gym-RPG app. The entire app's visual identity is retro
> 16/32-bit JRPG pixel art — think Chrono Trigger UI + Stardew Valley stats
> panel + classic SNES Final Fantasy menu chrome, with a dark-arcane mood.
>
> STRICT RULES — enforce every generation, no exceptions:
>
> 1. TRUE PIXEL ART ONLY.
>    - No anti-aliasing, no gradients, no soft edges, no 3D shading, no
>      blur, no bokeh, no film grain, no photographic textures, no modern
>      vector look, no flat-illustration look, no isometric 3D, no voxel.
>    - Every shape is built from hard-edged square pixels of one consistent
>      unit size per asset.
>    - Dithering for shading is allowed and encouraged (Bayer or
>      checkerboard) but never gradient smoothing.
>    - Nearest-neighbor scaling only. If output is 1024×1024, the artwork
>      underneath is drawn at a low native resolution (e.g. 32×32, 64×64,
>      128×128) and upscaled cleanly — the upscaled pixel must be a perfect
>      square of N×N display pixels.
>
> 2. CANVAS.
>    - Transparent PNG background unless the asset explicitly calls for a
>      colored background (e.g. app icon, splash art).
>    - Centered composition with padding, readable at 25% zoom.
>
> 3. PALETTE (hex codes — use ONLY these, no near-variants).
>    Background / stone:
>      #000000   true black (outlines)
>      #0D0319   abyss purple (deepest shadow, background)
>      #2A0E4A   deep purple (panel fills, mid background)
>      #3A1466   rich purple (panel borders, arcane energy mid-tone)
>      #6A2FA8   arcane violet (lightning, magic glow mid-tone)
>      #8A3DC1   arcane violet bright (glow highlight)
>      #B36DFF   arcane pale (glow peaks, sparkle)
>      #4A4560   iron grey (stone frames, armor mid-tone)
>      #6A6585   iron grey light (armor highlights, panel rims)
>      #2A1A0F   leather dark (strap, book cover shadow)
>
>    Gold primary (THE hero color — use on nearly every asset):
>      #7A4D00   gold deep shadow
>      #D9B864   gold mid
>      #FFB800   gold (main)
>      #FFD54F   gold highlight
>      #FFF1B8   gold sparkle (tiny accents only)
>
>    Stat accents (one per semantic):
>      #E03A3A   STR / health red
>      #FF6B6B   STR highlight
>      #3EC46D   VIT / life green
>      #82E39A   VIT highlight
>      #3BB0E6   END / stamina blue
>      #7FD1F2   END highlight
>      #FFFFFF   pure white (use very sparingly, only for tiny highlight dots)
>      #F3E6C6   parchment cream (scrolls, light text on dark panels)
>
> 4. LIGHTING.
>    - Single light source from the UPPER-LEFT on every asset. Highlights on
>      top-left facets, shadows on bottom-right. Do not deviate between
>      assets, or the set will not feel cohesive.
>    - Rim highlight on metallics (gold, iron): one row of #FFD54F or
>      #6A6585 on the top-left edge.
>    - Drop shadow: a single column/row of #000000 on the opposite side.
>
> 5. MOOD.
>    - Dark fantasy, arcane, medieval RPG. Purple lightning/aura is a motif
>      — use it sparingly to add energy around hero elements.
>    - Gold is precious — it is the reward color. Never use gold for chrome
>      or inactive states.
>
> 6. TYPOGRAPHY IN ASSETS.
>    - Any text rendered inside an asset uses the "Press Start 2P" bitmap
>      serif look: blocky uppercase, 1-pixel stroke, gold fill with a
>      2-pixel purple drop-shadow and a 1-pixel black outline.
>    - Do NOT invent Latin-alphabet-only words — the copy I give in each
>      asset prompt is final; render it character-by-character.
>
> 7. OUTPUT.
>    - Produce ONE image per request, centered, with the specified canvas
>      size as a square PNG.
>    - Include a 2–4 pixel transparent margin on all sides so the art
>      doesn't clip.
>    - After generating, confirm the "native pixel grid" (e.g. 32×32 art
>      upscaled to 1024×1024 = every 32 display-pixels = 1 art-pixel). If
>      the scaling is off, redo.
>
> Acknowledge with a single line: "Style locked. Ready for assets." Then
> wait for my asset prompts. Do not generate anything yet.
> ```

---

## §2 · Palette reference card (already embedded in §1 — here for your quick copy)

| Role | Hex |
|---|---|
| True black (outlines) | `#000000` |
| Abyss purple (deepest) | `#0D0319` |
| Deep purple (panel fill) | `#2A0E4A` |
| Rich purple (panel border) | `#3A1466` |
| Arcane violet mid | `#6A2FA8` |
| Arcane violet bright | `#8A3DC1` |
| Arcane pale (glow peak) | `#B36DFF` |
| Iron grey | `#4A4560` |
| Iron grey light | `#6A6585` |
| Leather dark | `#2A1A0F` |
| Gold deep shadow | `#7A4D00` |
| Gold mid | `#D9B864` |
| **Gold main** | `#FFB800` |
| Gold highlight | `#FFD54F` |
| Gold sparkle | `#FFF1B8` |
| STR / health red | `#E03A3A` |
| STR highlight | `#FF6B6B` |
| VIT / life green | `#3EC46D` |
| VIT highlight | `#82E39A` |
| END / stamina blue | `#3BB0E6` |
| END highlight | `#7FD1F2` |
| Parchment cream | `#F3E6C6` |
| Pure white (tiny highlights) | `#FFFFFF` |

---

## §3 · Canvas-size reference

| Asset class | Native pixel grid | Output PNG | Upscale factor |
|---|---|---|---|
| App icon (launcher, Play Store) | 64×64 | 1024×1024 | ×16 |
| Nav tab icon (5 tabs) | 32×32 | 512×512 | ×16 |
| Rank badge (7 ranks) | 48×48 | 768×768 | ×16 |
| Milestone artwork (timeline cards) | 48×48 | 768×768 | ×16 |
| Stat icon (6 radar stats) | 32×32 | 512×512 | ×16 |
| Quest-type icon (3) | 32×32 | 512×512 | ×16 |
| Celebration hero sprite | 64×64 | 1024×1024 | ×16 |
| Micro sprite (heart, xp crystal, padlock) | 16×16 | 256×256 | ×16 |
| Splash / onboarding hero illustration | 128×128 | 1024×1024 | ×8 |
| Panel frame corner piece (if needed) | 16×16 | 256×256 | ×16 |
| Wordmark / logo type | 128×32 | 1024×256 | ×8 |

**Always:** transparent background (unless the asset requires a backdrop),
center composition, 2–4 px margin, one light source upper-left.

---

## §4 · Per-asset prompts

Paste any one of these *after* §1 has been acknowledged. Each prompt is
self-contained: it restates the critical rules so you can also use it alone
in a new chat.

---

### 4.1 · App icon

**File:** `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (1024×1024
for Play Store, plus Android generates smaller sizes)
**Save-as:** `repsaga_app_icon_1024.png`

> ```
> Generate the RepSaga Android launcher app icon. Canvas 1024×1024, native
> pixel grid 64×64 upscaled ×16 with nearest-neighbor.
>
> Composition: a single upright dumbbell whose bar is a glowing golden
> medieval sword hilt, standing on a stone pedestal. Purple arcane
> lightning bolts radiate from behind the dumbbell/sword in a symmetric
> X pattern. Below, a compact banner in gold with black outline reads
> "REPSAGA" in Press-Start-2P blocky serif, letters filled with
> #FFB800, drop-shadow #7A4D00, outline #000000.
>
> Background: rounded-corner square (Android adaptive icon safe zone),
> filled with a 2-stop vertical pixel gradient using only two flat
> colors — top #2A0E4A, bottom #0D0319. No true gradient, two hard-edged
> bands joined by 3 rows of 50%-dither in between.
>
> Palette enforcement: only the hex codes defined in the RepSaga
> style lock (purples, golds, iron grey, true black, arcane violet).
> Gold is the hero color — the dumbbell and wordmark are #FFB800 with
> #FFD54F rim highlight on the upper-left facets and #7A4D00 shadow
> on the lower-right. Arcane lightning uses #8A3DC1 mid with #B36DFF
> single-pixel sparkle peaks.
>
> No anti-aliasing. Hard pixel edges. Upper-left light source.
> ```

---

### 4.2 · Splash / loading logo (wordmark + sword emblem)

**Save-as:** `repsaga_wordmark_1024.png`
**Flutter path:** `assets/pixel/branding/repsaga_wordmark.png`

> ```
> Generate the RepSaga wordmark for the splash screen. Canvas 1024×256,
> native grid 128×32 upscaled ×8.
>
> Composition, left to right:
>   [sword-dumbbell emblem 32×32 native]  [wordmark "REPSAGA" 80×24 native]
>
> The sword-dumbbell emblem is a small version of the app icon glyph: a
> vertical dumbbell whose shaft is a sword hilt, 32×32, pure silhouette
> in #FFB800 with #FFD54F top-left highlight and #7A4D00 bottom-right
> shadow, 1-pixel #000000 outline.
>
> The wordmark: the seven letters R-E-P-S-A-G-A rendered as chunky
> pixel-serif caps, each letter 10 pixels wide × 18 pixels tall in
> native, 2-pixel spacing between letters. Letter fill #FFB800, top-left
> highlight #FFD54F (1 pixel), bottom-right drop-shadow #7A4D00 (2
> pixels), outline #000000 (1 pixel). Under the wordmark, a tiny 1-pixel
> purple underline row in #6A2FA8.
>
> Transparent background. Single upper-left light. No anti-aliasing. No
> gradients.
> ```

---

### 4.3 · Navigation bar icons (5 icons, active + inactive states)

Our app tabs: **Home**, **Exercises**, **Routines**, **PRs / Records**,
**Profile / Hero**. Generate each icon in two states:

- **Active:** full color, gold #FFB800 as primary, arcane violet #8A3DC1 accent.
- **Inactive:** monochrome — same silhouette in iron grey #4A4560 fill with
  #6A6585 top-left highlight, #000000 outline, no gold, no arcane accent.

Each: canvas 512×512, native grid 32×32, transparent background.

**Shared aura rules — apply to every active nav sprite below, not inactive:**

1. A 2-pixel `#B36DFF` aura hugs the sprite's outer silhouette; a looser
   1-pixel `#6A2FA8` halo sits just outside that aura. Hard pixel steps,
   no blur, no gradient.
2. Four 2×2-pixel `#B36DFF` sparkles, one in each corner of the bounding
   box ~3 px inset; each sparkle has a 1-px `#FFF1B8` hot center.
3. One extra `#FFD54F` or `#FFF1B8` interior highlight pixel on the
   sprite's "center of action" (sword gem, dumbbell rim, door handle,
   scroll wax seal, hood clasp).
4. Transparent background. 1-pixel `#000000` outline on the sprite itself
   (aura sits outside the outline, not on it).

Inactive sprites never get the aura or sparkles.

---

#### 4.3.1 Home → pixel cottage/temple

**Save-as:** `nav_home_active_512.png` / `nav_home_inactive_512.png`
**Flutter path:** `assets/pixel/nav/home_{active,inactive}.png`

> ```
> Pixel-art icon: a compact medieval-RPG home/base. 32×32 native, 512×512
> output. A small stone-brick cottage with a pointed wooden shingle roof,
> a round wooden door, two square windows with a warm gold glow inside
> (#FFB800 at 50% fill), and a single upright sword with a purple-amethyst
> pommel leaning against the front-left wall. The cottage sits on a
> 3-pixel base of grey cobblestone. Active version: roof shingles #7A4D00,
> walls #6A6585, door #2A1A0F with #D9B864 knob, window glow #FFB800
> fading to #FFF1B8 in the center pixel, sword blade #FFD54F with #FFB800
> shadow, sword pommel #B36DFF, outline #000000. Apply the shared active-
> aura rules from §4.3: 2-px #B36DFF aura, 1-px #6A2FA8 halo, 4 corner
> sparkles, 1 gold highlight pixel on the sword pommel. Inactive version:
> the same silhouette in flat #4A4560 fill with #6A6585 top-left
> highlight, no gold, no window glow, no aura, no sparkles, outline
> #000000. Transparent bg. Upper-left light.
> ```

---

#### 4.3.2 Exercises → crossed dumbbells with halo

**Save-as:** `nav_exercises_active_512.png` / `nav_exercises_inactive_512.png`
**Flutter path:** `assets/pixel/nav/exercises_{active,inactive}.png`

> ```
> Pixel-art icon: two dumbbells crossed in an X shape, centered. 32×32
> native, 512×512 output. Each dumbbell bar is 2 pixels thick, 18 pixels
> long, with 6×6-pixel weight plates on each end. Active version:
> dumbbell plates #FFB800 with #FFD54F top-left rim, bar #D9B864, one
> extra #FFF1B8 pixel highlight at the center cross-over, outline
> #000000. Apply the shared active-aura rules from §4.3: 2-px #B36DFF
> aura hugging the X silhouette, 1-px #6A2FA8 halo outside that, 4
> sparkles in the outer corners of the bbox. Inactive version: flat iron
> grey #4A4560 fill, #6A6585 top-left highlight, no aura, no sparkles,
> outline #000000. Transparent bg. Upper-left light.
> ```

---

#### 4.3.3 Routines → pixel-art scroll

**Save-as:** `nav_routines_active_512.png` / `nav_routines_inactive_512.png`
**Flutter path:** `assets/pixel/nav/routines_{active,inactive}.png`

> ```
> Pixel-art icon: an unfurled parchment scroll tied at the bottom with a
> red wax ribbon. 32×32 native, 512×512 output. Parchment body #F3E6C6
> with #D9B864 rolled-up ends top and bottom (each end 4 pixels tall),
> and three horizontal ink lines on the parchment in #2A1A0F representing
> routine entries. Active version: parchment cream, rolled ends gold
> #D9B864 with #FFD54F highlight, ribbon #E03A3A with a single #FF6B6B
> rim pixel and a 1-px #FFD54F highlight at the knot center, ink lines
> #2A1A0F, outline #000000. Apply the shared active-aura rules from
> §4.3. Inactive version: parchment flat #6A6585, ends #4A4560, ribbon
> flat #4A4560, ink lines #000000, no aura, no sparkles, outline
> #000000. Transparent bg. Upper-left light.
> ```

---

#### 4.3.4 PRs / Records → laurel-framed trophy

**Save-as:** `nav_prs_active_512.png` / `nav_prs_inactive_512.png`
**Flutter path:** `assets/pixel/nav/prs_{active,inactive}.png`

> ```
> Pixel-art icon: a two-handled medieval chalice/trophy surrounded by two
> curved laurel branches, one on each side. 32×32 native, 512×512 output.
> Chalice body #FFB800 with #FFD54F top-left rim and #7A4D00 bottom-right
> shadow. Each laurel branch is 6 leaves tall, leaves #3EC46D with
> #82E39A highlights in the active version. A single 1-pixel #FFF1B8
> sparkle on the chalice rim. Active version uses the full palette
> described. Apply the shared active-aura rules from §4.3. Inactive
> version: chalice flat #4A4560 with #6A6585 highlight, laurels flat
> #4A4560, no sparkle, no aura, outline #000000. Transparent bg.
> Upper-left light.
> ```

---

#### 4.3.5 Profile / Hero → hooded adventurer silhouette

**Save-as:** `nav_profile_active_512.png` / `nav_profile_inactive_512.png`
**Flutter path:** `assets/pixel/nav/profile_{active,inactive}.png`

> ```
> Pixel-art icon: a front-facing hooded adventurer portrait, shoulders-up,
> centered. 32×32 native, 512×512 output. The hood drapes down over the
> shoulders, face in shadow with only two glowing eyes visible. Active
> version: hood outer #3A1466, hood inner shadow #2A0E4A, shoulders cloak
> #6A2FA8 with #8A3DC1 top-left rim, eyes two glowing cross-shaped
> sparkles (1-pixel #FFB800 center with 4 #FFD54F diagonal rays), outline
> #000000. A thin 1-pixel gold #FFB800 clasp at the neckline serves as
> the interior highlight. Apply the shared active-aura rules from §4.3.
> Inactive version: entire silhouette in flat #4A4560 fill, #6A6585
> top-left highlight, empty hood (no eyes, no clasp), no aura, outline
> #000000. Transparent bg. Upper-left light.
> ```

---

### 4.4 · Rank badges (7 ranks)

All 48×48 native, 768×768 output. Each rank is a shield-shape badge with a
distinct glyph and banner.

**Family lock (enforced across all 7):**

- **Identical shield shape** — flat top with rivets at top-left and top-right
  corners, curved sides, rounded-pointed bottom. Draw once and copy across
  all 7; only fill color, glyph, and banner text differ.
- **Identical banner ribbon** — same forked-ends silhouette across all 7.
  Same pixel-serif font, same letter height (5 native px), same letter
  spacing.
- **No corner decorations** — no chemistry-symbol hints, no runes in the
  shield corners. A single 1-px `#FFF1B8` interior highlight at the shield's
  top-left (light-source indicator) is the only decoration.
- **Transparent background.** Upper-left light source.

**Ranks & shield colors (v2 palette, locked):**

| Rank | Shield fill | Top-highlight row | Central glyph |
|---|---|---|---|
| Rookie | `#F3E6C6` parchment | `#FFF1B8` | Wooden practice sword, upright, handle `#7A4D00`, blade `#D9B864` (bleached wood). No letters. |
| Iron | `#4A4560` iron grey | `#6A6585` | Iron dumbbell (two plates + bar, 3/4 view), plates `#2A1A0F` with `#4A4560` rim, bar `#6A6585`. NOT a pickaxe. |
| Copper | `#7A4D00` copper | `#D9B864` | Smith's hammer (head horizontal), head `#7A4D00` with `#D9B864` rim, handle `#2A1A0F` |
| Silver | `#6A6585` silver | `#B0B0C0` | Upright longsword, blade `#F3E6C6`, crossguard/pommel `#6A6585`, grip `#2A1A0F` |
| Gold | `#FFB800` gold | `#FFD54F` | Five-point crown, body `#FFB800`, 3 jewels `#B36DFF`, rim `#FFD54F` |
| Platinum | `#B36DFF` arcane | `#FFF1B8` | Five-point star, body `#B36DFF`, inner highlight `#FFF1B8` |
| Diamond | `#3BB0E6` cornflower | `#7FD1F2` | Faceted gem (diamond shape with internal facet lines), body `#7FD1F2`, top facet `#FFFFFF`, bottom facet `#3BB0E6` |

**Save-as:** `rank_{rookie,iron,copper,silver,gold,platinum,diamond}_768.png`
**Flutter path:** `assets/pixel/ranks/{rookie,...}.png`

**Recommended delivery format:** one 1536×1024 sheet with all 7 badges in a
2-row × 4-column grid (row 2 has 3). Generating all 7 at once locks the
shared silhouette and banner shape far better than 7 separate generations.

> ```
> Pixel-art shield badges for the RepSaga rank ladder — all 7 on one
> sheet, 2 rows × 4 cols (row 2 has only 3). 48×48 native per badge,
> 768×768 output per badge, transparent background.
>
> Family lock — enforce across all 7:
>   - IDENTICAL SHIELD SHAPE: flat top with 2-pixel rivets at the top-left
>     and top-right corners, curved sides, rounded-pointed bottom. Shield
>     is 40×44 pixels centered in a 48×48 cell. Draw the silhouette once
>     and reuse across all 7 — only the fill color, glyph, and banner
>     text differ.
>   - IDENTICAL BANNER RIBBON: same forked-ends silhouette across all 7.
>     Same pixel-serif font, same letter height (5 native pixels), same
>     letter spacing. Banner text in dark #2A1A0F on gold #FFB800 ribbon
>     with #7A4D00 shadow.
>   - NO CORNER DECORATIONS. No chemistry-symbol hints, no rune marks
>     inside or on top of the shield. A single 1-pixel #FFF1B8 interior
>     highlight at the shield's top-left corner is the only decoration
>     (light-source indicator).
>   - 1-pixel #000000 outline on every shield and banner silhouette.
>   - Transparent background. Upper-left light source on every glyph.
>
> Rank-specific fills, highlights, and glyphs (use the exact values
> below — do NOT re-interpret them):
>
>   - Rookie:   fill #F3E6C6 parchment, top-hl #FFF1B8.
>               Glyph: wooden practice sword upright, handle #7A4D00,
>               blade #D9B864 (bleached wood). NO LETTERS.
>               Banner text: ROOKIE.
>   - Iron:     fill #4A4560 iron grey (neutral, NOT slate-blue),
>               top-hl #6A6585.
>               Glyph: iron dumbbell 3/4 view — plates #2A1A0F with
>               #4A4560 rim, bar #6A6585. NOT a pickaxe.
>               Banner text: IRON.
>   - Copper:   fill #7A4D00 copper-brown, top-hl #D9B864.
>               Glyph: smith's hammer, head horizontal, head #7A4D00
>               with #D9B864 rim, handle #2A1A0F.
>               Banner text: COPPER.
>   - Silver:   fill #6A6585 silver, top-hl #B0B0C0.
>               Glyph: upright longsword — blade #F3E6C6, crossguard
>               and pommel #6A6585, grip #2A1A0F.
>               Banner text: SILVER.
>   - Gold:     fill #FFB800 gold, top-hl #FFD54F.
>               Glyph: five-point crown, body #FFB800 with #FFD54F rim,
>               3 jewels #B36DFF set across the band.
>               Banner text: GOLD.
>   - Platinum: fill #B36DFF arcane purple, top-hl #FFF1B8.
>               Glyph: five-point star, body #B36DFF, inner highlight
>               #FFF1B8.
>               Banner text: PLATINUM.
>   - Diamond:  fill #3BB0E6 cornflower blue, top-hl #7FD1F2.
>               Glyph: faceted gem — diamond shape with internal facet
>               lines, body #7FD1F2, top facet #FFFFFF, bottom facet
>               #3BB0E6.
>               Banner text: DIAMOND.
>
> Dark-fantasy, RPG-JRPG 16-bit style. No anti-aliasing, hard pixel edges.
> ```

---

### 4.5 · Milestone / Achievement artwork (6 key kinds)

All 48×48 native, 768×768 output. Milestones feel like *little trophies
inside pages of a saga* — each is a single standalone object on
transparent bg, with small gold sparkles in the outer corners.

**Save-as:** `milestone_{slug}_768.png`
**Flutter path:** `assets/pixel/milestones/{slug}.png`

**Family-lock rules** (apply to every prompt below):

1. **Backdrop-free.** No spotlight cones, no parchment washes, no
   vignettes. Transparent bg. The object stands alone.
2. **Sparkles:** exactly 3 small 4-pointed `#FFD54F` gold sparkles,
   each ≤6 px, in the outer corners outside the main object. Never
   purple, never diamond-shaped (diamond sparkles belong to nav-active
   auras in §4.3).
3. **No glyph collisions with rank badges (§4.4).** Do not use the crown,
   practice-sword, iron-dumbbell, hammer, longsword, five-point-star, or
   faceted-gem as a milestone's primary glyph — those belong to specific
   ranks and cause visual confusion on the character-sheet grid.
4. 1-pixel `#000000` outline on every shape. Upper-left light. No
   anti-aliasing.

---

#### 4.5.1 First workout — `milestone_first_workout_768.png`

> ```
> Pixel-art achievement icon: "First Workout". 48×48 native, 768×768 output.
> A small wooden 3-legged stool with a single gold dumbbell resting on top.
> Dumbbell plates #FFB800 with #FFD54F rim, bar #D9B864, stool #2A1A0F
> with #7A4D00 top-left highlight. 3 small 4-pointed #FFD54F gold
> sparkles (each ≤6 px) in the outer corners around the stool — NO
> spotlight cone, NO background wash. Transparent bg. Upper-left light.
> 1-pixel #000000 outline on every shape.
> ```

#### 4.5.2 7-week streak — `milestone_streak_7_768.png`

> ```
> Pixel-art achievement icon: "7-Week Streak". 48×48 native, 768×768
> output. A stone tablet etched with the numeral 7 in pixel-serif gold
> #FFB800 on a tablet of #4A4560 stone with #6A6585 top highlight.
> Seven tiny arcane violet rune marks (#8A3DC1) run along the top rim of
> the tablet, one per week. Three small laurel leaves #3EC46D curl from
> the bottom-left corner. 3 small 4-pointed #FFD54F gold sparkles
> (each ≤6 px) in the outer corners around the tablet — no background
> wash. Transparent bg. 1-pixel black outline.
> ```

#### 4.5.3 First PR — `milestone_first_pr_768.png`

> ```
> Pixel-art achievement icon: "First Personal Record". 48×48 native,
> 768×768 output. A medieval anvil #4A4560 (top highlight #6A6585, shadow
> #2A1A0F) with a small pile of gold coins #FFB800 on top, and a single
> heavy hammer #2A1A0F resting against its side. A rising thin golden
> curve above the anvil in #FFD54F represents the PR trend line climbing.
> 3 small 4-pointed #FFD54F gold sparkles (each ≤6 px) in the outer
> corners around the anvil — no background wash. Transparent bg.
> Upper-left light. Black outline.
> ```

#### 4.5.4 Rank promotion — `milestone_rank_up_768.png`

> ```
> Pixel-art achievement icon: "Rank Promotion". 48×48 native, 768×768
> output. An open wooden treasure chest with a large gold upward chevron
> (▲, 3-pixel-thick strokes) floating above it, rising out of the chest's
> glow. Chest body #7A4D00 with #2A1A0F iron bindings and a bright
> #FFD54F interior glow radiating upward in 3–4 dithered light rays.
> Chevron fill #FFB800 with #FFD54F top-left highlight and 1-pixel
> #FFF1B8 hot center on the tip. 3 small 4-pointed #FFD54F gold
> sparkles (each ≤6 px) in the outer corners of the canvas — NO purple
> sparks, NO crown (the crown is the Gold rank badge glyph and would
> collide in the achievement grid). 1-pixel black outline on every
> shape. Transparent bg. Upper-left light.
> ```

#### 4.5.5 100 workouts — `milestone_100_workouts_768.png`

> ```
> Pixel-art achievement icon: "100 Workouts". 48×48 native, 768×768
> output. A stack of three medieval tomes/books, spines facing the viewer.
> Top book #6A2FA8 with #8A3DC1 top-left rim and a single gold clasp
> #FFB800. Middle book #3A1466 with clasp, bottom book #2A0E4A. On the
> front cover of the top book, the numeral 100 in pixel-serif gold
> #FFB800 with #FFD54F highlight. A small feather quill #F3E6C6 rests
> on top. 3 small 4-pointed #FFD54F gold sparkles (each ≤6 px) in the
> outer corners around the book stack — no background wash, no purple
> sparks. Black outline. Transparent bg. Upper-left light.
> ```

#### 4.5.6 Quest streak — `milestone_quest_streak_768.png`

> ```
> Pixel-art achievement icon: "Quest Streak". 48×48 native, 768×768
> output. A pixel-art scroll mid-unfurl, with a bright green wax seal
> #3EC46D in the center and a quill #F3E6C6 crossed behind it. Scroll
> body #F3E6C6 with #D9B864 rolled ends. On the scroll face, three
> tiny gold checkmarks #FFB800. 3 small 4-pointed #FFD54F gold
> sparkles (each ≤6 px) in the outer corners around the scroll — no
> background wash, no purple sparks. Transparent bg. Black outline.
> Upper-left light.
> ```

---

### 4.6 · Stat icons (6 stats — for 18b radar + chip grid)

All 32×32 native, 512×512 output, transparent bg. One color-coded icon per
stat. Each is a front-view object with a 1-pixel colored aura.

**Save-as:** `stat_{slug}_512.png`
**Flutter path:** `assets/pixel/stats/{slug}.png`

| Stat | Slug | Object | Aura color |
|---|---|---|---|
| Strength | `strength` | Flexed pixel-art arm with bicep | `#E03A3A` |
| Endurance | `endurance` | Running boot with wind-lines | `#3BB0E6` |
| Power | `power` | Hammer strike with impact star | `#FFB800` |
| Consistency | `consistency` | Calendar with 4 gold checkmarks | `#3EC46D` |
| Volume | `volume` | Stack of 3 weight plates | `#B36DFF` |
| Mobility | `mobility` | Coiled rope / flexibility swirl | `#7FD1F2` |

> ```
> Pixel-art stat icon: "{STAT}". 32×32 native, 512×512 output, transparent
> bg. Centered object: {OBJECT DESCRIPTION}. Object fill uses the stat's
> accent color {AURA} as the dominant fill with its lighter tint as the
> top-left highlight (e.g. Strength → #E03A3A fill, #FF6B6B highlight).
> Surround the object with a 1-pixel aura outline in the same color
> {AURA}, and 3–4 sparkle pixels of #FFFFFF at 1-pixel size scattered
> just outside the aura. Black outline on all inner shapes. Upper-left
> light. No anti-aliasing.
> ```

---

### 4.7 · Quest-type icons (3)

**Save-as:** `quest_{slug}_512.png`
**Flutter path:** `assets/pixel/quests/{slug}.png`

| Type | Slug | Object | Primary color |
|---|---|---|---|
| Consistency | `consistency` | Calendar page with a bold ring on today | `#3EC46D` |
| Improvement | `improvement` | Upward arrow striking through a weight plate | `#FFB800` |
| Exploration | `exploration` | Compass rose with the N-needle glowing | `#8A3DC1` |

> ```
> Pixel-art quest-type icon: "{TYPE}". 32×32 native, 512×512 output,
> transparent bg. {OBJECT DESCRIPTION}. Primary fill color {PRIMARY}, with
> one tint lighter for the top-left highlight pixel. A 1-pixel arcane
> violet #8A3DC1 sub-outline sits just inside the black outline for the
> "magical quest" feel. Upper-left light. Black outline. No
> anti-aliasing. Hard pixel edges.
> ```

---

### 4.8 · Celebration hero sprites (4)

For the post-workout `CelebrationOverlay`. Each is a 64×64 native, 1024×1024
output, centered sprite that gets composited on a purple radial gradient
scrim by Flutter.

**Save-as:** `celebration_{slug}_1024.png`
**Flutter path:** `assets/pixel/celebration/{slug}.png`

**Family-lock rules** (locked by 4.8.1; every prompt below obeys):

1. Hero element fills the vertical center ~2/3 of canvas, with ~1/6
   padding top and bottom. Generous negative space around the edges.
2. A **radiating accent motif** surrounds the hero: lightning bolts
   (level_up), gold fan-rays (pr + milestone), mist + sparkles
   (comeback). Radiation is the family signature.
3. Each sprite leans into its moment's hero color — gold for PR and
   milestone, purple-gold for level-up, purple for comeback. Forcing
   purple into every sprite is not required; the Flutter overlay scrim
   (purple radial gradient) ties the family together at composite time.
4. One `#FFF1B8` sparkle sits at the "peak" of the hero element
   (sword tip, crown peak, shield center, chest glow center).
5. 1-pixel `#000000` outline. Upper-left light. Transparent bg.

---

#### 4.8.1 Level-up knight — `celebration_level_up_1024.png`

> ```
> Pixel-art celebration sprite: a full-body heroic pixel knight in
> triumphant victory pose. 64×64 native, 1024×1024 output, transparent bg.
> The knight is front-facing, feet apart, arms raised overhead, gripping a
> glowing golden longsword above their head with both hands. Knight
> silhouette: armor plate #4A4560 with #6A6585 top-left rim and #000000
> shadow, helmet closed with a single #B36DFF glowing eye-slit,
> shoulder pauldrons #6A2FA8, cape #3A1466 flaring behind. Sword blade
> #FFD54F core with #FFB800 mid and #FFF1B8 single-pixel tip sparkle,
> hilt #7A4D00 wrapped in leather #2A1A0F. Surround the knight with 8
> purple arcane lightning bolts radiating outward at 45° intervals,
> bolts 1-pixel wide, each 6 pixels long, in #8A3DC1 with single-pixel
> #B36DFF peaks. Black outline on knight. Upper-left light source.
> ```

#### 4.8.2 PR chest — `celebration_pr_1024.png`

> ```
> Pixel-art celebration sprite: a golden treasure chest burst open with
> light pouring out. 64×64 native, 1024×1024 output, transparent bg. Chest
> body #7A4D00 with #D9B864 top-left rim and #2A1A0F iron bands. Interior
> of the open chest is a solid block of #FFD54F gold glow fading outward
> with one ring of 50%-dither to #FFF1B8 in the center. Six rays of gold
> #FFB800 shoot upward from the chest at a fan, each ray 1-pixel wide at
> base widening to 3 pixels at tip. Two coins #FFD54F spill out the front.
> Black outline. Upper-left light.
> ```

#### 4.8.3 Comeback shield — `celebration_comeback_1024.png`

> ```
> Pixel-art celebration sprite: a heater shield rising from purple mist,
> with 2× multiplier marking. 64×64 native, 1024×1024 output, transparent
> bg. Shield body #FFB800 with #7A4D00 frame and #FFD54F top-left rim. In
> the center of the shield, pixel-serif "2×" in #2A1A0F outline with
> #F3E6C6 fill. Purple mist at the bottom of the canvas: three rows of
> 50%-dither in #6A2FA8 and transparent, rising. Six tiny #B36DFF sparkle
> pixels scattered around the shield. Black outline. Upper-left light.
> ```

#### 4.8.4 Milestone crown — `celebration_milestone_1024.png`

> ```
> Pixel-art celebration sprite: a floating crown with a velvet cushion
> beneath it. 64×64 native, 1024×1024 output, transparent bg. Crown gold
> #FFB800 with #FFD54F top-left rim, #7A4D00 bottom shadow, three
> #B36DFF single-pixel gems inset across the band, five #FFF1B8 sparkle
> peaks atop the crown points. Cushion #6A2FA8 with #8A3DC1 top rim,
> four gold #D9B864 tassels at its corners. Six radiating gold rays #FFB800
> behind the crown, 45° intervals, 1-pixel wide. Black outline.
> Upper-left light.
> ```

---

### 4.9 · Micro-sprites (reused across UI)

All 16×16 native, 256×256 output, transparent bg. These are the little
symbols that appear inside UI chrome (HP bar icon, XP counter, empty
states, locked badges).

**Save-as:** `micro_{slug}_256.png`
**Flutter path:** `assets/pixel/micro/{slug}.png`

| Sprite | Slug | Description |
|---|---|---|
| HP heart | `hp_heart` | Red pixel heart, 3 highlight pixels upper-left |
| XP crystal | `xp_crystal` | Violet diamond gem with sparkle |
| Streak flame-glyph | `streak_glyph` | A small gold shield with a number slot (filled with `7` as an example — generate blank) |
| Locked padlock | `locked` | Grey iron padlock |
| Checkmark | `check` | Gold checkmark |
| Quest chip marker | `quest_marker` | Compact scroll curl with gold seal |
| Coin | `coin` | Gold coin face-on with R glyph |
| Empty state "tavern" | `empty_tavern` | A hanging wooden sign with "?" |

> ```
> Pixel-art micro sprite: "{SPRITE NAME}". 16×16 native, 256×256 output,
> transparent bg. {DESCRIPTION}. Follow the RepSaga locked palette only.
> 1-pixel black outline. Upper-left light source. No anti-aliasing.
> ```

(Substitute `{SPRITE NAME}` and `{DESCRIPTION}` from the table.)

---

### 4.10 · Onboarding / empty-state illustrations (3)

Larger narrative pieces. 128×128 native, 1024×1024 output. These carry
heavier storytelling than the UI icons — think Stardew Valley title-card
vignettes.

**Save-as:** `story_{slug}_1024.png`
**Flutter path:** `assets/pixel/story/{slug}.png`

---

#### 4.10.1 Empty "no workouts yet" — `story_empty_gym_1024.png`

> ```
> Pixel-art scene: the interior of an empty medieval training hall,
> shown from a front-facing 2D side view (not isometric). 128×128 native,
> 1024×1024 output, transparent bg.
>
> Content: stone floor (#4A4560 bricks with #2A1A0F grout lines) across
> the bottom 20 pixels. A cozy gym corner: wall of #3A1466 stone in the
> back, torch sconces left and right (#FFB800 flame with #FFD54F core,
> #FF6B6B ember pixel), a rack with two resting dumbbells of graduated
> weights (#D9B864 to #7A4D00), an unrolled pixel-art yoga mat in #6A2FA8
> on the floor, and a wooden stool #2A1A0F to the right. Dust-mote
> particles: 5 single-pixel #F3E6C6 dots scattered mid-air. Upper-left
> light source casts subtle dithered shadows on the floor. Black outlines.
> Dark-fantasy RPG mood, inviting despite the emptiness — "your saga
> begins here".
> ```

#### 4.10.2 Onboarding hero — `story_your_saga_begins_1024.png`

> ```
> Pixel-art scene: a hooded adventurer standing in front of the same
> medieval training hall from scene 4.10.1, shoulders-up silhouette
> centered on-canvas. 128×128 native, 1024×1024 output, transparent bg.
>
> The adventurer's cloak #3A1466 with #6A2FA8 shoulder rim, hood #2A0E4A
> casting face in shadow, two glowing #B36DFF eye pixels with #FFF1B8
> centers. Behind them, the training hall interior from 4.10.1 slightly
> simplified (torches, wall, single dumbbell rack). Above the adventurer,
> floating in pixel-serif gold "YOUR SAGA BEGINS" in #FFB800 with #7A4D00
> drop-shadow and #000000 outline, letters 8 pixels tall. Upper-left
> light. Hard pixel edges, no anti-aliasing.
> ```

#### 4.10.3 First-workout invitation — `story_first_workout_1024.png`

> ```
> Pixel-art scene: a single dumbbell sitting under a golden spotlight on
> a stone pedestal. 128×128 native, 1024×1024 output, transparent bg.
>
> Pedestal: 3 stone steps in #4A4560 with #6A6585 top highlight, 24
> pixels wide at the base tapering to 14 at the top. On the pedestal, a
> dumbbell in #FFB800 gold with #FFD54F top rim and #7A4D00 shadow.
> Descending from above, a spotlight cone (5 pixels wide at apex
> widening to 30 at the pedestal) in #FFF1B8 at 50%-dither fading to
> transparent. Six sparkle pixels #FFF1B8 floating around the dumbbell.
> Background: dark #0D0319 radial-feel with 3 rows of 50%-dither to
> #2A0E4A at the edges. Upper-left light. Black outline on all solid
> shapes.
> ```

---

### 4.12 · Exercise category icons (14)

All 32×32 native, 256×256 output, transparent bg around each sprite.
These appear on exercise list rows, filter chips at the top of the
Exercises tab, and the create-exercise form. Drawn from two adjacent
families — **muscle groups** (body-target icons) and **equipment types**
(object icons). Both share the "selectable/filterable" family-lock
convention inherited from §4.7 quests.

**Save-as:** `exercise_muscle_sheet.png`, `exercise_equipment_sheet.png`
(one ChatGPT turn per sheet → we split into 14 PNGs locally).

**Flutter paths:** `assets/pixel/muscle/{slug}.png`,
`assets/pixel/equipment/{slug}.png`

**Family-lock rules (apply to both sheets):**
1. 1-px `#8A3DC1` purple sub-outline inside 1-px `#000000` outer outline
   — marks sprites as "tap to filter" (same rule as §4.7 quests).
2. Upper-left light source; no anti-aliasing; palette only.
3. **Muscle family:** iron-grey `#4A4560`/`#6A6585` body silhouette with
   the targeted muscle region glowing gold `#FFB800` core + 1-px
   `#FFD54F` hot pixel inside the gold patch. No facial/hand detail —
   silhouettes only. Reads like a medical anatomy chart at a glance.
4. **Equipment family:** iron-grey `#4A4560`/`#6A6585` body + gold
   `#FFB800`/`#D9B864` accents for loads/handles/pins. Bodyweight is the
   only all-gold sprite (hero silhouette, no equipment).
5. Every sprite must be readable at 32×32 native — silhouettes must have
   a distinct overall outline (shoulder V ≠ flexed arm ≠ core torso).

---

#### 4.12.1 Muscle group sheet — `exercise_muscle_sheet.png`

Generate as one 4 cols × 2 rows sheet. Bottom-right slot is intentionally
blank (only 7 icons needed).

| Slot | Sprite | Slug | Description |
|---|---|---|---|
| 1 | Chest | `chest` | Front-view male torso silhouette; upper-pec region (both sides of sternum) glowing gold |
| 2 | Back | `back` | Rear-view torso silhouette (no face); V-shaped lat taper + upper-back glowing gold |
| 3 | Legs | `legs` | Lower-body silhouette from waist down (both quads visible, knees visible); thigh region glowing gold |
| 4 | Shoulders | `shoulders` | Front-view upper torso (head + shoulders + upper chest); both deltoids glowing gold, symmetric |
| 5 | Arms | `arms` | Single flexed bicep pose (one arm bent upward in classic "flex", torso faint in background); bicep + tricep glowing gold |
| 6 | Core | `core` | Front-view torso silhouette; 6-pack abdominal grid glowing gold (2×3 gold patch in abdomen area) |
| 7 | Cardio | `cardio` | Full-body side-view running figure mid-stride, legs spread; entire silhouette glowing gold (not localized — cardio is whole-body) |

> ```
> Pixel-art sheet: 7 exercise muscle-group icons arranged as 4 cols × 2
> rows (bottom-right 8th slot intentionally blank). Each icon 32×32
> native, scaled to 256×256 in the sheet. White background around the
> whole sheet; each sprite has transparent bg at its slot.
>
> Family-lock: every sprite is an iron-grey #4A4560 body silhouette with
> the targeted muscle region highlighted as a gold #FFB800 patch plus a
> single #FFD54F hot-core pixel inside the gold. 1-pixel #8A3DC1 purple
> sub-outline inside 1-pixel #000000 black outer outline on every sprite.
> Upper-left light source. No anti-aliasing. RepSaga locked palette only.
>
> Slot 1 (chest): front-view torso, upper-pec region glowing gold.
> Slot 2 (back): rear-view torso (no head detail), V-taper lats + upper
>   back glowing gold.
> Slot 3 (legs): front-view lower body, waist-down, both quads glowing
>   gold, knees visible at bottom.
> Slot 4 (shoulders): front-view head + upper torso, both deltoids
>   glowing gold symmetrically.
> Slot 5 (arms): single flexed bicep pose, one arm bent upward, bicep +
>   tricep glowing gold. Faint torso behind the arm.
> Slot 6 (core): front-view torso, 6-pack abdominal grid glowing gold
>   (2 columns × 3 rows of gold pixels).
> Slot 7 (cardio): full-body side-view running figure mid-stride, whole
>   silhouette glowing gold (not localized).
> ```

---

#### 4.12.2 Equipment sheet — `exercise_equipment_sheet.png`

Generate as one 4 cols × 2 rows sheet. Bottom-right slot is intentionally
blank.

| Slot | Sprite | Slug | Description |
|---|---|---|---|
| 1 | Barbell | `barbell` | Horizontal iron bar with 2 gold weight plates per side, gold sleeves, iron knurled grip in middle |
| 2 | Dumbbell | `dumbbell` | Side-view dumbbell — iron handle with 2 stacked gold weight discs at each end |
| 3 | Cable | `cable` | Iron pulley frame + a single cable descending to a gold D-handle; small iron weight-stack visible behind |
| 4 | Machine | `machine` | Selectorized weight-stack machine (no seat) — iron frame + stacked weight plates + gold selector pin sticking out mid-stack |
| 5 | Bodyweight | `bodyweight` | Gold hero silhouette in a power pose (arms raised in a star/V shape) — the ONLY all-gold sprite in the sheet |
| 6 | Bands | `bands` | Two gold handle-grips left and right, connected by an iron-grey resistance-band loop arching between them |
| 7 | Kettlebell | `kettlebell` | Side-view kettlebell — iron round body + gold arched top handle + small gold medallion emblem centered on the face |

> ```
> Pixel-art sheet: 7 exercise equipment icons arranged as 4 cols × 2
> rows (bottom-right 8th slot intentionally blank). Each icon 32×32
> native, scaled to 256×256 in the sheet. White background around the
> whole sheet; each sprite has transparent bg at its slot.
>
> Family-lock: iron-grey #4A4560/#6A6585 base with gold #FFB800/#D9B864
> accents for loads, handles, and pins. 1-pixel #8A3DC1 purple sub-
> outline inside 1-pixel #000000 black outer outline on every sprite.
> Upper-left light source. No anti-aliasing. RepSaga locked palette only.
>
> Slot 1 (barbell): horizontal iron bar, 2 gold weight plates per side,
>   gold bar sleeves flanking iron knurled middle grip.
> Slot 2 (dumbbell): side-view dumbbell, iron handle, 2 gold weight
>   discs stacked each end.
> Slot 3 (cable): iron pulley frame with a single cable descending to a
>   gold D-handle; small iron weight-stack visible behind.
> Slot 4 (machine): selectorized weight-stack machine — iron cage frame,
>   visible stack of iron weight plates, gold selector pin sticking out
>   of the stack at mid-height. No seat/pad — just the stack + frame.
> Slot 5 (bodyweight): full gold hero silhouette in a V-pose (arms
>   raised), the ONLY all-gold sprite in the sheet — no equipment
>   depicted, this represents the athlete themselves.
> Slot 6 (bands): two gold handle-grips (left + right), connected by an
>   iron-grey resistance-band elastic loop arching between them.
> Slot 7 (kettlebell): side-view kettlebell — iron round body + gold
>   arched top handle + small gold medallion emblem centered on the
>   body face.
> ```

---

## §5 · Flutter asset registration

Once you have the PNGs saved into `assets/pixel/…`, register the root in
`pubspec.yaml` so Flutter bundles them:

```yaml
flutter:
  assets:
    - assets/pixel/branding/
    - assets/pixel/nav/
    - assets/pixel/ranks/
    - assets/pixel/milestones/
    - assets/pixel/stats/
    - assets/pixel/quests/
    - assets/pixel/celebration/
    - assets/pixel/micro/
    - assets/pixel/story/
    - assets/pixel/muscle/
    - assets/pixel/equipment/
```

When rendering pixel-art in Flutter, **always** use:

```dart
Image.asset(
  'assets/pixel/nav/home_active.png',
  filterQuality: FilterQuality.none,
  fit: BoxFit.contain,
)
```

`FilterQuality.none` is the Flutter equivalent of CSS `image-rendering:
pixelated` — it tells the GPU to use nearest-neighbor instead of bilinear
scaling, which is the *whole point* of shipping pixel art. Without it, the
PNGs get blurred and look like generic dark illustrations.

---

## §6 · Generation workflow tips

1. **Lock first, then generate.** Paste §1 and wait for "Style locked." If the
   model skips that step, paste it again.
2. **Generate the app icon first.** It sets the tone. If it doesn't feel
   right, iterate until it does — everything else will inherit this look.
3. **Then generate the 7 rank badges together in a row.** These must feel
   like a family. Generate all 7, compare, regenerate any outliers.
4. **Then nav icons as a set of 5 (active only).** Active set first, then
   ask the model to "produce the inactive/monochrome variants of the 5 nav
   icons above using only #4A4560 fill and #6A6585 highlight."
5. **Milestones + stats + quests + celebrations** can be done in any order.
6. **Micro sprites last** — small, low-risk, quick to re-do.
7. **If the model starts drifting** (adding gradients, softening edges,
   adding photographic textures), respond: *"Revert to the locked RepSaga
   pixel-art rules. Hard pixel edges, no anti-aliasing, palette only, nearest-
   neighbor scaling from the native grid."*
8. **Save every approved asset immediately** to its target filename. Don't
   wait until the end — chat history can expire.
9. **When done, drop the full folder into `repsaga/assets/pixel/`**, run
   `flutter pub get`, and hand the branch back to me so I can wire the
   assets into the Flutter UI.

---

## §7 · Asset checklist (57 files total)

**Progress: 63 / 71 saved.** Tick off as each PNG lands in `assets/pixel/`.
(Total raised from 57 → 71 after §4.12 added 14 exercise category sprites.)

**Milestone family conventions** (enforced in §0 Decision Log):
- Backdrop-free: no spotlight cones, no parchment washes.
- Sparkles: 3 small 4-pointed `#FFD54F` gold, ≤6 px, outer corners only. No purple, no diamond-shaped.
- No glyph collisions with rank badges (no crowns, swords, hammers, gems, stars used as the hero glyph).

### Branding (2)
- [x] `branding/repsaga_app_icon.png` (1024×1024) — saved 2026-04-22. Wordmark is baked into the banner, which is fine for the Play Store / launcher icon.
- [x] `branding/repsaga_wordmark.png` (1024×256 → actual ~1536×1024) — saved 2026-04-22. Sword-through-dumbbell emblem on the left, gold beveled "REPSAGA" letters on transparent background. Works for splash screens and in-app headers.

### Navigation (10 — 5 active + 5 inactive)
- [x] `nav/home_active.png` (512×512) — **re-saved 2026-04-22 with aura-locked style.** Stone cottage with brown tile roof, lit windows, sword leaning on the front wall, now with violet aura + corner sparkles.
- [x] `nav/home_inactive.png` (512×512) — re-saved 2026-04-22 from the combined 3×2 sheet. Monochrome desaturated cottage.
- [x] `nav/exercises_active.png` (512×512) — re-saved 2026-04-22 from the combined 3×2 sheet. Crossed gold dumbbells with violet aura + sparkles.
- [x] `nav/exercises_inactive.png` (512×512) — re-saved 2026-04-22 from the combined 3×2 sheet. Monochrome gunmetal crossed dumbbells.
- [x] `nav/routines_active.png` (512×512) — saved 2026-04-22. Unfurled parchment scroll with gold rod ends, horizontal ruled lines, red wax ribbon tied around the bottom, violet aura + sparkles.
- [x] `nav/routines_inactive.png` (512×512) — saved 2026-04-22. Monochrome gunmetal scroll, transparent bg.
- [x] `nav/prs_active.png` (512×512) — saved 2026-04-22. Gold two-handled chalice flanked by green laurel wreaths, violet aura + corner sparkles.
- [x] `nav/prs_inactive.png` (512×512) — saved 2026-04-22. Monochrome gunmetal chalice + laurel wreath, transparent bg.
- [x] `nav/profile_active.png` (512×512) — saved 2026-04-22. Hooded purple cloak with glowing gold cross-shaped eyes and a single gold clasp, violet aura + corner sparkles.
- [x] `nav/profile_inactive.png` (512×512) — saved 2026-04-22. Monochrome gunmetal empty-hood silhouette, no face, transparent bg.

### Ranks (7)
- [x] `ranks/rookie.png` (768×768) — saved 2026-04-22 (v2). Parchment shield with wooden practice sword glyph, ROOKIE banner.
- [x] `ranks/iron.png` (768×768) — saved 2026-04-22 (v2). Iron-grey shield with iron dumbbell glyph, IRON banner.
- [x] `ranks/copper.png` (768×768) — saved 2026-04-22 (v2). Copper-brown shield with smith's hammer glyph, COPPER banner.
- [x] `ranks/silver.png` (768×768) — saved 2026-04-22 (v2). Silver shield with upright longsword glyph, SILVER banner.
- [x] `ranks/gold.png` (768×768) — saved 2026-04-22 (v2). Gold shield with jeweled crown glyph, GOLD banner.
- [x] `ranks/platinum.png` (768×768) — saved 2026-04-22 (v2). Arcane-purple shield with five-point star glyph, PLATINUM banner.
- [x] `ranks/diamond.png` (768×768) — saved 2026-04-22 (v2). Cornflower-blue shield with faceted gem glyph, DIAMOND banner.

All 7 share identical shield + banner silhouettes; only fill color + glyph + banner text differ. Split with gap-based column detection (neighbor-bleed-safe) from the 1536×1024 v2 sheet.

### Milestones (6)
- [x] `milestones/first_workout.png` (768×768) — **re-saved 2026-04-22 (v3, backdrop-free).** Gold dumbbell resting on a dark wooden 3-legged stool, 2 gold corner sparkles, transparent bg. Cone backdrop dropped in favor of the backdrop-free family convention.
- [x] `milestones/streak_7.png` (768×768) — saved 2026-04-22. Dark stone tablet etched with large gold "7", 7 purple runes across the top rim, green laurel leaves climbing the bottom-left corner. Transparent bg. *Missing 2–3 gold corner sparkles per convention — regen on next pass, low priority.*
- [x] `milestones/first_pr.png` (768×768) — saved 2026-04-22. Iron anvil with gold coin pile + hammer resting against the side, rising gold PR-trend line above. Transparent bg. *Missing 2–3 gold corner sparkles per convention — regen on next pass, low priority.*
- [x] `milestones/rank_up.png` (768×768) — saved 2026-04-22 (v1, **drift flagged**). Gold crown floating over open chest with purple sparks. **Hero glyph collides with Gold rank badge crown, and sparkle count/color violates milestone convention (12 purple diamonds vs 2–3 gold corner sparkles rule).** Regen recommended with chevron-over-chest + gold corner sparkles — prompt already updated in §4.5.4.
- [x] `milestones/100_workouts.png` (768×768) — saved 2026-04-23. Stack of 3 purple tomes with gold "100" on top cover, gold clasps on each spine, cream quill resting on top, 4 gold corner sparkles (1 over tightened 3-sparkle rule — acceptable). Transparent bg.
- [x] `milestones/quest_streak.png` (768×768) — saved 2026-04-23. Unfurled parchment scroll with 3 gold descending checkmarks down the left face, green wax seal center with cross imprint, cream quill tucked behind, 4 gold corner sparkles (same +1 drift as 100_workouts, matched pair). Transparent bg.

**Milestone family status:** 6/6 landed. Known low-priority regens on the next pass: streak_7 + first_pr (missing corner sparkles), rank_up (crown/Gold collision + 12 purple sparks vs 3-gold rule), 100_workouts + quest_streak (4 sparkles vs tightened 3-rule). All prompts in §4.5.1–§4.5.6 already encode the tight convention, so future regens will land compliant.

### Stats (6)
- [x] `stats/strength.png` (512×512) — saved 2026-04-23. Red flexed bicep with red aura + corner sparkle. Source had black bg with scan-line noise; cleaned via connected-component despeckle pass.
- [x] `stats/endurance.png` (512×512) — saved 2026-04-23. Blue running shoe with blue motion streaks (motion lines intentional per prompt). Transparent bg.
- [x] `stats/power.png` (512×512) — saved 2026-04-23. Iron hammer with gold flame/impact aura radiating out. Transparent bg.
- [x] `stats/consistency.png` (512×512) — saved 2026-04-23. Green calendar body with 6 gold check marks laid out on white page. Transparent bg.
- [x] `stats/volume.png` (512×512) — saved 2026-04-23. Stack of 3 purple weight plates (side profile). *Reads more like "stacked tins" at zoomed-in view than plates — fine at stat-chip size, flag for potential regen if the character-sheet reveal looks off.*
- [x] `stats/mobility.png` (512×512) — saved 2026-04-23. Coiled blue rope with leather strap end. Transparent bg.

All 6 split from the 1024×1024 black-bg 3×2 sheet via connected-component despeckle (largest sprite blob + near-sprite sparkles retained; disconnected scan-line noise wiped).

### Quest types (3)
- [x] `quests/consistency.png` (512×512) — saved 2026-04-23. Green calendar body with white grid page and a circled "today" cell, 1-px purple `#8A3DC1` sub-outline inside the black outline ("magical quest" rule). Transparent bg.
- [x] `quests/improvement.png` (512×512) — saved 2026-04-23. Gold weight plate (side view, center hole visible) with a gold upward arrow piercing through. Purple sub-outline. Transparent bg.
- [x] `quests/exploration.png` (512×512) — saved 2026-04-23. Purple compass rose with glowing N-needle, 8-point star pattern. Lighter purple highlight on N-needle. Transparent bg.

All 3 share the same 1-px `#8A3DC1` sub-outline convention — reads as a matched family on the quest filter chip grid. Split from a 1536×1024 white-bg 1×3 sheet via gap-based column detection.

### Celebration (4)
- [x] `celebration/level_up.png` (1024×1024) — saved 2026-04-23. Iron-armored knight front-facing, arms raised overhead with glowing gold sword, purple cape flaring behind, 6 purple lightning bolts radiating around (prompt says 8 — minor drift, acceptable at overlay size). Glowing `#B36DFF` visor, gold helmet trim, `#FFF1B8` sword-tip sparkle. Transparent bg. Establishes the celebration family lock documented in §4.8 intro.
- [x] `celebration/pr.png` (1024×1024) — saved 2026-04-23. Open wooden chest with gold interior glow, 6 wheat-stalk gold rays fanning upward + 3 side-rays, 3 coins spilling out front, iron band detail, visible padlock plate. `#FFF1B8` chest-glow-center sparkle. All-gold composition (no purple — acceptable per refined family rule; the overlay scrim supplies purple). Transparent bg.
- [x] `celebration/comeback.png` (1024×1024) — saved 2026-04-23. Gold heater shield with decorative rivets (top + bottom-center), pixel-serif "2×" in cream fill with gold shadow in the shield face, purple dithered mist rising across the bottom ~35% of canvas, ~6–8 small purple sparkle pixels scattered around the shield perimeter, `#FFF1B8` peak sparkle on the "2×". Transparent bg. Best-in-family purple expression so far — mist + all sparkles are purple, gold shield body reads as "reward + protection" for the comeback moment. Family-lock verdict: hero 2/3 vertical ✓, radiating motif ✓ (mist + sparkles), per-moment hero color ✓ (purple-gold duality), peak sparkle ✓, outline + light ✓.
- [x] `celebration/milestone.png` (1024×1024) — saved 2026-04-23. Gold 5-point crown with 3 purple gems on the band, 5 tiny 4-pointed stars on each peak, resting on a purple velvet pillow with gold braid trim and 5 gold tassels (4 corners + front-center). 8-point gold sunburst rays radiating behind the crown. Black 1-px outline. Transparent bg. Family-lock verdict: hero 2/3 vertical ✓ (crown upper, pillow base), radiating motif ✓ (sunburst rays), per-moment hero color ✓ (gold-purple duality — the strongest purple expression in the celebration set via pillow + gems), peak sparkle ✓ (crown-peak stars), outline + light ✓. **Caveat:** crown glyph is reserved for Diamond rank badge (§0 rule 5). Since celebration overlays are full-screen and visually distinct from the rank grid, this is acceptable for 4.8; if it ever plays simultaneously with a Diamond-rank unlock, revisit.

### Micro sprites (8)
- [x] `micro/hp_heart.png` (256×256) — saved 2026-04-23. Red pixel heart with 3 upper-left highlight pixels (bright `#FFFFFF` spot + softer mid-red dithering). Black 1-px outline. Transparent bg. Matches spec exactly.
- [x] `micro/xp_crystal.png` (256×256) — saved 2026-04-23. Violet 4-sided diamond gem (`#8A3DC1` fill + `#6A2FA8` darker facets) with a central 4-point white sparkle and a small trailing white sparkle at upper-right edge. Matches spec.
- [x] `micro/streak_glyph.png` (256×256) — saved 2026-04-23. Gold shield (`#FFB800` rim + `#7A4D00` interior cartouche) with a brown blank number slot (intended to have `7`/streak count overlaid at runtime by Flutter text widget, not baked into the PNG). Matches spec. **Note:** visually echoes `celebration/comeback.png` (also a gold shield) — intentional cross-scale vocabulary (micro HUD chip vs full-screen overlay), not drift.
- [x] `micro/locked.png` (256×256) — saved 2026-04-23. Grey iron padlock with keyhole, mid-grey shackle + shadow, 1-px black outline. Transparent bg.
- [x] `micro/check.png` (256×256) — saved 2026-04-23. Gold checkmark (`#FFB800` fill + `#D9B864` highlights + `#7A4D00` shadow edges). Transparent bg.
- [x] `micro/quest_marker.png` (256×256) — saved 2026-04-23. Cream scroll with a gold wax seal (round gold medallion with dithering, pendant-style ribbon trailing). Echoes `milestones/quest_streak.png` at smaller scale — intentional cross-family vocabulary.
- [x] `micro/coin.png` (256×256) — saved 2026-04-23. Gold coin with embossed bold pixel-serif "R" (RepSaga brand currency). `#FFB800` rim + `#D9B864` face + `#7A4D00` R-stroke. Classic JRPG coin shape. Transparent bg.
- [x] `micro/empty_tavern.png` (256×256) — saved 2026-04-23. Hanging wooden tavern sign — cross-beam with iron chain links suspending a dark-wood plaque emblazoned with a cream pixel-serif "?". Warm brown palette (`#7A4D00`/`#2A1A0F`). Perfect empty-state tone — "no quests here yet, check back later".

### Story / onboarding (3)
- [x] `story/empty_gym.png` (1024×1024) — saved 2026-04-23. Medieval training-hall interior, front-facing 2D side view. Purple stone-brick wall (`#3A1466`/`#2A0E4A` with crack dithering), two flanking pillars with wall-mounted torches (gold `#FFB800` flame + orange `#FF6B6B` ember core) casting warm light pools. 2-tier wooden dumbbell rack with graduated gold weights, small wooden stool to the right, rolled-open purple `#6A2FA8` yoga mat across the cobblestone floor. Dust-mote `#F3E6C6` pixels scattered mid-air (5 visible). Dark-fantasy "cozy empty dungeon" mood — matches spec exactly. Composition reads like a Stardew/Terraria title-card vignette.
- [x] `story/your_saga_begins.png` (1024×1024) — saved 2026-04-23. Hooded adventurer (purple cloak `#3A1466`/`#6A2FA8` rim, deep-shadow hood `#2A0E4A` swallowing the face, two glowing `#B36DFF` eye pixels with `#FFF1B8` hot centers, gold square belt buckle) centered low in the canvas. Behind: simplified training-hall interior from 4.10.1 (purple stone wall, L+R torches, single dumbbell rack, wooden stool). Above: "YOUR SAGA BEGINS" in chunky pixel-serif `#FFB800` letters with `#7A4D00` drop-shadow and full black outline, banner-wide across upper third. Upper-left light throws highlights on left side of cloak hood and buckle. Scene-family lock holds — torches ✓, purple stone wall ✓, gold-on-purple hierarchy ✓, cozy-dungeon mood ✓. **Strength:** glowing eye pixels reinforce the "you are the hero of this story" metaphor without showing a face — reads as self-insert. Title lock-up is the strongest typographic element in the whole asset set.
- [x] `story/first_workout.png` (1024×1024) — saved 2026-04-23. Gold dumbbell resting on a 3-step stone pedestal (`#4A4560` face + `#6A6585` top highlights), descending golden-cream `#FFF1B8` spotlight cone from a hot star-pixel apex widening to the pedestal top, 50%-dither fade. 6 gold sparkle pixels floating around the dumbbell. Purple-radial-feel background (`#0D0319` center → `#2A0E4A` at edges via dithering). Black outlines throughout. Scene-family lock: no torches here (by spec), but purple ambient + gold-on-purple hierarchy + dithered atmosphere all hold. **Strength:** the pedestal + spotlight framing treats the first dumbbell as a *relic* — reinforces the "your first workout is a sacred moment" framing. Best atmospheric composition in the story set.

### Muscle groups (7)
- [x] `muscle/chest.png` (256×256) — saved 2026-04-23. Front-view iron-grey torso silhouette, both upper-pec regions glowing gold with `#FFD54F` hot-core pixels. Purple sub-outline + black outer outline both present. Reads clearly as "chest" at filter-chip scale.
- [x] `muscle/back.png` (256×256) — saved 2026-04-23. Iron-grey torso silhouette with a prominent gold diamond/kite on the upper-chest region, implying "the backside lights up when viewed through the front" (gold V-taper is a traditional lat metaphor). **Drift note:** silhouette is still front-facing; a true rear-view would be unambiguous but this is defensible via the V-taper convention. Low-priority regen if ui-ux-critic flags it.
- [x] `muscle/legs.png` (256×256) — saved 2026-04-23. Lower-body silhouette from waist down, both thighs glowing gold with hot-core pixels, knees visible. Reads clearly.
- [x] `muscle/shoulders.png` (256×256) — saved 2026-04-23. Front-view upper-torso silhouette, both deltoid caps glowing gold symmetrically. Perfect.
- [x] `muscle/arms.png` (256×256) — saved 2026-04-23. Classic flexed bicep pose (one arm bent upward), bicep + tricep entirely gold with `#FFD54F` hot-core. Iron-grey torso + other arm as faint silhouette. Strongest sprite in the muscle sheet.
- [x] `muscle/core.png` (256×256) — saved 2026-04-23. Front-view torso with 2×3 gold abdominal grid glowing gold. Exactly matches spec.
- [x] `muscle/cardio.png` (256×256) — saved 2026-04-23. Full-body side-view running figure mid-stride, entire silhouette glowing gold (not localized — cardio = whole body). Dynamic pose, arms + legs clearly mid-run.

### Equipment types (7)
- [x] `equipment/barbell.png` (256×256) — saved 2026-04-23. Long horizontal iron bar with 2 gold weight plates each side, gold bar sleeves flanking an iron knurled grip. Reads "long bar for compound lifts".
- [x] `equipment/dumbbell.png` (256×256) — saved 2026-04-23. Compact dumbbell — iron handle with 2 stacked gold discs at each end. Shorter, stubbier proportions vs barbell. **Note:** barbell and dumbbell share the "iron-bar + gold-plates" visual language by necessity (they ARE the same archetype at different scales). Differentiation is via bar length only — the same issue Material Icons has. Acceptable.
- [x] `equipment/cable.png` (256×256) — saved 2026-04-23. Iron pulley frame with a single cable descending to a gold D-handle; small iron weight-stack visible at right. Clearly distinguishable from machine by single-cable + exposed frame.
- [x] `equipment/machine.png` (256×256) — saved 2026-04-23. Selectorized weight-stack machine — full iron cage frame + stacked iron weight plates + gold selector pin sticking out mid-stack. Reads as "gym machine" — distinct from cable.
- [x] `equipment/bodyweight.png` (256×256) — saved 2026-04-23. Full gold muscular hero silhouette in a V-pose (arms raised), visible 6-pack abs detail adds "athlete" read. The only all-gold equipment sprite per family-lock rule 4 — perfect.
- [x] `equipment/bands.png` (256×256) — saved 2026-04-23. Arc of iron-grey resistance band with two gold D-handles at each bottom end. Distinct silhouette from cable (two-handled vs single-handled) prevents confusion.
- [x] `equipment/kettlebell.png` (256×256) — saved 2026-04-23. Classic side-view kettlebell — iron round body + gold arched top handle + gold medallion emblem centered on the body face. Instantly readable.

### Panel frame (optional — generate only if CSS frames won't work) (1)
- [ ] `frame/panel_corner.png` (16×16 tileable corner)

**Total: 57 PNG files** across 10 folders.

---

## §8 · Post-generation — what I'll do next

Once you hand me the `assets/pixel/` folder:

1. I'll amend PLAN.md 17.0 so the visual foundation is "pixel-art system" instead
   of "radial gradient + Roboto typography". Anti-Patterns §3 (badge walls) and
   the Milestone Signal section will be rewritten to allow the pixel-art
   achievement grid shown in your reference image 2.
2. I'll dispatch the tech-lead to build:
   - `lib/core/theme/pixel_theme.dart` — palette tokens, Press-Start-2P font
     loader, `PixelImage` widget with `FilterQuality.none` baked in.
   - `lib/core/theme/pixel_panel.dart` — the bordered panel container used
     across screens.
   - Migrate the bottom nav to use the 5 nav PNGs (active/inactive).
   - Replace the current splash-screen logo with the pixel wordmark.
3. Then move into 17b (XP data layer) etc., now visually on top of this
   foundation.

Hand me the folder and I'll take it from there.
