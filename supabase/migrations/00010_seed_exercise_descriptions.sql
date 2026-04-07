-- =============================================================================
-- Seed descriptions and form tips for all default exercises
-- Migration: 00010_seed_exercise_descriptions
--
-- Populates the description and form_tips columns added in 00009 for every
-- default exercise inserted by seed.sql. Matched by exact name where
-- is_default = true. form_tips uses \n as the line separator; the Flutter
-- UI splits on \n to render a bulleted list.
-- =============================================================================

-- CHEST

UPDATE exercises SET
  description = 'The king of upper-body pressing. Targets the chest, front delts, and triceps with a barbell on a flat bench.',
  form_tips = 'Plant feet flat on the floor and squeeze shoulder blades together\nLower the bar to mid-chest with elbows at roughly 45 degrees\nPress up and slightly back to lockout\nKeep wrists stacked over elbows throughout'
WHERE name = 'Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell press on an incline bench (30-45 degrees) that shifts emphasis to the upper chest and front delts.',
  form_tips = 'Set the bench to 30-45 degrees for best upper chest activation\nLower the bar to the upper chest just below the collarbone\nKeep shoulder blades pinched and back arched slightly\nAvoid flaring elbows past 60 degrees'
WHERE name = 'Incline Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell press on a decline bench that emphasizes the lower chest fibers and allows heavier loads.',
  form_tips = 'Secure legs under the pads before unracking\nLower the bar to the lower chest or sternum\nKeep elbows at about 45 degrees to protect shoulders\nUse a spotter or safety pins for heavy sets'
WHERE name = 'Decline Barbell Bench Press' AND is_default = true;

UPDATE exercises SET
  description = 'A flat bench press with dumbbells that allows a greater range of motion and independent arm work.',
  form_tips = 'Start with dumbbells at chest level, palms facing forward\nPress up while bringing the dumbbells slightly together at the top\nLower under control to a deep stretch at the bottom\nKeep feet flat and back slightly arched'
WHERE name = 'Dumbbell Bench Press' AND is_default = true;

UPDATE exercises SET
  description = 'An incline dumbbell press that targets the upper chest with a full range of motion and independent arm action.',
  form_tips = 'Set bench to 30-45 degrees\nStart with dumbbells at shoulder height, palms forward\nPress up and together without clanking at the top\nLower slowly to feel the stretch in the upper chest'
WHERE name = 'Incline Dumbbell Press' AND is_default = true;

UPDATE exercises SET
  description = 'An isolation movement for the chest using dumbbells in a wide arc. Excellent for stretching the pecs under load.',
  form_tips = 'Keep a slight bend in the elbows throughout\nLower the dumbbells in a wide arc until you feel a chest stretch\nSqueeze the chest to bring the weights back together\nAvoid going too heavy — this is a stretch and squeeze movement'
WHERE name = 'Dumbbell Fly' AND is_default = true;

UPDATE exercises SET
  description = 'A cable isolation exercise that provides constant tension across the chest through a crossing motion.',
  form_tips = 'Set pulleys to shoulder height or slightly above\nStep forward into a staggered stance for stability\nBring handles together in front of the chest with a slight bend in elbows\nControl the return — do not let the cables snap back'
WHERE name = 'Cable Crossover' AND is_default = true;

UPDATE exercises SET
  description = 'A machine-based chest press that follows a fixed path, making it beginner-friendly and safe to push to failure.',
  form_tips = 'Adjust the seat so handles align with mid-chest\nPress forward without locking out the elbows\nKeep shoulder blades against the pad throughout\nControl the weight on the way back — no slamming'
WHERE name = 'Machine Chest Press' AND is_default = true;

UPDATE exercises SET
  description = 'A bodyweight pressing movement that builds chest, shoulder, and tricep strength anywhere, no equipment needed.',
  form_tips = 'Keep your body in a straight line from head to heels\nLower until chest nearly touches the ground\nKeep elbows at 45 degrees, not flared out to 90\nFully extend arms at the top without hyperextending elbows'
