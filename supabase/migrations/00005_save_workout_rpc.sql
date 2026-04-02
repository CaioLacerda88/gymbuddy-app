-- =============================================================================
-- Step 5a: Atomic Workout Save RPC
-- Migration: 00005_save_workout_rpc
--
-- Creates a Postgres RPC function that atomically saves a completed workout
-- with all its exercises and sets in a single transaction.
--
-- Atomicity: Supabase wraps each RPC call in a transaction. If any statement
-- fails (e.g., constraint violation on sets), the entire operation rolls back.
-- The plpgsql function body executes within that transaction.
-- =============================================================================

CREATE OR REPLACE FUNCTION save_workout(
  p_workout jsonb,
  p_exercises jsonb,
  p_sets jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workout_id uuid;
  v_user_id uuid;
  v_result jsonb;
BEGIN
  -- Extract IDs from input
  v_workout_id := (p_workout ->> 'id')::uuid;
  v_user_id := (p_workout ->> 'user_id')::uuid;

  -- Validate that the caller owns this workout
  IF v_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: workout user_id does not match authenticated user'
      USING ERRCODE = '42501';
  END IF;

  -- Verify the workout exists and belongs to the user
  IF NOT EXISTS (
    SELECT 1 FROM workouts
    WHERE id = v_workout_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Workout not found or does not belong to user'
      USING ERRCODE = 'P0002';
  END IF;

  -- Delete existing exercises and sets (cascade handles sets)
  DELETE FROM workout_exercises WHERE workout_id = v_workout_id;

  -- Update the workout row to mark it as finished
  UPDATE workouts
  SET
    name             = COALESCE(p_workout ->> 'name', name),
    finished_at      = (p_workout ->> 'finished_at')::timestamptz,
    duration_seconds = (p_workout ->> 'duration_seconds')::integer,
    notes            = p_workout ->> 'notes',
    is_active        = false
  WHERE id = v_workout_id AND user_id = v_user_id;

  -- Insert workout exercises
  INSERT INTO workout_exercises (id, workout_id, exercise_id, "order", rest_seconds)
  SELECT
    (e ->> 'id')::uuid,
    (e ->> 'workout_id')::uuid,
    (e ->> 'exercise_id')::uuid,
    (e ->> 'order')::integer,
    (e ->> 'rest_seconds')::integer
  FROM jsonb_array_elements(p_exercises) AS e;

  -- Insert sets
  INSERT INTO sets (id, workout_exercise_id, set_number, reps, weight, rpe, set_type, notes, is_completed)
  SELECT
    (s ->> 'id')::uuid,
    (s ->> 'workout_exercise_id')::uuid,
    (s ->> 'set_number')::integer,
    (s ->> 'reps')::integer,
    (s ->> 'weight')::numeric,
    (s ->> 'rpe')::integer,
    COALESCE(s ->> 'set_type', 'working'),
    s ->> 'notes',
    COALESCE((s ->> 'is_completed')::boolean, false)
  FROM jsonb_array_elements(p_sets) AS s;

  -- Return the updated workout row as jsonb
  SELECT to_jsonb(w) INTO v_result
  FROM workouts w
  WHERE w.id = v_workout_id;

  RETURN v_result;
END;
$$;

-- Grant execute to authenticated users (required for SECURITY DEFINER functions)
GRANT EXECUTE ON FUNCTION save_workout(jsonb, jsonb, jsonb) TO authenticated;
