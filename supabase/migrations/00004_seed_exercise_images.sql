-- Seed exercise images from Free Exercise DB (public domain, Unlicense)
-- URL pattern: https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{name}/0.jpg (start)
-- URL pattern: https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{name}/1.jpg (end)

-- CHEST
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press/1.jpg'
WHERE name = 'Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Incline_Bench_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Incline_Bench_Press/1.jpg'
WHERE name = 'Incline Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Decline_Bench_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Decline_Bench_Press/1.jpg'
WHERE name = 'Decline Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bench_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bench_Press/1.jpg'
WHERE name = 'Dumbbell Bench Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/1.jpg'
WHERE name = 'Incline Dumbbell Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Flyes/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Flyes/1.jpg'
WHERE name = 'Dumbbell Fly' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/1.jpg'
WHERE name = 'Cable Crossover' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Chest_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Chest_Press/1.jpg'
WHERE name = 'Machine Chest Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push-Ups/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push-Ups/1.jpg'
WHERE name = 'Push-Up' AND is_default = true;

-- BACK
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bent_Over_Row/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bent_Over_Row/1.jpg'
WHERE name = 'Barbell Bent-Over Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Deadlift/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Deadlift/1.jpg'
WHERE name = 'Deadlift' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_T-Bar_Row/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_T-Bar_Row/1.jpg'
WHERE name = 'T-Bar Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bent_Over_Row/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bent_Over_Row/1.jpg'
WHERE name = 'Dumbbell Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Pullover/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Pullover/1.jpg'
WHERE name = 'Dumbbell Pullover' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Cable_Rows/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Cable_Rows/1.jpg'
WHERE name = 'Cable Row' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/1.jpg'
WHERE name = 'Lat Pulldown' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pullups/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pullups/1.jpg'
WHERE name = 'Pull-Up' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Chin-Up/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Chin-Up/1.jpg'
WHERE name = 'Chin-Up' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lever_Seated_Row/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lever_Seated_Row/1.jpg'
WHERE name = 'Machine Row' AND is_default = true;

-- LEGS
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/1.jpg'
WHERE name = 'Barbell Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Front_Squat/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Front_Squat/1.jpg'
WHERE name = 'Front Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift_With_Dumbbells/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift_With_Dumbbells/1.jpg'
WHERE name = 'Romanian Deadlift' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Hip_Thrust/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Hip_Thrust/1.jpg'
WHERE name = 'Hip Thrust' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/1.jpg'
WHERE name = 'Dumbbell Lunges' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Single_Leg_Split_Squat/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Single_Leg_Split_Squat/1.jpg'
WHERE name = 'Bulgarian Split Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/1.jpg'
WHERE name = 'Goblet Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/1.jpg'
WHERE name = 'Leg Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/1.jpg'
WHERE name = 'Leg Extension' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Leg_Curls/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Leg_Curls/1.jpg'
WHERE name = 'Leg Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/1.jpg'
WHERE name = 'Calf Raise' AND is_default = true;

-- SHOULDERS
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shoulder_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shoulder_Press/1.jpg'
WHERE name = 'Overhead Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push_Press/1.jpg'
WHERE name = 'Push Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shoulder_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shoulder_Press/1.jpg'
WHERE name = 'Dumbbell Shoulder Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arnold_Dumbbell_Press/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arnold_Dumbbell_Press/1.jpg'
WHERE name = 'Arnold Press' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/1.jpg'
WHERE name = 'Lateral Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Dumbbell_Raise/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Front_Dumbbell_Raise/1.jpg'
WHERE name = 'Front Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Bent-Over_Rear_Delt_Raise/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Bent-Over_Rear_Delt_Raise/1.jpg'
WHERE name = 'Rear Delt Fly' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/1.jpg'
WHERE name = 'Cable Face Pull' AND is_default = true;

-- ARMS
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/1.jpg'
WHERE name = 'Barbell Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/EZ-Bar_Curl/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/EZ-Bar_Curl/1.jpg'
WHERE name = 'EZ Bar Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Close-Grip_Barbell_Triceps_Extension_Behind_The_Head/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Close-Grip_Barbell_Triceps_Extension_Behind_The_Head/1.jpg'
WHERE name = 'Skull Crusher' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bicep_Curl/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Bicep_Curl/1.jpg'
WHERE name = 'Dumbbell Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hammer_Curls/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hammer_Curls/1.jpg'
WHERE name = 'Hammer Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Concentration_Curls/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Concentration_Curls/1.jpg'
WHERE name = 'Concentration Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Tricep_Extension_-_Seated/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Tricep_Extension_-_Seated/1.jpg'
WHERE name = 'Dumbbell Tricep Extension' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/1.jpg'
WHERE name = 'Tricep Pushdown' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Hammer_Curls_-_Rope_Attachment/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Hammer_Curls_-_Rope_Attachment/1.jpg'
WHERE name = 'Cable Curl' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Triceps_Version/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Triceps_Version/1.jpg'
WHERE name = 'Dips' AND is_default = true;

-- CORE
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/1.jpg'
WHERE name = 'Plank' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hanging_Leg_Raise/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hanging_Leg_Raise/1.jpg'
WHERE name = 'Hanging Leg Raise' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Crunches/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Crunches/1.jpg'
WHERE name = 'Crunches' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Ab_Roller/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Ab_Roller/1.jpg'
WHERE name = 'Ab Rollout' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Russian_Twist/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Russian_Twist/1.jpg'
WHERE name = 'Russian Twist' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dead_Bug/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dead_Bug/1.jpg'
WHERE name = 'Dead Bug' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Woodchoppers/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Woodchoppers/1.jpg'
WHERE name = 'Cable Woodchop' AND is_default = true;

-- BANDS
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Band_Pull_Apart/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Band_Pull_Apart/1.jpg'
WHERE name = 'Band Pull-Apart' AND is_default = true;

-- KETTLEBELL
UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/One-Arm_Kettlebell_Swings/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/One-Arm_Kettlebell_Swings/1.jpg'
WHERE name = 'Kettlebell Swing' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/1.jpg'
WHERE name = 'Kettlebell Goblet Squat' AND is_default = true;

UPDATE exercises SET
  image_start_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Turkish_Get-Up_(Kettlebell)/0.jpg',
  image_end_url   = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Turkish_Get-Up_(Kettlebell)/1.jpg'
WHERE name = 'Kettlebell Turkish Get-Up' AND is_default = true;