WHERE name = 'Push-Up' AND is_default = true;

-- BACK

UPDATE exercises SET
  description = 'A compound barbell row that builds a thick back. Targets the lats, rhomboids, and rear delts.',
  form_tips = 'Hinge at the hips to about 45 degrees with a flat back\nPull the bar to the lower chest or upper abdomen\nSqueeze shoulder blades together at the top\nLower under control — no bouncing off the bottom'
WHERE name = 'Barbell Bent-Over Row' AND is_default = true;

UPDATE exercises SET
  description = 'The ultimate full-body pull. Builds the entire posterior chain — back, glutes, hamstrings, and grip strength.',
  form_tips = 'Set up with the bar over mid-foot, hips between knees and shoulders\nKeep the bar close to your body throughout the lift\nDrive through the floor and extend hips and knees together\nLock out by squeezing glutes — do not hyperextend the lower back'
WHERE name = 'Deadlift' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell row variation using a landmine or T-bar handle that allows heavy loading with a neutral grip.',
  form_tips = 'Straddle the bar with feet shoulder-width apart\nKeep chest up and back flat throughout\nPull the weight toward your chest, squeezing at the top\nAvoid excessive body English — control the weight'
WHERE name = 'T-Bar Row' AND is_default = true;

UPDATE exercises SET
  description = 'A single-arm row with a dumbbell that builds lat thickness and helps correct side-to-side imbalances.',
  form_tips = 'Place one hand and knee on a bench for support\nPull the dumbbell toward the hip, not the shoulder\nKeep your back flat and avoid rotating the torso\nLower the weight fully to get a stretch at the bottom'
WHERE name = 'Dumbbell Row' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell exercise that targets the lats through a sweeping overhead arc while lying on a bench.',
  form_tips = 'Lie across a bench with only upper back supported\nHold one dumbbell overhead with slightly bent elbows\nLower behind head until you feel a lat stretch\nPull back to start position using the lats, not the arms'
WHERE name = 'Dumbbell Pullover' AND is_default = true;

UPDATE exercises SET
  description = 'A seated cable row that targets the mid-back with constant tension through the full range of motion.',
  form_tips = 'Sit upright with a slight forward lean at the start\nPull the handle to your lower chest, squeezing shoulder blades\nAvoid leaning too far back — the torso should stay mostly upright\nReturn the weight slowly with arms fully extended'
WHERE name = 'Cable Row' AND is_default = true;

UPDATE exercises SET
  description = 'A cable machine exercise where you pull a wide bar down to your chest. Builds lat width and is a great pull-up alternative.',
  form_tips = 'Grip the bar slightly wider than shoulder width\nLean back slightly and pull the bar to your upper chest\nDrive elbows down and back, squeezing lats at the bottom\nControl the bar up — do not let it yank your arms overhead'
WHERE name = 'Lat Pulldown' AND is_default = true;

UPDATE exercises SET
  description = 'A bodyweight vertical pull that builds lat width, grip strength, and upper-body pulling power.',
  form_tips = 'Grip the bar slightly wider than shoulder width, palms facing away\nPull up until chin clears the bar\nLower under control to a full dead hang\nAvoid excessive kipping — use strict form for back development'
WHERE name = 'Pull-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A supinated (underhand) pull-up that emphasizes the biceps alongside the lats. Easier than a pull-up for most.',
  form_tips = 'Grip the bar shoulder-width apart, palms facing you\nPull up until chin clears the bar\nLower under control to a full hang\nKeep elbows pointing forward, not flared out'
WHERE name = 'Chin-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A machine-based row that provides a fixed path and back support, making it easy to isolate the mid-back.',
  form_tips = 'Adjust the chest pad so arms can fully extend\nPull handles toward your torso, squeezing shoulder blades\nKeep chest pressed against the pad throughout\nReturn to start slowly — no slamming the weight stack'
WHERE name = 'Machine Row' AND is_default = true;

-- LEGS

