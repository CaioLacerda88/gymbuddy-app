-- Fix exercise images: replace broken raw.githubusercontent.com URLs
-- (migration 00004) with Supabase Storage rehosts in the 'exercise-media' bucket.
--
-- Root cause: the original seed URLs in 00004 referenced folder names like
-- 'Barbell_Bench_Press/' that never existed in yuhonas/free-exercise-db — the
-- source repo uses descriptive names like 'Barbell_Bench_Press_-_Medium_Grip/'.
-- Every one of those URLs has returned HTTP 404 since the migration shipped.
--
-- This migration points each of the 59 default exercises at the rehosted
-- assets that now live in the public 'exercise-media' bucket (provisioned
-- in migration 00003). See tools/exercise_image_mapping.json for the full
-- name -> source_id -> upload_slug audit trail, and
-- tools/fix_exercise_images.dart for the download+upload tooling.
--
-- PR: feature/phase13-sprintb-p4-images (PLAN.md Phase 13 Sprint B, row P4).

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_bench_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_bench_press_end.jpg'
  WHERE name = 'Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/incline_barbell_bench_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/incline_barbell_bench_press_end.jpg'
  WHERE name = 'Incline Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/decline_barbell_bench_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/decline_barbell_bench_press_end.jpg'
  WHERE name = 'Decline Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_bench_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_bench_press_end.jpg'
  WHERE name = 'Dumbbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/incline_dumbbell_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/incline_dumbbell_press_end.jpg'
  WHERE name = 'Incline Dumbbell Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_fly_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_fly_end.jpg'
  WHERE name = 'Dumbbell Fly' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_crossover_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_crossover_end.jpg'
  WHERE name = 'Cable Crossover' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/machine_chest_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/machine_chest_press_end.jpg'
  WHERE name = 'Machine Chest Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/push_up_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/push_up_end.jpg'
  WHERE name = 'Push-Up' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_bent_over_row_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_bent_over_row_end.jpg'
  WHERE name = 'Barbell Bent-Over Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/deadlift_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/deadlift_end.jpg'
  WHERE name = 'Deadlift' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/t_bar_row_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/t_bar_row_end.jpg'
  WHERE name = 'T-Bar Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_row_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_row_end.jpg'
  WHERE name = 'Dumbbell Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_pullover_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_pullover_end.jpg'
  WHERE name = 'Dumbbell Pullover' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_row_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_row_end.jpg'
  WHERE name = 'Cable Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/lat_pulldown_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/lat_pulldown_end.jpg'
  WHERE name = 'Lat Pulldown' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/pull_up_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/pull_up_end.jpg'
  WHERE name = 'Pull-Up' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/chin_up_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/chin_up_end.jpg'
  WHERE name = 'Chin-Up' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/machine_row_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/machine_row_end.jpg'
  WHERE name = 'Machine Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_squat_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_squat_end.jpg'
  WHERE name = 'Barbell Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/front_squat_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/front_squat_end.jpg'
  WHERE name = 'Front Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/romanian_deadlift_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/romanian_deadlift_end.jpg'
  WHERE name = 'Romanian Deadlift' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/hip_thrust_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/hip_thrust_end.jpg'
  WHERE name = 'Hip Thrust' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_lunges_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_lunges_end.jpg'
  WHERE name = 'Dumbbell Lunges' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/bulgarian_split_squat_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/bulgarian_split_squat_end.jpg'
  WHERE name = 'Bulgarian Split Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/goblet_squat_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/goblet_squat_end.jpg'
  WHERE name = 'Goblet Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/leg_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/leg_press_end.jpg'
  WHERE name = 'Leg Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/leg_extension_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/leg_extension_end.jpg'
  WHERE name = 'Leg Extension' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/leg_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/leg_curl_end.jpg'
  WHERE name = 'Leg Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/calf_raise_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/calf_raise_end.jpg'
  WHERE name = 'Calf Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/overhead_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/overhead_press_end.jpg'
  WHERE name = 'Overhead Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/push_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/push_press_end.jpg'
  WHERE name = 'Push Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_shoulder_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_shoulder_press_end.jpg'
  WHERE name = 'Dumbbell Shoulder Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/arnold_press_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/arnold_press_end.jpg'
  WHERE name = 'Arnold Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/lateral_raise_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/lateral_raise_end.jpg'
  WHERE name = 'Lateral Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/front_raise_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/front_raise_end.jpg'
  WHERE name = 'Front Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/rear_delt_fly_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/rear_delt_fly_end.jpg'
  WHERE name = 'Rear Delt Fly' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_face_pull_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_face_pull_end.jpg'
  WHERE name = 'Cable Face Pull' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/barbell_curl_end.jpg'
  WHERE name = 'Barbell Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/ez_bar_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/ez_bar_curl_end.jpg'
  WHERE name = 'EZ Bar Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/skull_crusher_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/skull_crusher_end.jpg'
  WHERE name = 'Skull Crusher' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_curl_end.jpg'
  WHERE name = 'Dumbbell Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/hammer_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/hammer_curl_end.jpg'
  WHERE name = 'Hammer Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/concentration_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/concentration_curl_end.jpg'
  WHERE name = 'Concentration Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_tricep_extension_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dumbbell_tricep_extension_end.jpg'
  WHERE name = 'Dumbbell Tricep Extension' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/tricep_pushdown_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/tricep_pushdown_end.jpg'
  WHERE name = 'Tricep Pushdown' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_curl_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_curl_end.jpg'
  WHERE name = 'Cable Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dips_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dips_end.jpg'
  WHERE name = 'Dips' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/plank_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/plank_end.jpg'
  WHERE name = 'Plank' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/hanging_leg_raise_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/hanging_leg_raise_end.jpg'
  WHERE name = 'Hanging Leg Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/crunches_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/crunches_end.jpg'
  WHERE name = 'Crunches' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/ab_rollout_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/ab_rollout_end.jpg'
  WHERE name = 'Ab Rollout' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/russian_twist_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/russian_twist_end.jpg'
  WHERE name = 'Russian Twist' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dead_bug_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/dead_bug_end.jpg'
  WHERE name = 'Dead Bug' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_woodchop_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/cable_woodchop_end.jpg'
  WHERE name = 'Cable Woodchop' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/band_pull_apart_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/band_pull_apart_end.jpg'
  WHERE name = 'Band Pull-Apart' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/kettlebell_swing_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/kettlebell_swing_end.jpg'
  WHERE name = 'Kettlebell Swing' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/kettlebell_goblet_squat_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/kettlebell_goblet_squat_end.jpg'
  WHERE name = 'Kettlebell Goblet Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/kettlebell_turkish_get_up_start.jpg',
  image_end_url   = 'https://dgcueqvqfyuedclkxixz.supabase.co/storage/v1/object/public/exercise-media/kettlebell_turkish_get_up_end.jpg'
  WHERE name = 'Kettlebell Turkish Get-Up' AND is_default = true;

