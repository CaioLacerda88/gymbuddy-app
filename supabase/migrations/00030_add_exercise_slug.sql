-- Phase 15f Stage 1 — add locale-independent semantic slug to `exercises`.
--
-- The slug is the stable identifier used to JOIN exercises ↔ locale-specific
-- translations (see 00031) without coupling either side to display text.
-- Defaults share a slug namespace (globally unique); user-created exercises
-- may collide slugs with each other or with defaults — hence the partial
-- unique index.
--
-- For DEFAULT rows we backfill from a hardcoded literal map (Block A below)
-- rather than computing slugs via regex. Per the design spec
-- (docs/superpowers/specs/2026-04-24-exercise-content-localization-design.md
-- §9), the Stage 3 pt seed (00033) JOINs `exercise_translations.slug` against
-- `exercises.slug` using literal slug strings. If the SQL regex ever diverged
-- from Dart `exerciseSlug()` in any edge case (unicode, separator handling,
-- whitespace edges) the JOIN would silently drop rows. A literal map
-- (matching `_exerciseNames` keys in `lib/core/l10n/exercise_l10n.dart`) is
-- the structural guarantee — byte-exact parity by construction.
--
-- For USER-CREATED rows (Block B) we use `regexp_replace` because there is
-- no fixed list to enumerate. These rows are not part of the i18n JOIN, so
-- exact-byte parity with Dart is best-effort, not a correctness invariant.
--
-- Slug derivation rule (mirrors `exerciseSlug()` in
-- `lib/core/l10n/exercise_l10n.dart:9-14`):
--
--   englishName.toLowerCase()
--     .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
--     .replaceAll(RegExp(r'^_+|_+$'), '')
--
-- Postgres equivalent (used in Block B and the BEFORE INSERT trigger):
--
--   trim(both '_' from regexp_replace(lower(name), '[^a-z0-9]+', '_', 'g'))
--
-- Test anchors:
--   'Barbell Bench Press'   → 'barbell_bench_press'
--   "Farmer's Walk"         → 'farmer_s_walk'
--   'Push-Up'               → 'push_up'
--   'T-Bar Row'             → 't_bar_row'

BEGIN;

-- 1. Add column nullable so the backfill can run.
ALTER TABLE exercises
  ADD COLUMN slug TEXT;

-- 2A. BLOCK A — backfill the 150 default exercises with hardcoded literal
--     slugs. Names below are verbatim copies of the `name` column values
--     inserted by 00007/00014/00019 (61 + 31 + 58 = 150). Slug literals must
--     match the keys in `_exerciseNames` (lib/core/l10n/exercise_l10n.dart).
--
--     If you ever add or rename a default exercise, you MUST update both:
--       - the seed migration that inserts the row, AND
--       - the slug map in `_exerciseNames`, AND
--       - this block (or a follow-up migration that backfills new rows).
--     The post-block assert (step 2C) catches missed names immediately.

-- ---- 00007: CHEST (9) ----
UPDATE exercises SET slug = 'barbell_bench_press'         WHERE is_default = true AND name = 'Barbell Bench Press';
UPDATE exercises SET slug = 'incline_barbell_bench_press' WHERE is_default = true AND name = 'Incline Barbell Bench Press';
UPDATE exercises SET slug = 'decline_barbell_bench_press' WHERE is_default = true AND name = 'Decline Barbell Bench Press';
UPDATE exercises SET slug = 'dumbbell_bench_press'        WHERE is_default = true AND name = 'Dumbbell Bench Press';
UPDATE exercises SET slug = 'incline_dumbbell_press'      WHERE is_default = true AND name = 'Incline Dumbbell Press';
UPDATE exercises SET slug = 'dumbbell_fly'                WHERE is_default = true AND name = 'Dumbbell Fly';
UPDATE exercises SET slug = 'cable_crossover'             WHERE is_default = true AND name = 'Cable Crossover';
UPDATE exercises SET slug = 'machine_chest_press'         WHERE is_default = true AND name = 'Machine Chest Press';
UPDATE exercises SET slug = 'push_up'                     WHERE is_default = true AND name = 'Push-Up';