UPDATE exercises SET
  description = 'The foundational lower-body exercise. Builds quads, glutes, and overall leg strength with a barbell on the back.',
  form_tips = 'Place the bar on upper traps, not on the neck\nBreak at hips and knees simultaneously to descend\nKeep knees tracking over toes — do not let them cave in\nDescend to at least parallel, then drive up through the whole foot'
WHERE name = 'Barbell Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell squat with the bar held in the front rack position. Emphasizes quads and demands strong core stability.',
  form_tips = 'Rest the bar on front delts with elbows high\nKeep torso as upright as possible throughout\nDescend to at least parallel depth\nDrive knees forward over toes — this is normal for front squats'
WHERE name = 'Front Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A hip-hinge movement that targets the hamstrings and glutes. Performed with a slight knee bend, lowering the bar along the legs.',
  form_tips = 'Keep the bar close to your legs throughout the movement\nHinge at the hips, not the lower back\nFeel the stretch in your hamstrings before reversing\nSqueeze glutes at the top to lock out'
WHERE name = 'Romanian Deadlift' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell glute exercise performed by driving the hips upward while your upper back rests on a bench.',
  form_tips = 'Position upper back on the bench with the bar over hips\nDrive through heels to lift hips until torso is parallel to the floor\nSqueeze glutes hard at the top for a one-second hold\nLower under control — do not drop at the bottom'
WHERE name = 'Hip Thrust' AND is_default = true;

UPDATE exercises SET
  description = 'A unilateral leg exercise where you step forward and lower into a lunge position while holding dumbbells.',
  form_tips = 'Take a long enough step so your front knee stays over the ankle\nLower until both knees are at roughly 90 degrees\nKeep torso upright and core braced\nPush through the front heel to return to standing'
WHERE name = 'Dumbbell Lunges' AND is_default = true;

UPDATE exercises SET
  description = 'A rear-foot-elevated split squat that crushes the quads and glutes while training single-leg stability.',
  form_tips = 'Place the rear foot laces-down on a bench behind you\nLower until the back knee nearly touches the floor\nKeep most of the weight on the front leg\nDrive up through the front heel, keeping torso upright'
WHERE name = 'Bulgarian Split Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell squat where you hold the weight at chest height. Great for learning squat mechanics and building quads.',
  form_tips = 'Hold one dumbbell vertically at chest level with both hands\nKeep elbows inside the knees at the bottom position\nSit down between your legs, not behind them\nKeep chest tall and core tight throughout'
WHERE name = 'Goblet Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A machine compound movement that allows heavy quad and glute loading without spinal compression.',
  form_tips = 'Place feet shoulder-width apart on the platform\nLower the sled until knees are at about 90 degrees\nPress through the whole foot — do not let heels lift\nDo not lock out knees completely at the top'
WHERE name = 'Leg Press' AND is_default = true;

UPDATE exercises SET
  description = 'An isolation machine exercise that targets the quadriceps through knee extension.',
  form_tips = 'Adjust the pad so it sits on the lower shin, just above the ankle\nExtend the legs fully, squeezing the quads at the top\nLower slowly — the eccentric is where growth happens\nAvoid using momentum to swing the weight up'
WHERE name = 'Leg Extension' AND is_default = true;

UPDATE exercises SET
  description = 'An isolation machine exercise that targets the hamstrings through knee flexion.',
  form_tips = 'Adjust the pad so it sits just above the heels\nCurl the weight up by squeezing the hamstrings\nHold the top position briefly for peak contraction\nLower under control — do not let the weight drop'
WHERE name = 'Leg Curl' AND is_default = true;

UPDATE exercises SET
  description = 'An isolation exercise that targets the calves (gastrocnemius and soleus) through ankle plantarflexion.',
  form_tips = 'Start with a full stretch at the bottom — heels below the platform\nPush up onto the balls of your feet as high as possible\nHold the top contraction for one second\nUse a slow, controlled tempo — no bouncing'
WHERE name = 'Calf Raise' AND is_default = true;

-- SHOULDERS

