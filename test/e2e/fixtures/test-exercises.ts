/**
 * Known exercise names from supabase/seed.sql.
 *
 * Use these constants in tests instead of raw strings to avoid typos and
 * make it obvious when a name change in seed data would break tests.
 *
 * Verified against supabase/seed.sql — exact names as stored in the database.
 */

export const SEED_EXERCISES = {
  benchPress: 'Barbell Bench Press',
  squat: 'Barbell Squat',
  deadlift: 'Deadlift',
  overheadPress: 'Overhead Press',
} as const;
