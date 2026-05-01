# `Rotinas` → `Treinos`? — Naming research (pt-BR)

**Question:** Should we rename "Rotinas" to "Treinos" for the saved-template
concept? "Treinos" is the more natural Brazilian gym-slang term, but it
overloads with the logged-session concept. How do we disambiguate?

**Short answer:** Yes, rename. Use **"Treinos"** for templates and
**"Sessão"** as the explicit noun for logged sessions whenever the
object-type distinction matters.

---

## What Brazilian gym culture actually calls these two concepts

In pt-BR gym slang, the dominant vocabulary is:

- **Saved template (plan that repeats)** — "treino A / B / C" or
  "ficha de treino". Nearly universal in written fitness culture (Bluefit,
  Hipertrofia.org, TreinoMestre all use "Treino A/B/C" as the primary label
  for a saved split). The academic/institutional term "rotina" appears in
  Portuguese fitness journalism but not in everyday lifter conversation.
- **Logged session (what you did today)** — "treino de hoje", "sessão", or
  just "treino" with past-tense context.

"Ficha de treino" (literally: workout card/sheet) is the legacy
physical-world term that Brazilian gym apps like Bodytech and Tecnofit have
digitized — their apps surface "treino" or "ficha" as the label, not
"rotina." Selfit and Bodytech both call the template the user accesses at
the gym their "treino," not their "rotina." Hevy's Brazilian Portuguese App
Store listing is titled "Treino de Academia Gym" — internally Hevy uses
"rotinas" for routine objects, but the app is marketed in pt-BR with
"treino" as the top-level concept.

## Domain ambiguity analysis

"Treino" is genuinely overloaded, but Brazilians disambiguate it through
context and suffix without friction:

- **"Meu treino A"** — saved template. Letter suffix is the disambiguation.
- **"Fiz meu treino hoje"** — logged session. Past tense or "fiz/completei"
  is the signal.
- **"Histórico de treinos"** — log of sessions. "Histórico" + plural is
  unambiguous.

The confusion risk is lower than it appears because both meanings already
coexist in the word as used daily. The app needs one additional signal: a
consistent object model in the UI (an icon, a section heading, or a parent
label) to disambiguate at a glance.

## Recommendation table

| Concept | Current label | Recommended label | Rationale | Competitor backing |
|---|---|---|---|---|
| Saved template | Rotinas / Rotina | **Treinos** | Dominant gym slang; how lifters name their A/B/C splits | Smart Fit uses "treinos" for programs; Selfit labels templates "treino"; Tecnofit calls the saved sheet "ficha de treino" — "treino" is the working term |
| Logged session | Treino (implicit) | **Sessão** | Unambiguous; no overloading; standard Portuguese; zero gym-slang baggage | Selfit's schedule feature uses "sessão de treino"; `app_pt.arb` already contains `sessionsCount: "{count} sessões"` (line 389) |
| Session history tab | Histórico | **Histórico** (keep) | Already correct; unambiguous; users understand this immediately | Hevy, Strong, Bodytech all use "Histórico" or "History" — no change needed |
| Nav tab label | Rotinas | **Treinos** | Matches the rename above | Smart Fit's top-level nav calls workout plans "Treinos" |
| Per-object label in editor | Criar Rotina | **Criar Treino** | Follows the rename | — |

## Domain-ambiguity solution

Rename the nav tab and all template-facing strings from "Rotina/Rotinas" to
"Treino/Treinos." The logged-session concept, currently labeled with the
implicit word "treino" in context strings like `finishWorkout` and
`historyLabel`, should adopt **"Sessão"** as the explicit noun wherever the
object-type distinction matters — for example:

- "Sessão concluída" (instead of "Treino concluído")
- "Histórico de sessões" (instead of "Histórico de treinos")
- "Descartar sessão?" (instead of "Descartar treino?")

For casual / "quick" entry points like the home screen hero card, "Treino
rápido" is fine — the context of "iniciar" makes it a session.

## Risk callout — what breaks if we rename

### l10n keys impacted in `lib/l10n/app_pt.arb`

18 keys directly contain "Rotina" or "rotina":

- `navRoutines` (line 6)
- `myRoutines` (line 176)
- `createYourFirstRoutine` (line 177)
- `routines` (line 287)
- `failedToLoadRoutines` (line 288)
- `myRoutinesSection` (line 289)
- `starterRoutinesSection` (line 290)
- `noCustomRoutines` (line 291)
- `createRoutine` (line 293)
- `editRoutine` (line 294)
- `routineName` (line 295)
- `failedToSaveRoutine` (line 296)
- `deleteRoutine` (line 301)
- `deleteRoutineConfirm` (line 302)
- `addRoutine` (line 366)
- `addRoutines` (line 372)
- `routineRemoved` (line 377)
- `unknownRoutine` (line 378)
- `addRoutinesSheet` (line 380)
- `allRoutinesInPlan` (line 381)
- `addCountRoutines` (line 383)
- `noRoutinesPlanned` (line 370)

Plus the **9 starter `routineName*` keys** (lines 493–511). The English
`app_en.arb` must also be updated for parity.

### Route / code impact

The l10n rename is **surface-only** — no Dart code needs changing because all
strings route through the localization layer. The Dart model is `Routine`,
which stays as-is in the domain layer; only display strings change.

### Search / discovery risk

App Store keyword optimization may benefit from "treinos" as a more searched
term for Brazilian users. **Net positive.**

### Support docs risk

Any help article, onboarding text, or in-app tooltip that says "rotina" will
read as stale post-rename. Worth an audit pass when the rename ships.

## Recommendation

Land the rename in a dedicated PR alongside the active-workout redesign (or
just before — the redesign mockups can use the new vocabulary from the
start). Single squash commit, l10n-only diff. Keep `Routine` as the Dart
model name to avoid touching the domain layer.
