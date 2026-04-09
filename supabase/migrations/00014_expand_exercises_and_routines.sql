-- Expand the exercise library with ~32 new exercises and 5 new routine templates.
-- Requires migration 00013 (adds 'cardio' enum value) to have already committed.

-- Insert new exercises (idempotent — skips existing)
INSERT INTO exercises (name, muscle_group, equipment_type, is_default, user_id)
SELECT v.name, v.muscle_group::muscle_group, v.equipment_type::equipment_type, true, NULL
FROM (VALUES
  -- CHEST (3)
  ('Pec Deck',                    'chest',     'machine'),
  ('Cable Chest Press',           'chest',     'cable'),
  ('Wide Push-Up',                'chest',     'bodyweight'),

  -- BACK (4)
  ('Face Pull',                   'back',      'cable'),
  ('Rack Pull',                   'back',      'barbell'),
  ('Good Morning',                'back',      'barbell'),
  ('Pendlay Row',                 'back',      'barbell'),

  -- LEGS (7)
  ('Hack Squat',                  'legs',      'machine'),
  ('Sumo Deadlift',              'legs',      'barbell'),
  ('Walking Lunges',              'legs',      'dumbbell'),
  ('Step-Up',                     'legs',      'dumbbell'),
  ('Seated Calf Raise',           'legs',      'machine'),
  ('Leg Abductor',                'legs',      'machine'),
  ('Leg Adductor',                'legs',      'machine'),

  -- SHOULDERS (3)
  ('Upright Row',                 'shoulders', 'barbell'),
  ('Machine Shoulder Press',      'shoulders', 'machine'),
  ('Cable Lateral Raise',         'shoulders', 'cable'),

  -- ARMS (5)
  ('Preacher Curl',               'arms',      'barbell'),
  ('Incline Dumbbell Curl',       'arms',      'dumbbell'),
  ('Close-Grip Bench Press',      'arms',      'barbell'),
  ('Overhead Tricep Extension',   'arms',      'cable'),
  ('Rope Pushdown',               'arms',      'cable'),

  -- CORE (5)
  ('Bicycle Crunch',              'core',      'bodyweight'),
  ('Cable Crunch',                'core',      'cable'),
  ('Pallof Press',                'core',      'cable'),
  ('Side Plank',                  'core',      'bodyweight'),
  -- Note: 'Hanging Leg Raise' already exists in migration 00007

  -- CARDIO (5)
  ('Treadmill',                   'cardio',    'machine'),
  ('Rowing Machine',              'cardio',    'machine'),
  ('Stationary Bike',             'cardio',    'machine'),
  ('Jump Rope',                   'cardio',    'bodyweight'),
  ('Elliptical',                  'cardio',    'machine')
) AS v(name, muscle_group, equipment_type)
WHERE NOT EXISTS (
  SELECT 1 FROM exercises e
  WHERE e.name = v.name AND e.is_default = true AND e.deleted_at IS NULL
);

