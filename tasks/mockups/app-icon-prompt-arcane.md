# RepSaga App Icon — Arcane Ascent

One prompt. Generate 3 variants. User picks winner. Drops PNG to `assets/app_icon/`.

---

## What we need

1. `assets/app_icon/arcane_sigil_1024.png` — 1024×1024 PNG, opaque background (the full icon plate, for iOS/web/Play Store listing)
2. `assets/app_icon/arcane_sigil_foreground.png` — 1024×1024 PNG, **transparent** background, sigil only, with 17% safe padding (for Android adaptive icon foreground layer)
3. Android adaptive background is a flat color — no AI generation needed (`#0D0319`)

If you can only generate one image, make it the **#1 full plate** — we can mask the sigil out manually later.

---

## The prompt (copy-paste into ChatGPT, DALL-E, or Midjourney)

> A flat-designed mobile app icon for a strength-training RPG app called **RepSaga**. Square 1024×1024 canvas. Solid deep-purple background color `#0D0319` (abyss purple, no gradient variation on the background — keep it one flat color plate). Centered motif: an **arcane sigil** rendered as a single clean illustrative shape — think "mystical crest" not "busy wizard painting." The sigil is rendered in **arcane violet `#8A3DC1`** as the primary color with a **hot violet `#B36DFF`** highlight along one edge, and a bright **hero gold `#FFB800`** core glow at the very center of the composition (the "reward light" — the one and only bright warm accent).
>
> **Motif options — generate 3 variants, one of each:**
>
> 1. **Hooded figure sigil** — a minimalist, stylized hooded silhouette seen head-on, shoulders back, posture of a lifter about to engage. Face is in shadow but a small hero-gold glow sits where the eyes/heart would be. Cape edges suggest movement. Reads as "hero" and "mystery" together.
> 2. **Ascending chevron sigil** — two or three upward-pointing violet chevrons stacked, with a hero-gold circle or star at the apex. The shape should feel like "progression" and "ascending level." Reads as pure symbol, no figurative content.
> 3. **Rune + barbell composite** — an abstract rune carved from a side-view barbell silhouette (horizontal bar + asymmetric plates), with hero-gold energy emerging from the center of the bar. Reads as "strength + magic" unified into one mark.
>
> **Style rules (apply to all three):**
>
> - **Flat design, painterly illustration.** Not pixel art. Not 3D render. Not photorealistic. Not cartoon. Think: modern mobile game icon from a AAA studio — clean vector-style shapes with subtle painterly shading, bold silhouette readable at 48×48 px.
> - **Composition fits inside a 68% safe-zone circle.** Nothing important near the corners — modern OS adaptive icons will mask to a circle or squircle. The sigil occupies roughly the central 68% of the canvas.
> - **Color discipline:** exactly these four colors and nothing else — `#0D0319` (background), `#8A3DC1` (primary violet), `#B36DFF` (hot violet highlight), `#FFB800` (hero gold core glow). No teal. No white. No other purples. No gradients except a subtle radial glow emerging from the hero-gold center.
> - **Symmetric or near-symmetric** about the vertical axis. No off-center weight.
> - **No text, no letters, no numbers, no "R" logo.** Pure symbol.
> - **No drop shadow outside the canvas.** All lighting is self-contained to the sigil.
> - **No border, no frame, no inner bezel.** The abyss-purple plate is the entire background.
>
> **Explicit rejections — do NOT include:**
>
> - Pixel-art, 8-bit, or retro-game aesthetic
> - Photorealistic barbells, dumbbells, or weight plates
> - Generic fitness emoji (🏋️, 💪)
> - Flames, fire, or red/orange warm tones (hero-gold is the only warm accent)
> - Lightning bolts (clichéd)
> - Gradient-heavy Instagram-style
> - Teal, cyan, navy, or any blue-green
> - Hands holding things
> - Chains, shackles, or restraint imagery
> - Script fonts, any kind of text, or any letter shapes
> - Multiple small elements — the sigil is ONE clean shape, not a collage
>
> **Output:** 3 separate 1024×1024 PNG images, one per motif variant. Solid `#0D0319` background on each.

---

## After generating

1. Pick the variant that reads strongest at 48×48 (zoom out — does it still look like a confident, centered mark?)
2. Save winner as:
   - `assets/app_icon/arcane_sigil_1024.png` — the full plate with background
   - `assets/app_icon/arcane_sigil_foreground.png` — same sigil, transparent background, for Android adaptive (can be extracted in any image editor: lasso-select background, delete to alpha)
3. If the user running this picks variant 1 (Hooded figure), verify the central gold glow actually exists — some gens drop it. If missing, regen with the phrase `"emphasizing a small bright hero-gold #FFB800 circular glow at the very center of the figure's chest"`.
4. Commit both files. Then update `pubspec.yaml` `flutter_launcher_icons` to point at `assets/app_icon/arcane_sigil_1024.png` (full plate) and set `adaptive_icon_foreground: "assets/app_icon/arcane_sigil_foreground.png"` + `adaptive_icon_background: "#0D0319"`.
5. Run `dart run flutter_launcher_icons` to regenerate launcher icons.

## Sanity check before committing

- Does the icon read confidently at 48×48? (scale down in your editor and check)
- Is the hero-gold center actually the brightest point? (if not, regen)
- Zero text, zero fitness emoji, zero gradients except the center glow? (if any, regen)
- Background is truly flat `#0D0319`, no subtle variation? (if not, flatten in editor or regen)
