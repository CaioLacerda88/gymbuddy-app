-- Idempotent seed of default exercises.
-- Only inserts exercises that do not already exist (matched by name + is_default).
-- This ensures production databases get the starter exercise library.

-- CHEST
INSERT INTO exercises (name, muscle_group, equipment_type, is_default, user_id)
SELECT v.name, v.muscle_group::muscle_group, v.equipment_type::equipment_type, true, NULL
FROM (VALUES
  ('Barbell Bench Press',         'chest',     'barbell'),
  ('Incline Barbell Bench Press', 'chest',     'barbell'),
  ('Decline Barbell Bench Press', 'chest',     'barbell'),
  ('Dumbbell Bench Press',        'chest',     'dumbbell'),
  ('Incline Dumbbell Press',      'chest',     'dumbbell'),
  ('Dumbbell Fly',                'chest',     'dumbbell'),
  ('Cable Crossover',             'chest',     'cable'),
  ('Machine Chest Press',         'chest',     'machine'),
  ('Push-Up',                     'chest',     'bodyweight'),

  -- BACK
  ('Barbell Bent-Over Row',       'back',      'barbell'),
  ('Deadlift',                    'back',      'barbell'),
  ('T-Bar Row',                   'back',      'barbell'),
  ('Dumbbell Row',                'back',      'dumbbell'),
  ('Dumbbell Pullover',           'back',      'dumbbell'),
  ('Cable Row',                   'back',      'cable'),
  ('Lat Pulldown',                'back',      'cable'),
  ('Pull-Up',                     'back',      'bodyweight'),
  ('Chin-Up',                     'back',      'bodyweight'),
  ('Machine Row',                 'back',      'machine'),

  -- LEGS
  ('Barbell Squat',               'legs',      'barbell'),
  ('Front Squat',                 'legs',      'barbell'),
  ('Romanian Deadlift',           'legs',      'barbell'),
  ('Hip Thrust',                  'legs',      'barbell'),
  ('Dumbbell Lunges',             'legs',      'dumbbell'),
  ('Bulgarian Split Squat',       'legs',      'dumbbell'),
  ('Goblet Squat',                'legs',      'dumbbell'),
  ('Leg Press',                   'legs',      'machine'),
  ('Leg Extension',               'legs',      'machine'),
  ('Leg Curl',                    'legs',      'machine'),
  ('Calf Raise',                  'legs',      'machine'),

  -- SHOULDERS
  ('Overhead Press',              'shoulders', 'barbell'),
  ('Push Press',                  'shoulders', 'barbell'),
  ('Dumbbell Shoulder Press',     'shoulders', 'dumbbell'),
  ('Arnold Press',                'shoulders', 'dumbbell'),
  ('Lateral Raise',               'shoulders', 'dumbbell'),
  ('Front Raise',                 'shoulders', 'dumbbell'),
  ('Rear Delt Fly',               'shoulders', 'dumbbell'),
  ('Cable Face Pull',             'shoulders', 'cable'),

  -- ARMS
  ('Barbell Curl',                'arms',      'barbell'),
  ('EZ Bar Curl',                 'arms',      'barbell'),
  ('Skull Crusher',               'arms',      'barbell'),
  ('Dumbbell Curl',               'arms',      'dumbbell'),
  ('Hammer Curl',                 'arms',      'dumbbell'),
  ('Concentration Curl',          'arms',      'dumbbell'),
  ('Dumbbell Tricep Extension',   'arms',      'dumbbell'),
  ('Tricep Pushdown',             'arms',      'cable'),
  ('Cable Curl',                  'arms',      'cable'),
  ('Dips',                        'arms',      'bodyweight'),

  -- CORE
  ('Plank',                       'core',      'bodyweight'),
  ('Hanging Leg Raise',           'core',      'bodyweight'),
  ('Crunches',                    'core',      'bodyweight'),
  ('Ab Rollout',                  'core',      'bodyweight'),
  ('Russian Twist',               'core',      'bodyweight'),
  ('Dead Bug',                    'core',      'bodyweight'),
  ('Cable Woodchop',              'core',      'cable'),

  -- BANDS
  ('Band Pull-Apart',             'back',      'bands'),
  ('Band Face Pull',              'shoulders', 'bands'),
  ('Band Squat',                  'legs',      'bands'),

  -- KETTLEBELL
  ('Kettlebell Swing',            'legs',      'kettlebell'),
  ('Kettlebell Goblet Squat',     'legs',      'kettlebell'),
  ('Kettlebell Turkish Get-Up',   'core',      'kettlebell')
) AS v(name, muscle_group, equipment_type)
WHERE NOT EXISTS (
  SELECT 1 FROM exercises e
  WHERE e.name = v.name AND e.is_default = true AND e.deleted_at IS NULL
);

