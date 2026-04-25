-- Phase 15f Stage 1 — backfill EN translations for every exercise.
--
-- Copies the current `exercises.name/description/form_tips` columns into
-- `exercise_translations` as `locale = 'en'`. Runs for BOTH defaults and
-- user-created rows because every exercise must have at least one
-- translation once Stage 4 (00034) drops the monolingual columns from
-- `exercises`.
--
-- Defaults and user rows are inserted in separate statements purely for
-- post-mortem clarity in logs if something fails — behavior is identical to a
-- single INSERT. The final count-parity assertion covers both.
--
-- This migration runs as `postgres` so RLS is bypassed.

BEGIN;

-- 1. Default exercises first (they're the content Stage 3 will also seed
--    pt-BR for).
INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT id, 'en', name, description, form_tips
FROM exercises
WHERE is_default = true;

-- 2. User-created exercises — preserve the creator's English content so the
--    column drop in Stage 4 is lossless.
INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT id, 'en', name, description, form_tips
FROM exercises
WHERE is_default = false;

-- 3. Hard assert: every exercise row has exactly one EN translation. If the
--    counts diverge something went wrong (e.g. a row added between the two
--    inserts, or a FK failure swallowed silently — shouldn't happen inside a
--    transaction, but the guard costs nothing).
DO $$
DECLARE
  ex_count INTEGER;
  tr_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO ex_count FROM exercises;
  SELECT COUNT(*) INTO tr_count FROM exercise_translations WHERE locale = 'en';
  IF ex_count <> tr_count THEN
    RAISE EXCEPTION
      'EN backfill count mismatch: % exercises vs % translations',
      ex_count, tr_count;
  END IF;
END
$$;

COMMIT;
