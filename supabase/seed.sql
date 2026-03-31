-- GymBuddy Seed Data
-- Default exercises (~60) and starter workout templates (4)
-- Run after migrations: psql ... < supabase/seed.sql

-- ============================================================
-- EXERCISES
-- ============================================================

-- Store inserted exercise IDs for use in templates
WITH inserted_exercises AS (
  INSERT INTO exercises (id, name, muscle_group, equipment_type, is_default, user_id, created_at)
  VALUES
    -- CHEST
    (gen_random_uuid(), 'Barbell Bench Press',         'chest',     'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Incline Barbell Bench Press', 'chest',     'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Decline Barbell Bench Press', 'chest',     'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Bench Press',         'chest',     'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Incline Dumbbell Press',       'chest',     'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Fly',                 'chest',     'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Cable Crossover',              'chest',     'cable',      true, NULL, NOW()),
    (gen_random_uuid(), 'Machine Chest Press',          'chest',     'machine',    true, NULL, NOW()),
    (gen_random_uuid(), 'Push-Up',                      'chest',     'bodyweight', true, NULL, NOW()),

    -- BACK
    (gen_random_uuid(), 'Barbell Bent-Over Row',        'back',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Deadlift',                     'back',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'T-Bar Row',                    'back',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Row',                 'back',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Pullover',            'back',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Cable Row',                    'back',      'cable',      true, NULL, NOW()),
    (gen_random_uuid(), 'Lat Pulldown',                 'back',      'cable',      true, NULL, NOW()),
    (gen_random_uuid(), 'Pull-Up',                      'back',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Chin-Up',                      'back',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Machine Row',                  'back',      'machine',    true, NULL, NOW()),

    -- LEGS
    (gen_random_uuid(), 'Barbell Squat',                'legs',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Front Squat',                  'legs',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Romanian Deadlift',            'legs',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Hip Thrust',                   'legs',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Lunges',              'legs',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Bulgarian Split Squat',        'legs',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Goblet Squat',                 'legs',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Leg Press',                    'legs',      'machine',    true, NULL, NOW()),
    (gen_random_uuid(), 'Leg Extension',                'legs',      'machine',    true, NULL, NOW()),
    (gen_random_uuid(), 'Leg Curl',                     'legs',      'machine',    true, NULL, NOW()),
    (gen_random_uuid(), 'Calf Raise',                   'legs',      'machine',    true, NULL, NOW()),

    -- SHOULDERS
    (gen_random_uuid(), 'Overhead Press',               'shoulders', 'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Push Press',                   'shoulders', 'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Shoulder Press',      'shoulders', 'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Arnold Press',                 'shoulders', 'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Lateral Raise',                'shoulders', 'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Front Raise',                  'shoulders', 'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Rear Delt Fly',                'shoulders', 'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Cable Face Pull',              'shoulders', 'cable',      true, NULL, NOW()),

    -- ARMS
    (gen_random_uuid(), 'Barbell Curl',                 'arms',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'EZ Bar Curl',                  'arms',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Skull Crusher',                'arms',      'barbell',    true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Curl',                'arms',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Hammer Curl',                  'arms',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Concentration Curl',           'arms',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Dumbbell Tricep Extension',    'arms',      'dumbbell',   true, NULL, NOW()),
    (gen_random_uuid(), 'Tricep Pushdown',              'arms',      'cable',      true, NULL, NOW()),
    (gen_random_uuid(), 'Cable Curl',                   'arms',      'cable',      true, NULL, NOW()),
    (gen_random_uuid(), 'Dips',                         'arms',      'bodyweight', true, NULL, NOW()),

    -- CORE
    (gen_random_uuid(), 'Plank',                        'core',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Hanging Leg Raise',            'core',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Crunches',                     'core',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Ab Rollout',                   'core',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Russian Twist',                'core',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Dead Bug',                     'core',      'bodyweight', true, NULL, NOW()),
    (gen_random_uuid(), 'Cable Woodchop',               'core',      'cable',      true, NULL, NOW()),

    -- BANDS
    (gen_random_uuid(), 'Band Pull-Apart',              'back',      'bands',      true, NULL, NOW()),
    (gen_random_uuid(), 'Band Face Pull',               'shoulders', 'bands',      true, NULL, NOW()),
    (gen_random_uuid(), 'Band Squat',                   'legs',      'bands',      true, NULL, NOW()),

    -- KETTLEBELL
    (gen_random_uuid(), 'Kettlebell Swing',             'legs',      'kettlebell', true, NULL, NOW()),
    (gen_random_uuid(), 'Kettlebell Goblet Squat',      'legs',      'kettlebell', true, NULL, NOW()),
    (gen_random_uuid(), 'Kettlebell Turkish Get-Up',    'core',      'kettlebell', true, NULL, NOW())

  RETURNING id, name
),

-- ============================================================
-- WORKOUT TEMPLATES
-- Reference exercises by name since IDs are generated above.
-- ============================================================

-- Extract IDs for the exercises used in templates
ex AS (
  SELECT name, id FROM inserted_exercises
),

-- PUSH DAY exercises JSONB
push_day_exercises AS (
  SELECT jsonb_agg(
    jsonb_build_object(
      'exercise_id', ex.id,
      'set_configs', CASE ex.name
        -- Compounds: 4 sets x 6 reps, 3 min rest
        WHEN 'Barbell Bench Press'    THEN '[{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180}]'::jsonb
        WHEN 'Incline Dumbbell Press' THEN '[{"target_reps":8,"target_weight":null,"rest_seconds":120},{"target_reps":8,"target_weight":null,"rest_seconds":120},{"target_reps":8,"target_weight":null,"rest_seconds":120}]'::jsonb
        WHEN 'Overhead Press'         THEN '[{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180}]'::jsonb
        -- Isolations: 3 sets x 12-15 reps, 60-90 s rest
        WHEN 'Lateral Raise'          THEN '[{"target_reps":15,"target_weight":null,"rest_seconds":60},{"target_reps":15,"target_weight":null,"rest_seconds":60},{"target_reps":15,"target_weight":null,"rest_seconds":60}]'::jsonb
        WHEN 'Tricep Pushdown'        THEN '[{"target_reps":12,"target_weight":null,"rest_seconds":60},{"target_reps":12,"target_weight":null,"rest_seconds":60},{"target_reps":12,"target_weight":null,"rest_seconds":60}]'::jsonb
        WHEN 'Dips'                   THEN '[{"target_reps":10,"target_weight":null,"rest_seconds":90},{"target_reps":10,"target_weight":null,"rest_seconds":90},{"target_reps":10,"target_weight":null,"rest_seconds":90}]'::jsonb
      END
    )
    ORDER BY ARRAY_POSITION(
      ARRAY['Barbell Bench Press','Incline Dumbbell Press','Overhead Press','Lateral Raise','Tricep Pushdown','Dips'],
      ex.name
    )
  ) AS exercises
  FROM ex
  WHERE ex.name IN ('Barbell Bench Press','Incline Dumbbell Press','Overhead Press','Lateral Raise','Tricep Pushdown','Dips')
),

-- PULL DAY exercises JSONB
pull_day_exercises AS (
  SELECT jsonb_agg(
    jsonb_build_object(
      'exercise_id', ex.id,
      'set_configs', CASE ex.name
        WHEN 'Deadlift'              THEN '[{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240}]'::jsonb
        WHEN 'Barbell Bent-Over Row' THEN '[{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180},{"target_reps":6,"target_weight":null,"rest_seconds":180}]'::jsonb
        WHEN 'Lat Pulldown'          THEN '[{"target_reps":10,"target_weight":null,"rest_seconds":90},{"target_reps":10,"target_weight":null,"rest_seconds":90},{"target_reps":10,"target_weight":null,"rest_seconds":90}]'::jsonb
        WHEN 'Cable Row'             THEN '[{"target_reps":12,"target_weight":null,"rest_seconds":90},{"target_reps":12,"target_weight":null,"rest_seconds":90},{"target_reps":12,"target_weight":null,"rest_seconds":90}]'::jsonb
        WHEN 'Barbell Curl'          THEN '[{"target_reps":10,"target_weight":null,"rest_seconds":60},{"target_reps":10,"target_weight":null,"rest_seconds":60},{"target_reps":10,"target_weight":null,"rest_seconds":60}]'::jsonb
        WHEN 'Hammer Curl'           THEN '[{"target_reps":12,"target_weight":null,"rest_seconds":60},{"target_reps":12,"target_weight":null,"rest_seconds":60},{"target_reps":12,"target_weight":null,"rest_seconds":60}]'::jsonb
      END
    )
    ORDER BY ARRAY_POSITION(
      ARRAY['Deadlift','Barbell Bent-Over Row','Lat Pulldown','Cable Row','Barbell Curl','Hammer Curl'],
      ex.name
    )
  ) AS exercises
  FROM ex
  WHERE ex.name IN ('Deadlift','Barbell Bent-Over Row','Lat Pulldown','Cable Row','Barbell Curl','Hammer Curl')
),

-- LEG DAY exercises JSONB
leg_day_exercises AS (
  SELECT jsonb_agg(
    jsonb_build_object(
      'exercise_id', ex.id,
      'set_configs', CASE ex.name
        WHEN 'Barbell Squat'    THEN '[{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240}]'::jsonb
        WHEN 'Romanian Deadlift' THEN '[{"target_reps":8,"target_weight":null,"rest_seconds":180},{"target_reps":8,"target_weight":null,"rest_seconds":180},{"target_reps":8,"target_weight":null,"rest_seconds":180}]'::jsonb
        WHEN 'Leg Press'        THEN '[{"target_reps":10,"target_weight":null,"rest_seconds":120},{"target_reps":10,"target_weight":null,"rest_seconds":120},{"target_reps":10,"target_weight":null,"rest_seconds":120}]'::jsonb
        WHEN 'Leg Extension'    THEN '[{"target_reps":15,"target_weight":null,"rest_seconds":60},{"target_reps":15,"target_weight":null,"rest_seconds":60},{"target_reps":15,"target_weight":null,"rest_seconds":60}]'::jsonb
        WHEN 'Leg Curl'         THEN '[{"target_reps":15,"target_weight":null,"rest_seconds":60},{"target_reps":15,"target_weight":null,"rest_seconds":60},{"target_reps":15,"target_weight":null,"rest_seconds":60}]'::jsonb
        WHEN 'Calf Raise'       THEN '[{"target_reps":20,"target_weight":null,"rest_seconds":60},{"target_reps":20,"target_weight":null,"rest_seconds":60},{"target_reps":20,"target_weight":null,"rest_seconds":60}]'::jsonb
      END
    )
    ORDER BY ARRAY_POSITION(
      ARRAY['Barbell Squat','Romanian Deadlift','Leg Press','Leg Extension','Leg Curl','Calf Raise'],
      ex.name
    )
  ) AS exercises
  FROM ex
  WHERE ex.name IN ('Barbell Squat','Romanian Deadlift','Leg Press','Leg Extension','Leg Curl','Calf Raise')
),

-- FULL BODY exercises JSONB
full_body_exercises AS (
  SELECT jsonb_agg(
    jsonb_build_object(
      'exercise_id', ex.id,
      'set_configs', CASE ex.name
        WHEN 'Barbell Squat'        THEN '[{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240},{"target_reps":5,"target_weight":null,"rest_seconds":240}]'::jsonb
        WHEN 'Barbell Bench Press'  THEN '[{"target_reps":5,"target_weight":null,"rest_seconds":180},{"target_reps":5,"target_weight":null,"rest_seconds":180},{"target_reps":5,"target_weight":null,"rest_seconds":180}]'::jsonb
        WHEN 'Barbell Bent-Over Row' THEN '[{"target_reps":5,"target_weight":null,"rest_seconds":180},{"target_reps":5,"target_weight":null,"rest_seconds":180},{"target_reps":5,"target_weight":null,"rest_seconds":180}]'::jsonb
        WHEN 'Overhead Press'       THEN '[{"target_reps":5,"target_weight":null,"rest_seconds":180},{"target_reps":5,"target_weight":null,"rest_seconds":180},{"target_reps":5,"target_weight":null,"rest_seconds":180}]'::jsonb
        WHEN 'Barbell Curl'         THEN '[{"target_reps":10,"target_weight":null,"rest_seconds":60},{"target_reps":10,"target_weight":null,"rest_seconds":60},{"target_reps":10,"target_weight":null,"rest_seconds":60}]'::jsonb
        WHEN 'Plank'                THEN '[{"target_reps":60,"target_weight":null,"rest_seconds":60},{"target_reps":60,"target_weight":null,"rest_seconds":60},{"target_reps":60,"target_weight":null,"rest_seconds":60}]'::jsonb
      END
    )
    ORDER BY ARRAY_POSITION(
      ARRAY['Barbell Squat','Barbell Bench Press','Barbell Bent-Over Row','Overhead Press','Barbell Curl','Plank'],
      ex.name
    )
  ) AS exercises
  FROM ex
  WHERE ex.name IN ('Barbell Squat','Barbell Bench Press','Barbell Bent-Over Row','Overhead Press','Barbell Curl','Plank')
)

INSERT INTO workout_templates (id, user_id, name, is_default, exercises, created_at)
SELECT gen_random_uuid(), NULL::uuid, 'Push Day', true, push_day_exercises.exercises, NOW() FROM push_day_exercises
UNION ALL
SELECT gen_random_uuid(), NULL::uuid, 'Pull Day', true, pull_day_exercises.exercises, NOW() FROM pull_day_exercises
UNION ALL
SELECT gen_random_uuid(), NULL::uuid, 'Leg Day', true, leg_day_exercises.exercises, NOW() FROM leg_day_exercises
UNION ALL
SELECT gen_random_uuid(), NULL::uuid, 'Full Body', true, full_body_exercises.exercises, NOW() FROM full_body_exercises;