-- Part C: Insert 5 new routine templates (idempotent — skips if name already exists)
DO $$
BEGIN
  -- 1. Upper/Lower — Upper
  IF NOT EXISTS (SELECT 1 FROM workout_templates WHERE name = 'Upper/Lower — Upper' AND is_default = true) THEN
    WITH ex AS (
      SELECT id, name FROM exercises WHERE is_default = true AND deleted_at IS NULL
    ),
    routine_exercises AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Barbell Bench Press'    THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Overhead Press'         THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Incline Dumbbell Press' THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Lateral Raise'          THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Tricep Pushdown'        THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Barbell Curl'           THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Bench Press','Overhead Press','Incline Dumbbell Press','Lateral Raise','Tricep Pushdown','Barbell Curl'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Bench Press','Overhead Press','Incline Dumbbell Press','Lateral Raise','Tricep Pushdown','Barbell Curl')
    )
    INSERT INTO workout_templates (user_id, name, is_default, exercises)
    SELECT NULL::uuid, 'Upper/Lower — Upper', true, exercises FROM routine_exercises;
  END IF;

  -- 2. Upper/Lower — Lower
  IF NOT EXISTS (SELECT 1 FROM workout_templates WHERE name = 'Upper/Lower — Lower' AND is_default = true) THEN
    WITH ex AS (
      SELECT id, name FROM exercises WHERE is_default = true AND deleted_at IS NULL
    ),
    routine_exercises AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Barbell Squat'     THEN '[{"target_reps":10,"rest_seconds":180},{"target_reps":10,"rest_seconds":180},{"target_reps":10,"rest_seconds":180}]'::jsonb
            WHEN 'Romanian Deadlift' THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Leg Press'         THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Leg Extension'     THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Leg Curl'          THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Calf Raise'        THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Squat','Romanian Deadlift','Leg Press','Leg Extension','Leg Curl','Calf Raise'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Squat','Romanian Deadlift','Leg Press','Leg Extension','Leg Curl','Calf Raise')
    )
    INSERT INTO workout_templates (user_id, name, is_default, exercises)
    SELECT NULL::uuid, 'Upper/Lower — Lower', true, exercises FROM routine_exercises;
  END IF;

  -- 3. 5x5 Strength
  IF NOT EXISTS (SELECT 1 FROM workout_templates WHERE name = '5x5 Strength' AND is_default = true) THEN
    WITH ex AS (
      SELECT id, name FROM exercises WHERE is_default = true AND deleted_at IS NULL
    ),
    routine_exercises AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', '[{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180},{"target_reps":5,"rest_seconds":180}]'::jsonb
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Squat','Barbell Bench Press','Barbell Bent-Over Row','Overhead Press','Deadlift'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Squat','Barbell Bench Press','Barbell Bent-Over Row','Overhead Press','Deadlift')
    )
    INSERT INTO workout_templates (user_id, name, is_default, exercises)
    SELECT NULL::uuid, '5x5 Strength', true, exercises FROM routine_exercises;
  END IF;

  -- 4. Full Body Beginner
  IF NOT EXISTS (SELECT 1 FROM workout_templates WHERE name = 'Full Body Beginner' AND is_default = true) THEN
    WITH ex AS (
      SELECT id, name FROM exercises WHERE is_default = true AND deleted_at IS NULL
    ),
    routine_exercises AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', CASE ex.name
            WHEN 'Barbell Squat'       THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Barbell Bench Press'  THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Lat Pulldown'         THEN '[{"target_reps":10,"rest_seconds":90},{"target_reps":10,"rest_seconds":90},{"target_reps":10,"rest_seconds":90}]'::jsonb
            WHEN 'Overhead Press'       THEN '[{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120},{"target_reps":10,"rest_seconds":120}]'::jsonb
            WHEN 'Leg Curl'             THEN '[{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60},{"target_reps":10,"rest_seconds":60}]'::jsonb
            WHEN 'Plank'                THEN '[{"target_reps":60,"rest_seconds":60},{"target_reps":60,"rest_seconds":60},{"target_reps":60,"rest_seconds":60}]'::jsonb
          END
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Squat','Barbell Bench Press','Lat Pulldown','Overhead Press','Leg Curl','Plank'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Squat','Barbell Bench Press','Lat Pulldown','Overhead Press','Leg Curl','Plank')
    )
    INSERT INTO workout_templates (user_id, name, is_default, exercises)
    SELECT NULL::uuid, 'Full Body Beginner', true, exercises FROM routine_exercises;
  END IF;

  -- 5. Arms & Abs
  IF NOT EXISTS (SELECT 1 FROM workout_templates WHERE name = 'Arms & Abs' AND is_default = true) THEN
    WITH ex AS (
      SELECT id, name FROM exercises WHERE is_default = true AND deleted_at IS NULL
    ),
    routine_exercises AS (
      SELECT jsonb_agg(
        jsonb_build_object(
          'exercise_id', ex.id,
          'set_configs', '[{"target_reps":12,"rest_seconds":60},{"target_reps":12,"rest_seconds":60},{"target_reps":12,"rest_seconds":60}]'::jsonb
        ) ORDER BY ARRAY_POSITION(
          ARRAY['Barbell Curl','Hammer Curl','Preacher Curl','Tricep Pushdown','Rope Pushdown','Cable Crunch','Hanging Leg Raise'], ex.name
        )
      ) AS exercises
      FROM ex WHERE ex.name IN ('Barbell Curl','Hammer Curl','Preacher Curl','Tricep Pushdown','Rope Pushdown','Cable Crunch','Hanging Leg Raise')
    )
    INSERT INTO workout_templates (user_id, name, is_default, exercises)
    SELECT NULL::uuid, 'Arms & Abs', true, exercises FROM routine_exercises;
  END IF;
END
$$;
