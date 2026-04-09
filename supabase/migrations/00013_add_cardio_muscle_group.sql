-- Add 'cardio' to the muscle_group enum.
-- Must be in its own migration (separate transaction) because PostgreSQL
-- does not allow using a new enum value in the same transaction it was added.
ALTER TYPE muscle_group ADD VALUE IF NOT EXISTS 'cardio';
