-- =============================================================================
-- Expand default exercise library from 92 to 150 entries
-- Migration: 00019_expand_exercise_library
--
-- Inserts 58 new default exercises across chest, back, legs, shoulders, arms
-- and core. Idempotent (safe to re-run) — skips rows that already exist with
-- the same name and is_default = true. Follows the pattern established in
-- 00014_expand_exercises_and_routines.
--
-- Descriptions and form_tips for these rows (plus a backfill for the 31
-- content-less rows from 00014) are populated in the companion migration
-- 00020_seed_exercise_content_p9. After both migrations run, every default
-- exercise has non-NULL description and form_tips.
-- =============================================================================

INSERT INTO exercises (name, muscle_group, equipment_type, is_default, user_id)
SELECT v.name, v.muscle_group::muscle_group, v.equipment_type::equipment_type, true, NULL
FROM (VALUES
  -- CHEST (6)
  ('Incline Dumbbell Fly',           'chest',     'dumbbell'),
  ('Decline Dumbbell Press',         'chest',     'dumbbell'),
  ('Landmine Press',                 'chest',     'barbell'),
  ('Diamond Push-Up',                'chest',     'bodyweight'),
  ('Incline Push-Up',                'chest',     'bodyweight'),
  ('Decline Push-Up',                'chest',     'bodyweight'),

  -- BACK (9)
  ('Hyperextension',                 'back',      'bodyweight'),
  ('Back Extension',                 'back',      'machine'),
  ('Inverted Row',                   'back',      'bodyweight'),
  ('Chest-Supported Row',            'back',      'dumbbell'),
  ('Seal Row',                       'back',      'barbell'),
  ('Straight-Arm Pulldown',          'back',      'cable'),
  ('Close-Grip Lat Pulldown',        'back',      'cable'),
  ('Wide-Grip Pull-Up',              'back',      'bodyweight'),
  ('Kettlebell Row',                 'back',      'kettlebell'),

  -- LEGS (14)
  ('Glute Bridge',                   'legs',      'bodyweight'),
  ('Single-Leg Glute Bridge',        'legs',      'bodyweight'),
  ('Box Jump',                       'legs',      'bodyweight'),
  ('Nordic Curl',                    'legs',      'bodyweight'),
  ('Wall Sit',                       'legs',      'bodyweight'),
  ('Donkey Kick',                    'legs',      'bodyweight'),
  ('Bodyweight Squat',               'legs',      'bodyweight'),
  ('Reverse Lunges',                 'legs',      'dumbbell'),
  ('Dumbbell Calf Raise',            'legs',      'dumbbell'),
  ('Single-Leg Leg Press',           'legs',      'machine'),
  ('Reverse Hyperextension',         'legs',      'machine'),
  ('Cable Glute Kickback',           'legs',      'cable'),
  ('Cable Pull-Through',             'legs',      'cable'),
  ('Kettlebell Deadlift',            'legs',      'kettlebell'),

  -- SHOULDERS (7)
  ('Barbell Shrug',                  'shoulders', 'barbell'),
  ('Dumbbell Shrug',                 'shoulders', 'dumbbell'),
  ('Cable Rear Delt Fly',            'shoulders', 'cable'),
  ('Cable Front Raise',              'shoulders', 'cable'),
  ('Reverse Pec Deck',               'shoulders', 'machine'),
  ('Landmine Shoulder Press',        'shoulders', 'barbell'),
  ('Kettlebell Press',               'shoulders', 'kettlebell'),

  -- ARMS (10)
  ('Spider Curl',                    'arms',      'dumbbell'),
  ('Zottman Curl',                   'arms',      'dumbbell'),
  ('Reverse Curl',                   'arms',      'barbell'),
  ('Wrist Curl',                     'arms',      'dumbbell'),
  ('Reverse Wrist Curl',             'arms',      'dumbbell'),
  ('Farmer''s Walk',                 'arms',      'dumbbell'),
  ('Cable Hammer Curl',              'arms',      'cable'),
  ('Bench Dip',                      'arms',      'bodyweight'),
  ('Close-Grip Push-Up',             'arms',      'bodyweight'),
  ('JM Press',                       'arms',      'barbell'),

  -- CORE (12)
  ('Sit-Up',                         'core',      'bodyweight'),
  ('Mountain Climber',               'core',      'bodyweight'),
  ('Toe Touch',                      'core',      'bodyweight'),
  ('Hollow Body Hold',               'core',      'bodyweight'),
  ('V-Up',                           'core',      'bodyweight'),
  ('Flutter Kick',                   'core',      'bodyweight'),
  ('Reverse Crunch',                 'core',      'bodyweight'),
  ('Leg Raise',                      'core',      'bodyweight'),
  ('Windshield Wiper',               'core',      'bodyweight'),
  ('Plank Up-Down',                  'core',      'bodyweight'),
  ('Heel Touch',                     'core',      'bodyweight'),
  ('Kettlebell Windmill',            'core',      'kettlebell')
) AS v(name, muscle_group, equipment_type)
WHERE NOT EXISTS (
  SELECT 1 FROM exercises e
  WHERE e.name = v.name AND e.is_default = true AND e.deleted_at IS NULL
);

-- Reload PostgREST schema cache so new rows become queryable immediately.
NOTIFY pgrst, 'reload schema';