-- ---- 00007: BACK (10) ----
UPDATE exercises SET slug = 'barbell_bent_over_row'       WHERE is_default = true AND name = 'Barbell Bent-Over Row';
UPDATE exercises SET slug = 'deadlift'                    WHERE is_default = true AND name = 'Deadlift';
UPDATE exercises SET slug = 't_bar_row'                   WHERE is_default = true AND name = 'T-Bar Row';
UPDATE exercises SET slug = 'dumbbell_row'                WHERE is_default = true AND name = 'Dumbbell Row';
UPDATE exercises SET slug = 'dumbbell_pullover'           WHERE is_default = true AND name = 'Dumbbell Pullover';
UPDATE exercises SET slug = 'cable_row'                   WHERE is_default = true AND name = 'Cable Row';
UPDATE exercises SET slug = 'lat_pulldown'                WHERE is_default = true AND name = 'Lat Pulldown';
UPDATE exercises SET slug = 'pull_up'                     WHERE is_default = true AND name = 'Pull-Up';
UPDATE exercises SET slug = 'chin_up'                     WHERE is_default = true AND name = 'Chin-Up';
UPDATE exercises SET slug = 'machine_row'                 WHERE is_default = true AND name = 'Machine Row';

-- ---- 00007: LEGS (11) ----
UPDATE exercises SET slug = 'barbell_squat'               WHERE is_default = true AND name = 'Barbell Squat';
UPDATE exercises SET slug = 'front_squat'                 WHERE is_default = true AND name = 'Front Squat';
UPDATE exercises SET slug = 'romanian_deadlift'           WHERE is_default = true AND name = 'Romanian Deadlift';
UPDATE exercises SET slug = 'hip_thrust'                  WHERE is_default = true AND name = 'Hip Thrust';
UPDATE exercises SET slug = 'dumbbell_lunges'             WHERE is_default = true AND name = 'Dumbbell Lunges';
UPDATE exercises SET slug = 'bulgarian_split_squat'       WHERE is_default = true AND name = 'Bulgarian Split Squat';
UPDATE exercises SET slug = 'goblet_squat'                WHERE is_default = true AND name = 'Goblet Squat';
UPDATE exercises SET slug = 'leg_press'                   WHERE is_default = true AND name = 'Leg Press';
UPDATE exercises SET slug = 'leg_extension'               WHERE is_default = true AND name = 'Leg Extension';
UPDATE exercises SET slug = 'leg_curl'                    WHERE is_default = true AND name = 'Leg Curl';
UPDATE exercises SET slug = 'calf_raise'                  WHERE is_default = true AND name = 'Calf Raise';

-- ---- 00007: SHOULDERS (8) ----
UPDATE exercises SET slug = 'overhead_press'              WHERE is_default = true AND name = 'Overhead Press';
UPDATE exercises SET slug = 'push_press'                  WHERE is_default = true AND name = 'Push Press';
UPDATE exercises SET slug = 'dumbbell_shoulder_press'     WHERE is_default = true AND name = 'Dumbbell Shoulder Press';
UPDATE exercises SET slug = 'arnold_press'                WHERE is_default = true AND name = 'Arnold Press';
UPDATE exercises SET slug = 'lateral_raise'               WHERE is_default = true AND name = 'Lateral Raise';
UPDATE exercises SET slug = 'front_raise'                 WHERE is_default = true AND name = 'Front Raise';
UPDATE exercises SET slug = 'rear_delt_fly'               WHERE is_default = true AND name = 'Rear Delt Fly';
UPDATE exercises SET slug = 'cable_face_pull'             WHERE is_default = true AND name = 'Cable Face Pull';

-- ---- 00007: ARMS (10) ----
UPDATE exercises SET slug = 'barbell_curl'                WHERE is_default = true AND name = 'Barbell Curl';
UPDATE exercises SET slug = 'ez_bar_curl'                 WHERE is_default = true AND name = 'EZ Bar Curl';
UPDATE exercises SET slug = 'skull_crusher'               WHERE is_default = true AND name = 'Skull Crusher';
UPDATE exercises SET slug = 'dumbbell_curl'               WHERE is_default = true AND name = 'Dumbbell Curl';
UPDATE exercises SET slug = 'hammer_curl'                 WHERE is_default = true AND name = 'Hammer Curl';
UPDATE exercises SET slug = 'concentration_curl'          WHERE is_default = true AND name = 'Concentration Curl';
UPDATE exercises SET slug = 'dumbbell_tricep_extension'   WHERE is_default = true AND name = 'Dumbbell Tricep Extension';
UPDATE exercises SET slug = 'tricep_pushdown'             WHERE is_default = true AND name = 'Tricep Pushdown';
UPDATE exercises SET slug = 'cable_curl'                  WHERE is_default = true AND name = 'Cable Curl';
UPDATE exercises SET slug = 'dips'                        WHERE is_default = true AND name = 'Dips';

