-- Step 12a: Weekly Training Plan — Bucket Model
-- Creates weekly_plans table and adds training_frequency_per_week to profiles.

-- Add training frequency to profiles (soft cap for bucket planning).
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS training_frequency_per_week INTEGER NOT NULL DEFAULT 3
  CHECK (training_frequency_per_week BETWEEN 2 AND 6);

-- Weekly plan bucket table.
CREATE TABLE weekly_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start DATE NOT NULL,  -- always a Monday (ISO week start)
  routines JSONB NOT NULL DEFAULT '[]',
  -- Array of: [{routine_id: UUID, order: int, completed_workout_id: UUID|null, completed_at: timestamptz|null}]
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);

-- RLS: users can only access their own plans.
ALTER TABLE weekly_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own plans" ON weekly_plans
  FOR ALL USING (auth.uid() = user_id);

-- Index for efficient lookups by user and week.
CREATE INDEX idx_weekly_plans_user_week ON weekly_plans (user_id, week_start DESC);
