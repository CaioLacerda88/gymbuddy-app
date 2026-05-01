-- BUG-003 follow-up: allow callers to supply an explicit `id` to
-- `fn_insert_user_exercise` so offline-created exercises keep the same UUID
-- after replay.
--
-- Why this matters:
--   When the user creates an exercise offline, the client generates a local
--   stub UUID and stamps it onto the local Hive cache, AND any
--   `workout_exercises` rows logged in the same session reference that local
--   UUID through the queued `PendingSaveWorkout.exercisesJson`.
--   On reconnect the offline-sync drain replays the create FIRST
--   (PendingCreateExercise), then the workout (PendingSaveWorkout).
--   Pre-fix the RPC always allocated a fresh UUID server-side, so the
--   committed `workout_exercises.exercise_id` referenced an exercise row that
--   never existed server-side — the FK was satisfied at the moment of
--   `INSERT` only because the parent workout's INSERT happened to come AFTER
--   our reconciliation cleared the queue, but the row stored a dangling
--   pointer. With this fix the offline drain passes `p_id := action.exerciseId`
--   so the server row's PK matches the local stub byte-for-byte.
--
-- Forward-compatibility:
--   * `p_id` is the **last** parameter and defaults to NULL — any existing
--     caller that does not supply it continues to work unchanged (the
--     online create_exercise_screen path).
--   * The Dart repository's call site uses named params, so adding a trailing
--     positional default does not silently shift any other argument.
--   * COALESCE(p_id, gen_random_uuid()) means both online and replay paths
--     produce the same observable outcome: a row exists with a stable UUID,
--     either client-supplied or server-allocated.
--
-- Authorization is unchanged — caller must be authenticated AND
-- `auth.uid() = p_user_id`. We do NOT validate the shape of `p_id` beyond
-- "must be a valid UUID" (Postgres enforces that at parameter parse time);
-- the worst a malicious caller can do by supplying a custom UUID is collide
-- with their own existing row, which the duplicate-name check already
-- rejects in practice (you cannot have two rows with the same name regardless
-- of UUID, and the PK INSERT will raise 23505 anyway if two rows literally
-- share the same UUID).

BEGIN;

-- Drop the prior 7-arg overload before installing the 8-arg variant. Without
-- this, PostgreSQL leaves both overloads in place and the online call site
-- (which omits p_id) becomes ambiguous: the 7-arg exact match AND the 8-arg
-- with default p_id both qualify, and PG raises 42725 "function ... is not
-- unique" on dispatch. Killing the old overload first makes the 8-arg the
-- single authoritative function.
DROP FUNCTION IF EXISTS public.fn_insert_user_exercise(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
);

CREATE OR REPLACE FUNCTION public.fn_insert_user_exercise(
  p_user_id        UUID,
  p_locale         TEXT,
  p_name           TEXT,
  p_muscle_group   TEXT,
  p_equipment_type TEXT,
  p_description    TEXT DEFAULT NULL,
  p_form_tips      TEXT DEFAULT NULL,
  p_id             UUID DEFAULT NULL
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  muscle_group    muscle_group,
  equipment_type  equipment_type,
  is_default      BOOLEAN,
  description     TEXT,
  form_tips       TEXT,
  image_start_url TEXT,
  image_end_url   TEXT,
  user_id         UUID,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  slug            TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id    UUID;
  v_new_slug  TEXT;
BEGIN
  -- Authorization. NULL auth.uid() means anonymous caller.
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'unauthorized: caller does not own p_user_id'
      USING ERRCODE = '42501';
  END IF;

  -- Duplicate-name check across the user's owned, non-deleted exercises in
  -- any locale. Replaces the dropped `idx_exercises_unique_name` functional
  -- index (which keyed on lower(name) for `exercises.name`).
  IF EXISTS (
    SELECT 1
    FROM exercise_translations t
    JOIN exercises e ON e.id = t.exercise_id
    WHERE e.user_id = p_user_id
      AND e.deleted_at IS NULL
      AND lower(t.name) = lower(p_name)
  ) THEN
    RAISE EXCEPTION 'duplicate exercise name for user: %', p_name
      USING ERRCODE = '23505';
  END IF;

  -- Compute slug inline (byte-for-byte parity with Dart `exerciseSlug()`):
  --   lower → replace non-alphanum with `_` → trim leading/trailing `_`.
  v_new_slug := trim(both '_' from regexp_replace(lower(p_name), '[^a-z0-9]+', '_', 'g'));

  -- A purely punctuation/whitespace name would slug to empty — reject loudly
  -- since the trigger would too, and a clearer message helps diagnosis.
  IF v_new_slug = '' THEN
    RAISE EXCEPTION 'exercise name produced empty slug: %', p_name
      USING ERRCODE = '22023';
  END IF;

  -- Insert exercise row. When the caller provided `p_id`, use it verbatim so
  -- offline-replayed rows keep the same PK the local Hive cache and any
  -- workout_exercises.exercise_id references already wrote. Otherwise fall
  -- back to a server-allocated UUID (online path).
  INSERT INTO exercises (
    id, user_id, is_default, muscle_group, equipment_type, slug
  )
  VALUES (
    COALESCE(p_id, gen_random_uuid()),
    p_user_id,
    false,
    p_muscle_group::muscle_group,
    p_equipment_type::equipment_type,
    v_new_slug
  )
  RETURNING exercises.id INTO v_new_id;

  -- Insert the single translation row. RLS policy
  -- `exercise_translations_insert_own` allows it because we just inserted
  -- the parent with `user_id = p_user_id = auth.uid()`.
  INSERT INTO exercise_translations (
    exercise_id, locale, name, description, form_tips
  )
  VALUES (
    v_new_id, p_locale, p_name, p_description, p_form_tips
  );

  -- Return the localized view. Single-row case: just call the list RPC with
  -- p_ids = ARRAY[v_new_id]. Avoids duplicating the cascade SELECT here.
  RETURN QUERY
  SELECT * FROM public.fn_exercises_localized(
    p_locale,
    p_user_id,
    NULL, NULL,
    ARRAY[v_new_id]::UUID[],
    'name'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_insert_user_exercise(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID
) TO authenticated;

-- Sanity check: assert exactly one overload exists, and it has 8 args.
-- The prior 7-arg overload must be gone (DROP FUNCTION IF EXISTS above) AND
-- the new 8-arg variant must be in place. Two overloads coexisting causes
-- the dispatch ambiguity that broke the online create-exercise path before
-- this fix was added.
DO $$
DECLARE
  v_overload_count INT;
  v_eight_arg_count INT;
BEGIN
  SELECT COUNT(*)
  INTO v_overload_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'fn_insert_user_exercise';

  SELECT COUNT(*)
  INTO v_eight_arg_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'fn_insert_user_exercise'
    AND p.pronargs = 8;

  IF v_overload_count <> 1 OR v_eight_arg_count <> 1 THEN
    RAISE EXCEPTION 'BUG-003 invariant violated: expected exactly one fn_insert_user_exercise overload (8 args), found % total / % with 8 args',
      v_overload_count, v_eight_arg_count;
  END IF;
END
$$;

COMMIT;