UPDATE exercises SET
  description = 'The primary barbell shoulder press. Builds front and side delt mass along with tricep and upper chest involvement.',
  form_tips = 'Grip the bar just outside shoulder width\nPress straight up, moving your head back slightly to clear the bar path\nLock out overhead with the bar directly over mid-foot\nKeep core braced — do not lean back excessively'
WHERE name = 'Overhead Press' AND is_default = true;

UPDATE exercises SET
  description = 'An overhead press variation that uses leg drive to move heavier loads, building strength and power.',
  form_tips = 'Start with the bar in the front rack position\nDip by bending knees slightly, then explode upward\nUse the momentum to press the bar overhead to lockout\nLower the bar under control back to the front rack'
WHERE name = 'Push Press' AND is_default = true;

UPDATE exercises SET
  description = 'A seated or standing dumbbell press that allows a natural arc of motion and independent arm work for the shoulders.',
  form_tips = 'Start with dumbbells at shoulder height, palms facing forward\nPress up and slightly inward without clanking at the top\nLower to ear level or slightly below\nKeep core tight to avoid arching the lower back'
WHERE name = 'Dumbbell Shoulder Press' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell press that starts with palms facing you and rotates to palms forward, hitting all three delt heads.',
  form_tips = 'Start with dumbbells at chin height, palms facing you\nRotate palms forward as you press up\nReverse the rotation on the way down\nUse a smooth, controlled motion — do not rush the rotation'
WHERE name = 'Arnold Press' AND is_default = true;

UPDATE exercises SET
  description = 'The go-to isolation exercise for building wider shoulders. Targets the lateral (side) deltoid head.',
  form_tips = 'Stand with a slight forward lean at the hips\nRaise dumbbells out to the sides until arms are parallel to the floor\nLead with the elbows, not the hands\nLower slowly — do not just drop the weight'
WHERE name = 'Lateral Raise' AND is_default = true;

UPDATE exercises SET
  description = 'An isolation exercise for the front deltoid. Useful for additional front delt volume when pressing alone is not enough.',
  form_tips = 'Stand upright holding dumbbells in front of your thighs\nRaise one or both arms to shoulder height with a slight elbow bend\nLower under control — do not swing\nAlternate arms or raise both simultaneously'
WHERE name = 'Front Raise' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell isolation movement for the rear delts. Essential for balanced shoulder development and posture.',
  form_tips = 'Bend forward at the hips so your torso is nearly parallel to the floor\nRaise dumbbells out to the sides, leading with the elbows\nSqueeze shoulder blades together at the top\nUse light weight with strict form — rear delts are small muscles'
WHERE name = 'Rear Delt Fly' AND is_default = true;

UPDATE exercises SET
  description = 'A cable exercise that targets the rear delts and external rotators. Excellent for shoulder health and posture.',
  form_tips = 'Set the cable to face height with a rope attachment\nPull the rope toward your face, flaring elbows high and wide\nExternally rotate at the end so fists point to the ceiling\nSqueeze rear delts and hold briefly before returning'
WHERE name = 'Cable Face Pull' AND is_default = true;

-- ARMS

UPDATE exercises SET
  description = 'The classic bicep builder. A barbell curl that targets both heads of the biceps with heavy loads.',
  form_tips = 'Stand with feet shoulder-width apart, grip the bar at shoulder width\nCurl the bar up by flexing the elbows — do not swing the body\nSqueeze the biceps at the top\nLower under control to full arm extension'
WHERE name = 'Barbell Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell curl using an EZ (cambered) bar that reduces wrist strain and targets the biceps effectively.',
  form_tips = 'Grip the angled portions of the bar for a natural wrist position\nKeep elbows pinned at your sides throughout\nCurl up to full contraction, then lower slowly\nAvoid leaning back or using momentum'
WHERE name = 'EZ Bar Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A tricep isolation exercise performed lying on a bench, lowering the bar toward the forehead and pressing back up.',
  form_tips = 'Lie flat with arms extended, holding the bar above your chest\nLower the bar toward your forehead by bending only at the elbows\nKeep upper arms perpendicular to the floor\nExtend back to lockout, squeezing triceps at the top'
