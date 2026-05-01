-- =============================================================================
-- Cluster 7 — DB integrity (BUG-031, BUG-032)
-- Migration: 00046_indexes_workout_exercises_pr_set_id
--
-- Adds two missing indexes that should have shipped with 00001 / 00008. Both
-- are FK columns whose covering indexes are needed for:
--   1. PostgreSQL's per-row FK trigger (deletes on the referenced table scan
--      the referencing column — without an index, this is a sequential scan
--      across the entire workout_exercises / personal_records table).
--   2. Application query patterns ("show me all workouts that include
--      exercise X" / "look up the PR linked to set S").
--
-- BUG-031: workout_exercises.exercise_id had no index. The only existing
--          index on workout_exercises is (workout_id) at 00001:139.
--
-- BUG-032: personal_records.set_id had no index after 00008 rewired the FK
--          to ON DELETE SET NULL. SET NULL still requires an index on the
--          referencing column to avoid sequential scans on set deletes.
--
-- Idempotent: CREATE INDEX IF NOT EXISTS — safe to re-run.
--
-- Note: we do NOT use CREATE INDEX CONCURRENTLY because the Supabase CLI
-- wraps each migration in an implicit transaction, and CONCURRENTLY cannot
-- run inside a transaction block. For the current table sizes this is a
-- non-issue; if these tables grow into production scale where the brief
-- ACCESS EXCLUSIVE lock during index build matters, schedule the index
-- build via a separate maintenance script using `supabase db execute` with
-- explicit transaction control.
-- =============================================================================

CREATE INDEX IF NOT EXISTS workout_exercises_exercise_id_idx
  ON public.workout_exercises (exercise_id);

CREATE INDEX IF NOT EXISTS personal_records_set_id_idx
  ON public.personal_records (set_id);
