-- Add optional reps column to personal_records.
-- The Dart model (PersonalRecord) expects this column for record types
-- like "max_reps" and "max_volume" where rep count is relevant.
ALTER TABLE personal_records ADD COLUMN IF NOT EXISTS reps integer;