WHERE name = 'Skull Crusher' AND is_default = true;

UPDATE exercises SET
  description = 'A classic isolation curl with dumbbells that allows full supination for peak bicep contraction.',
  form_tips = 'Start with arms at your sides, palms facing forward\nCurl both dumbbells up while keeping elbows stationary\nSupinate (rotate palms up) as you curl for peak contraction\nLower under control to full extension'
WHERE name = 'Dumbbell Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A neutral-grip dumbbell curl that targets the brachialis and brachioradialis for thicker arms.',
  form_tips = 'Hold dumbbells with palms facing each other (neutral grip)\nCurl up without rotating the wrists\nKeep elbows close to your sides\nLower slowly — the brachialis responds well to slow eccentrics'
WHERE name = 'Hammer Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A seated single-arm curl that isolates the bicep by bracing the elbow against the inner thigh.',
  form_tips = 'Sit on a bench with the elbow braced against the inner thigh\nCurl the dumbbell up, squeezing the bicep at the top\nLower slowly to a near-full extension\nDo not lean back or use the shoulder to lift'
WHERE name = 'Concentration Curl' AND is_default = true;

UPDATE exercises SET
  description = 'An overhead tricep extension with a dumbbell that targets the long head of the triceps with a full stretch.',
  form_tips = 'Hold one dumbbell overhead with both hands under the top plate\nLower behind the head by bending at the elbows\nKeep upper arms close to the ears and stationary\nExtend back to lockout, squeezing triceps at the top'
WHERE name = 'Dumbbell Tricep Extension' AND is_default = true;

UPDATE exercises SET
  description = 'A cable isolation exercise for the triceps. Push the handle down using elbow extension for constant tension.',
  form_tips = 'Stand upright with elbows pinned at your sides\nPush the handle down until arms are fully extended\nSqueeze the triceps at the bottom\nReturn slowly — do not let the weight stack slam'
WHERE name = 'Tricep Pushdown' AND is_default = true;

UPDATE exercises SET
  description = 'A cable curl that provides constant tension throughout the range of motion for bicep isolation.',
  form_tips = 'Stand facing the low pulley with a straight or EZ bar attachment\nCurl up by flexing the elbows, keeping upper arms stationary\nSqueeze at the top and lower under control\nDo not lean back — keep your torso upright'
WHERE name = 'Cable Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A bodyweight exercise that targets the triceps, lower chest, and front delts. Can be loaded with a belt for progression.',
  form_tips = 'Grip the bars and support your weight with arms locked out\nLean slightly forward to emphasize chest, stay upright for triceps\nLower until upper arms are parallel to the floor\nPress back up to lockout without swinging'
WHERE name = 'Dips' AND is_default = true;

-- CORE

UPDATE exercises SET
  description = 'An isometric core exercise that builds endurance in the abs, obliques, and deep stabilizers.',
  form_tips = 'Support your body on forearms and toes in a straight line\nSqueeze glutes and brace abs as if expecting a punch\nDo not let hips sag or pike up\nBreathe steadily — do not hold your breath'
WHERE name = 'Plank' AND is_default = true;

UPDATE exercises SET
  description = 'An advanced core exercise that targets the lower abs by raising the legs while hanging from a bar.',
  form_tips = 'Hang from a pull-up bar with a shoulder-width grip\nRaise legs by curling the pelvis up, not just lifting knees\nControl the descent — do not swing\nAvoid excessive momentum; pause briefly at the bottom'
WHERE name = 'Hanging Leg Raise' AND is_default = true;

UPDATE exercises SET
  description = 'A classic abdominal exercise that targets the upper abs through spinal flexion.',
  form_tips = 'Lie on your back with knees bent and feet flat\nPlace hands behind the head — do not pull on the neck\nCurl the upper back off the floor by contracting the abs\nLower slowly and repeat without resting the shoulders fully'
WHERE name = 'Crunches' AND is_default = true;