-- ---- 00007: CORE (7) ----
UPDATE exercises SET slug = 'plank'                       WHERE is_default = true AND name = 'Plank';
UPDATE exercises SET slug = 'hanging_leg_raise'           WHERE is_default = true AND name = 'Hanging Leg Raise';
UPDATE exercises SET slug = 'crunches'                    WHERE is_default = true AND name = 'Crunches';
UPDATE exercises SET slug = 'ab_rollout'                  WHERE is_default = true AND name = 'Ab Rollout';
UPDATE exercises SET slug = 'russian_twist'               WHERE is_default = true AND name = 'Russian Twist';
UPDATE exercises SET slug = 'dead_bug'                    WHERE is_default = true AND name = 'Dead Bug';
UPDATE exercises SET slug = 'cable_woodchop'              WHERE is_default = true AND name = 'Cable Woodchop';

-- ---- 00007: BANDS (3) ----
UPDATE exercises SET slug = 'band_pull_apart'             WHERE is_default = true AND name = 'Band Pull-Apart';
UPDATE exercises SET slug = 'band_face_pull'              WHERE is_default = true AND name = 'Band Face Pull';
UPDATE exercises SET slug = 'band_squat'                  WHERE is_default = true AND name = 'Band Squat';

-- ---- 00007: KETTLEBELL (3) ----
UPDATE exercises SET slug = 'kettlebell_swing'            WHERE is_default = true AND name = 'Kettlebell Swing';
UPDATE exercises SET slug = 'kettlebell_goblet_squat'     WHERE is_default = true AND name = 'Kettlebell Goblet Squat';
UPDATE exercises SET slug = 'kettlebell_turkish_get_up'   WHERE is_default = true AND name = 'Kettlebell Turkish Get-Up';

-- ---- 00014: CHEST (3) ----
UPDATE exercises SET slug = 'pec_deck'                    WHERE is_default = true AND name = 'Pec Deck';
UPDATE exercises SET slug = 'cable_chest_press'           WHERE is_default = true AND name = 'Cable Chest Press';
UPDATE exercises SET slug = 'wide_push_up'                WHERE is_default = true AND name = 'Wide Push-Up';

-- ---- 00014: BACK (4) ----
UPDATE exercises SET slug = 'face_pull'                   WHERE is_default = true AND name = 'Face Pull';
UPDATE exercises SET slug = 'rack_pull'                   WHERE is_default = true AND name = 'Rack Pull';
UPDATE exercises SET slug = 'good_morning'                WHERE is_default = true AND name = 'Good Morning';
UPDATE exercises SET slug = 'pendlay_row'                 WHERE is_default = true AND name = 'Pendlay Row';

-- ---- 00014: LEGS (7) ----
UPDATE exercises SET slug = 'hack_squat'                  WHERE is_default = true AND name = 'Hack Squat';
UPDATE exercises SET slug = 'sumo_deadlift'               WHERE is_default = true AND name = 'Sumo Deadlift';
UPDATE exercises SET slug = 'walking_lunges'              WHERE is_default = true AND name = 'Walking Lunges';
UPDATE exercises SET slug = 'step_up'                     WHERE is_default = true AND name = 'Step-Up';
UPDATE exercises SET slug = 'seated_calf_raise'           WHERE is_default = true AND name = 'Seated Calf Raise';
UPDATE exercises SET slug = 'leg_abductor'                WHERE is_default = true AND name = 'Leg Abductor';
UPDATE exercises SET slug = 'leg_adductor'                WHERE is_default = true AND name = 'Leg Adductor';

-- ---- 00014: SHOULDERS (3) ----
UPDATE exercises SET slug = 'upright_row'                 WHERE is_default = true AND name = 'Upright Row';
UPDATE exercises SET slug = 'machine_shoulder_press'      WHERE is_default = true AND name = 'Machine Shoulder Press';
UPDATE exercises SET slug = 'cable_lateral_raise'         WHERE is_default = true AND name = 'Cable Lateral Raise';