-- Also seed the 4 default workout templates if they don't exist.
-- Templates reference exercises by joining on name.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM workout_templates WHERE is_default = true) THEN
    WITH ex AS (
      SELECT id, name FROM exercises WHERE is_default = true AND deleted_at IS NULL
    ),
    push_day AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Barbell Bench Press'    THEN '[{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180}]'::jsonb
            WHEN 'Incline Dumbbell Press' THEN '[{"target_reps":8,"rest_seconds":120},{"target_reps":8,"rest_seconds":120},{"target_reps":8,"rest_seconds":120}]'::jsonb
            WHEN 'Overhead Press'         THEN '[{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180}]'::jsonb
            WHEN 'Lateral Raise'          THEN '[{"target_reps":15,"rest_seconds":60},{"target_reps":15,"rest_seconds":60},{"target_reps":15,"rest_seconds":60}]'::jsonb
            WHEN 'Tricep Pushdown'        THEN '[{"target_reps":12,"rest_seconds":60},{"target_reps":12,"rest_seconds":60},{"target_reps":12,"rest_seconds":60}]'::jsonb
            WHEN 'Dips'                   THEN '[{"target_reps":10,"rest_seconds":90},{"target_reps":10,"rest_seconds":90},{"target_reps":10,"rest_seconds":90}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Bench Press','Incline Dumbbell Press','Overhead Press','Lateral Raise','Tricep Pushdown','Dips'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Bench Press','Incline Dumbbell Press','Overhead Press','Lateral Raise','Tricep Pushdown','Dips')
    ),
    pull_day AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Deadlift'              THEN '[{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240}]'::jsonb
            WHEN 'Barbell Bent-Over Row' THEN '[{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180},{"target_reps":6,"rest_seconds":180}]'::jsonb
            WHEN 'Lat Pulldown'          THEN '[{"target_reps":10,"rest_seconds":90},{"target_reps":10,"rest_seconds":90},{"target_reps":10,"rest_seconds":90}]'::jsonb
            WHEN 'Cable Row'             THEN '[{"target_reps":12,"rest_seconds":90},{"target_reps":12,"rest_seconds":90},{"target_reps":12,"rest_seconds":90}]'::jsonb
            WHEN 'Barbell Curl'          THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Hammer Curl'           THEN '[{"target_reps":12,"rest_seconds":60},{"target_reps":12,"rest_seconds":60},{"target_reps":12,"rest_seconds":60}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Deadlift','Barbell Bent-Over Row','Lat Pulldown','Cable Row','Barbell Curl','Hammer Curl'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Deadlift','Barbell Bent-Over Row','Lat Pulldown','Cable Row','Barbell Curl','Hammer Curl')
    ),
    leg_day AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Barbell Squat'     THEN '[{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240}]'::jsonb
            WHEN 'Romanian Deadlift' THEN '[{"target_reps":8,"rest_seconds":180},{"target_reps":8,"rest_seconds":180},{"target_reps":8,"rest_seconds":180}]'::jsonb
            WHEN 'Leg Press'         THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Leg Extension'     THEN '[{"target_reps":15,"rest_seconds":60},{"target_reps":15,"rest_seconds":60},{"target_reps":15,"rest_seconds":60}]'::jsonb
            WHEN 'Leg Curl'          THEN '[{"target_reps":15,"rest_seconds":60},{"target_reps":15,"rest_seconds":60},{"target_reps":15,"rest_seconds":60}]'::jsonb
            WHEN 'Calf Raise'        THEN '[{"target_reps":20,"rest_seconds":60},{"target_reps":20,"rest_seconds":60},{"target_reps":20,"rest_seconds":60}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Squat','Romanian Deadlift','Leg Press','Leg Extension','Leg Curl','Calf Raise'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Squat','Romanian Deadlift','Leg Press','Leg Extension','Leg Curl','Calf Raise')
    ),
    full_body AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Barbell Squat'         THEN '[{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240},{"target_reps":5,"rest_seconds":240}]'::jsonb
            WHEN 'Barbell Bench Press'   THEN '[{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180}]'::jsonb
            WHEN 'Barbell Bent-Over Row' THEN '[{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180}]'::jsonb
            WHEN 'Overhead Press'        THEN '[{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180}]'::jsonb
            WHEN 'Barbell Curl'          THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Plank'                 THEN '[{"target_reps":60,"rest_seconds":60},{"target_reps":60,"rest_seconds":60},{"target_reps":60,"rest_seconds":60}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Squat','Barbell Bench Press','Barbell Bent-Over Row','Overhead Press','Barbell Curl','Plank'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Squat','Barbell Bench Press','Barbell Bent-Over Row','Overhead Press','Barbell Curl','Plank')
    )
    INSERT INTO workout_templates (user_id, name, is_default, exercises)
    SELECT NULL::uuid, 'Push Day',   true, exercises FROM push_day
    UNION ALL
    SELECT NULL::uuid, 'Pull Day',   true, exercises FROM pull_day
    UNION ALL
    SELECT NULL::uuid, 'Leg Day',    true, exercises FROM leg_day
    UNION ALL
    SELECT NULL::uuid, 'Full Body',  true, exercises FROM full_body;
  END IF;
END
$$;