UPDATE exercises SET
  description = 'An anti-extension core exercise using a wheel or barbell that builds serious ab strength and stability.',
  form_tips = 'Kneel on a pad and grip the wheel or barbell\nRoll forward by extending the hips and keeping arms straight\nGo only as far as you can control without lower back sagging\nPull back to start by squeezing the abs, not the hip flexors'
WHERE name = 'Ab Rollout' AND is_default = true;

UPDATE exercises SET
  description = 'A rotational core exercise that targets the obliques. Performed seated with a twist while holding a weight.',
  form_tips = 'Sit with knees bent and lean back slightly\nHold a weight at chest level and rotate side to side\nMove from the torso, not just the arms\nKeep feet elevated for a harder variation, or grounded for easier'
WHERE name = 'Russian Twist' AND is_default = true;

UPDATE exercises SET
  description = 'An anti-extension core exercise performed lying face-up. Trains the abs to resist lumbar extension under load.',
  form_tips = 'Lie on your back with arms and legs extended toward the ceiling\nSlowly lower opposite arm and leg toward the floor\nKeep the lower back pressed flat into the ground\nReturn to start and alternate sides with control'
WHERE name = 'Dead Bug' AND is_default = true;

UPDATE exercises SET
  description = 'A cable rotation exercise that targets the obliques and builds rotational core strength.',
  form_tips = 'Set the cable to shoulder height and stand sideways\nPull the handle across your body in a diagonal chopping motion\nRotate through the torso, keeping arms relatively straight\nControl the return — do not let the cable snap back'
WHERE name = 'Cable Woodchop' AND is_default = true;

-- BANDS

UPDATE exercises SET
  description = 'A band exercise that targets the rear delts and mid-traps. Great for warm-ups and shoulder health.',
  form_tips = 'Hold the band at chest height with arms extended in front\nPull the band apart by squeezing the shoulder blades together\nKeep arms straight or with a very slight bend\nReturn slowly — do not let the band snap back'
WHERE name = 'Band Pull-Apart' AND is_default = true;

UPDATE exercises SET
  description = 'A band version of the face pull that targets the rear delts and external rotators for shoulder prehab.',
  form_tips = 'Anchor the band at face height\nPull toward your face, flaring elbows high and wide\nExternally rotate at the end position\nControl the return with a slow tempo'
WHERE name = 'Band Face Pull' AND is_default = true;

UPDATE exercises SET
  description = 'A squat performed with a resistance band looped around the thighs or under the feet for added tension.',
  form_tips = 'Stand on the band with feet shoulder-width apart\nHold the band at shoulder height or loop around the thighs\nSquat to at least parallel, pressing knees out against the band\nStand up by driving through the heels'
WHERE name = 'Band Squat' AND is_default = true;

-- KETTLEBELL

UPDATE exercises SET
  description = 'A ballistic hip-hinge exercise that builds explosive power in the glutes, hamstrings, and core.',
  form_tips = 'Hinge at the hips to swing the kettlebell between your legs\nSnap the hips forward to drive the bell to chest height\nKeep arms relaxed — the power comes from the hips, not the shoulders\nBrace your core at the top of each swing'
WHERE name = 'Kettlebell Swing' AND is_default = true;

UPDATE exercises SET
  description = 'A squat variation holding a kettlebell at chest height. Excellent for building squat depth and quad strength.',
  form_tips = 'Hold the kettlebell by the horns at chest level\nSit down between your legs, keeping elbows inside the knees\nDescend to full depth while keeping the torso upright\nDrive up through the heels, squeezing glutes at the top'
WHERE name = 'Kettlebell Goblet Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A complex full-body kettlebell movement that develops total-body strength, coordination, and stability.',
  form_tips = 'Start lying on your back with the kettlebell pressed overhead\nKeep eyes on the kettlebell throughout the entire movement\nRise to standing through a series of controlled transitions\nReverse the steps to return to the starting position'
WHERE name = 'Kettlebell Turkish Get-Up' AND is_default = true;