-- ---- 00014: ARMS (5) ----
UPDATE exercises SET slug = 'preacher_curl'               WHERE is_default = true AND name = 'Preacher Curl';
UPDATE exercises SET slug = 'incline_dumbbell_curl'       WHERE is_default = true AND name = 'Incline Dumbbell Curl';
UPDATE exercises SET slug = 'close_grip_bench_press'      WHERE is_default = true AND name = 'Close-Grip Bench Press';
UPDATE exercises SET slug = 'overhead_tricep_extension'   WHERE is_default = true AND name = 'Overhead Tricep Extension';
UPDATE exercises SET slug = 'rope_pushdown'               WHERE is_default = true AND name = 'Rope Pushdown';

-- ---- 00014: CORE (4) ----
UPDATE exercises SET slug = 'bicycle_crunch'              WHERE is_default = true AND name = 'Bicycle Crunch';
UPDATE exercises SET slug = 'cable_crunch'                WHERE is_default = true AND name = 'Cable Crunch';
UPDATE exercises SET slug = 'pallof_press'                WHERE is_default = true AND name = 'Pallof Press';
UPDATE exercises SET slug = 'side_plank'                  WHERE is_default = true AND name = 'Side Plank';

-- ---- 00014: CARDIO (5) ----
UPDATE exercises SET slug = 'treadmill'                   WHERE is_default = true AND name = 'Treadmill';
UPDATE exercises SET slug = 'rowing_machine'              WHERE is_default = true AND name = 'Rowing Machine';
UPDATE exercises SET slug = 'stationary_bike'             WHERE is_default = true AND name = 'Stationary Bike';
UPDATE exercises SET slug = 'jump_rope'                   WHERE is_default = true AND name = 'Jump Rope';
UPDATE exercises SET slug = 'elliptical'                  WHERE is_default = true AND name = 'Elliptical';

-- ---- 00019: CHEST (6) ----
UPDATE exercises SET slug = 'incline_dumbbell_fly'        WHERE is_default = true AND name = 'Incline Dumbbell Fly';
UPDATE exercises SET slug = 'decline_dumbbell_press'      WHERE is_default = true AND name = 'Decline Dumbbell Press';
UPDATE exercises SET slug = 'landmine_press'              WHERE is_default = true AND name = 'Landmine Press';
UPDATE exercises SET slug = 'diamond_push_up'             WHERE is_default = true AND name = 'Diamond Push-Up';
UPDATE exercises SET slug = 'incline_push_up'             WHERE is_default = true AND name = 'Incline Push-Up';
UPDATE exercises SET slug = 'decline_push_up'             WHERE is_default = true AND name = 'Decline Push-Up';

-- ---- 00019: BACK (9) ----
UPDATE exercises SET slug = 'hyperextension'              WHERE is_default = true AND name = 'Hyperextension';
UPDATE exercises SET slug = 'back_extension'              WHERE is_default = true AND name = 'Back Extension';
UPDATE exercises SET slug = 'inverted_row'                WHERE is_default = true AND name = 'Inverted Row';
UPDATE exercises SET slug = 'chest_supported_row'         WHERE is_default = true AND name = 'Chest-Supported Row';
UPDATE exercises SET slug = 'seal_row'                    WHERE is_default = true AND name = 'Seal Row';
UPDATE exercises SET slug = 'straight_arm_pulldown'       WHERE is_default = true AND name = 'Straight-Arm Pulldown';
UPDATE exercises SET slug = 'close_grip_lat_pulldown'     WHERE is_default = true AND name = 'Close-Grip Lat Pulldown';
UPDATE exercises SET slug = 'wide_grip_pull_up'           WHERE is_default = true AND name = 'Wide-Grip Pull-Up';
UPDATE exercises SET slug = 'kettlebell_row'              WHERE is_default = true AND name = 'Kettlebell Row';

-- ---- 00019: LEGS (14) ----
UPDATE exercises SET slug = 'glute_bridge'                WHERE is_default = true AND name = 'Glute Bridge';
UPDATE exercises SET slug = 'single_leg_glute_bridge'     WHERE is_default = true AND name = 'Single-Leg Glute Bridge';
UPDATE exercises SET slug = 'box_jump'                    WHERE is_default = true AND name = 'Box Jump';
UPDATE exercises SET slug = 'nordic_curl'                 WHERE is_default = true AND name = 'Nordic Curl';
UPDATE exercises SET slug = 'wall_sit'                    WHERE is_default = true AND name = 'Wall Sit';
UPDATE exercises SET slug = 'donkey_kick'                 WHERE is_default = true AND name = 'Donkey Kick';
UPDATE exercises SET slug = 'bodyweight_squat'            WHERE is_default = true AND name = 'Bodyweight Squat';
UPDATE exercises SET slug = 'reverse_lunges'              WHERE is_default = true AND name = 'Reverse Lunges';
UPDATE exercises SET slug = 'dumbbell_calf_raise'         WHERE is_default = true AND name = 'Dumbbell Calf Raise';
UPDATE exercises SET slug = 'single_leg_leg_press'        WHERE is_default = true AND name = 'Single-Leg Leg Press';
UPDATE exercises SET slug = 'reverse_hyperextension'      WHERE is_default = true AND name = 'Reverse Hyperextension';
UPDATE exercises SET slug = 'cable_glute_kickback'        WHERE is_default = true AND name = 'Cable Glute Kickback';
UPDATE exercises SET slug = 'cable_pull_through'          WHERE is_default = true AND name = 'Cable Pull-Through';
UPDATE exercises SET slug = 'kettlebell_deadlift'         WHERE is_default = true AND name = 'Kettlebell Deadlift';

-- ---- 00019: SHOULDERS (7) ----
UPDATE exercises SET slug = 'barbell_shrug'               WHERE is_default = true AND name = 'Barbell Shrug';
UPDATE exercises SET slug = 'dumbbell_shrug'              WHERE is_default = true AND name = 'Dumbbell Shrug';
UPDATE exercises SET slug = 'cable_rear_delt_fly'         WHERE is_default = true AND name = 'Cable Rear Delt Fly';
UPDATE exercises SET slug = 'cable_front_raise'           WHERE is_default = true AND name = 'Cable Front Raise';
UPDATE exercises SET slug = 'reverse_pec_deck'            WHERE is_default = true AND name = 'Reverse Pec Deck';
UPDATE exercises SET slug = 'landmine_shoulder_press'     WHERE is_default = true AND name = 'Landmine Shoulder Press';
UPDATE exercises SET slug = 'kettlebell_press'            WHERE is_default = true AND name = 'Kettlebell Press';

-- ---- 00019: ARMS (10) ----
UPDATE exercises SET slug = 'spider_curl'                 WHERE is_default = true AND name = 'Spider Curl';
UPDATE exercises SET slug = 'zottman_curl'                WHERE is_default = true AND name = 'Zottman Curl';
UPDATE exercises SET slug = 'reverse_curl'                WHERE is_default = true AND name = 'Reverse Curl';
UPDATE exercises SET slug = 'wrist_curl'                  WHERE is_default = true AND name = 'Wrist Curl';
UPDATE exercises SET slug = 'reverse_wrist_curl'          WHERE is_default = true AND name = 'Reverse Wrist Curl';
UPDATE exercises SET slug = 'farmer_s_walk'               WHERE is_default = true AND name = 'Farmer''s Walk';
UPDATE exercises SET slug = 'cable_hammer_curl'           WHERE is_default = true AND name = 'Cable Hammer Curl';
UPDATE exercises SET slug = 'bench_dip'                   WHERE is_default = true AND name = 'Bench Dip';
UPDATE exercises SET slug = 'close_grip_push_up'          WHERE is_default = true AND name = 'Close-Grip Push-Up';
UPDATE exercises SET slug = 'jm_press'                    WHERE is_default = true AND name = 'JM Press';

-- ---- 00019: CORE (12) ----
UPDATE exercises SET slug = 'sit_up'                      WHERE is_default = true AND name = 'Sit-Up';
UPDATE exercises SET slug = 'mountain_climber'            WHERE is_default = true AND name = 'Mountain Climber';
UPDATE exercises SET slug = 'toe_touch'                   WHERE is_default = true AND name = 'Toe Touch';
UPDATE exercises SET slug = 'hollow_body_hold'            WHERE is_default = true AND name = 'Hollow Body Hold';
UPDATE exercises SET slug = 'v_up'                        WHERE is_default = true AND name = 'V-Up';
UPDATE exercises SET slug = 'flutter_kick'                WHERE is_default = true AND name = 'Flutter Kick';
UPDATE exercises SET slug = 'reverse_crunch'              WHERE is_default = true AND name = 'Reverse Crunch';
UPDATE exercises SET slug = 'leg_raise'                   WHERE is_default = true AND name = 'Leg Raise';
UPDATE exercises SET slug = 'windshield_wiper'            WHERE is_default = true AND name = 'Windshield Wiper';
UPDATE exercises SET slug = 'plank_up_down'               WHERE is_default = true AND name = 'Plank Up-Down';
UPDATE exercises SET slug = 'heel_touch'                  WHERE is_default = true AND name = 'Heel Touch';
UPDATE exercises SET slug = 'kettlebell_windmill'         WHERE is_default = true AND name = 'Kettlebell Windmill';

-- 2B. Defensive assert: every default row must now have a slug. If any
--     default still has NULL slug, a name in the seed migrations diverged
--     from the literal map above (e.g. typo, renamed without map update).
--     Fail loudly so the gap is fixed at migration time, not at translation
--     JOIN time.
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM exercises WHERE is_default = true AND slug IS NULL) > 0 THEN
    RAISE EXCEPTION 'default rows missing slug after hardcoded backfill — name in seed migrations does not match map';
  END IF;
END
$$;

-- 2C. BLOCK B — backfill user-created rows with the regex form. These rows
--     are not part of the i18n JOIN, so byte-exact parity with Dart is
--     best-effort. In practice user-created rows only exist in dev/test
--     databases at this stage; production has none yet. Once Stage 6's
--     `create_exercise` RPC is the only insert path, callers will supply
--     the slug explicitly and this branch becomes dead code.
UPDATE exercises
SET slug = trim(both '_' from regexp_replace(lower(name), '[^a-z0-9]+', '_', 'g'))
WHERE is_default = false;

-- 3. Hard assert no NULL/empty slugs survived — fail loudly if anything
--    slipped through (e.g. user row with all-punctuation name).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM exercises WHERE slug IS NULL OR slug = '') THEN
    RAISE EXCEPTION 'slug backfill incomplete: found NULL or empty slug';
  END IF;
END
$$;

-- 4. Lock the invariant at the schema level.
ALTER TABLE exercises
  ALTER COLUMN slug SET NOT NULL;

-- 5. Default slugs must be globally unique — they're the join key for
--    translation seeds (00032/00033) and future locale additions.
--    User-created rows are intentionally excluded: two users may each create
--    "My Pushup" and both get slug `my_pushup` without colliding.
CREATE UNIQUE INDEX exercises_slug_unique_default
  ON exercises (slug)
  WHERE is_default = true;

-- 6. General lookup index for the hot path: RPCs resolving an exercise by
--    slug across defaults + user rows.
CREATE INDEX exercises_slug_idx
  ON exercises (slug);

-- 7. Structural guarantee: derive slug from name on INSERT when the caller
--    doesn't supply one. Mirrors Dart `exerciseSlug()` byte-for-byte, so a
--    Dart insert that only sets `name` still produces the identical slug the
--    application would compute client-side.
--
--    Why a trigger: Stage 1 introduces the `slug NOT NULL` invariant while
--    the rest of the system (Dart `ExerciseRepository.create`, `seed.sql`,
--    E2E fixtures) still inserts rows without a slug. Until Stage 4's RPCs
--    become the only insert path (Stage 6 client refactor), this trigger
--    bridges the gap without forcing every caller to know about slugs.
--    The NOT NULL check still fires if `name` is NULL or slug-derivable-to-
--    empty (all-punctuation), preserving the invariant.
--
--    INSERT-only: rename handling on UPDATE is deferred to the Stage 4
--    RPC contract, which will set slug explicitly. Auto-recomputing on
--    UPDATE is error-prone because `NEW.slug` inherits the old value when
--    not in the SET list, so a simple "NULL/empty" guard wouldn't catch a
--    stale-slug scenario after a rename. Explicit is safer.
--
--    Idempotent: explicit slugs are respected (e.g. tests, Stage 4 RPCs).
--    NULL or empty slug → derived.
CREATE OR REPLACE FUNCTION public.exercises_derive_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.slug IS NULL OR NEW.slug = '' THEN
    NEW.slug := trim(both '_' from regexp_replace(lower(NEW.name), '[^a-z0-9]+', '_', 'g'));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER exercises_derive_slug_trigger
  BEFORE INSERT ON exercises
  FOR EACH ROW
  EXECUTE FUNCTION public.exercises_derive_slug();

COMMIT;
