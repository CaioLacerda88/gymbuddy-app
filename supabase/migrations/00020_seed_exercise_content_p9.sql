-- =============================================================================
-- Seed descriptions and form_tips for P9 content-standard exercises
-- Migration: 00020_seed_exercise_content_p9
--
-- Populates description and form_tips for two groups of default exercises:
--   1. The 31 rows inserted by 00014 (including 5 cardio machines) that
--      shipped without content.
--   2. The 58 rows inserted by the companion migration 00019.
--
-- Voice matches 00010 (same 15-25 word imperative-capable description + 4
-- declarative form tip bullets, \n-separated). No medical vocabulary, no
-- tempo cues, no rep ranges. The "Upright Row" row carries the one
-- documented-injury-mechanism caveat in the library.
--
-- All UPDATEs are idempotent (repeating them just rewrites identical text).
-- =============================================================================

-- =========================
-- Backfills from 00014 (31)
-- =========================

-- CHEST (3)

UPDATE exercises SET
  description = 'A machine chest fly with pads that trace an arc, isolating the pecs without shoulder stabilizer demand.',
  form_tips = 'Adjust the seat so handles sit at chest height\nSqueeze the pecs to bring the pads together in front\nKeep shoulder blades flat against the back pad\nControl the return so the stack does not snap back'
WHERE name = 'Pec Deck' AND is_default = true;

UPDATE exercises SET
  description = 'A standing or kneeling cable press that drives the chest through horizontal adduction with constant tension.',
  form_tips = 'Set the pulleys to chest height with handles or a bar\nStep into a staggered stance for a stable base\nPress the handles forward and together in one smooth arc\nResist the cables on the way back for a deep pec stretch'
WHERE name = 'Cable Chest Press' AND is_default = true;

UPDATE exercises SET
  description = 'A push-up performed with hands well outside shoulder width that biases load toward the outer chest.',
  form_tips = 'Place hands wider than shoulder width with fingers forward\nKeep your body in one straight line from head to heels\nLower until the chest hovers just above the floor\nPress away without letting the hips sag or pike up'
WHERE name = 'Wide Push-Up' AND is_default = true;

-- BACK (4)

UPDATE exercises SET
  description = 'A cable exercise for the rear delts and mid-traps that reinforces healthy scapular mechanics and posture.',
  form_tips = 'Set a rope attachment at roughly face height\nPull the rope toward your forehead with elbows high\nExternally rotate so your knuckles point behind you\nReturn the handle under control without dropping the tension'
WHERE name = 'Face Pull' AND is_default = true;

UPDATE exercises SET
  description = 'A partial deadlift from pins set near knee height that overloads the lockout and builds upper-back thickness.',
  form_tips = 'Set the pins just below or at knee height in the rack\nBrace your core hard before pulling any weight\nDrive hips through to lock out with glutes, not the low back\nLower with control — do not crash the bar back onto the pins'
WHERE name = 'Rack Pull' AND is_default = true;

UPDATE exercises SET
  description = 'A hip-hinge with the bar across the upper back that trains hamstrings, glutes, and spinal erectors.',
  form_tips = 'Rack the bar on the upper traps as with a low-bar squat\nPush the hips back while keeping a soft bend in the knees\nStop when your torso is roughly parallel to the floor\nDrive hips forward to stand tall, squeezing the glutes'
WHERE name = 'Good Morning' AND is_default = true;

UPDATE exercises SET
  description = 'A strict barbell row that starts each rep from the floor, eliminating cheat and reinforcing explosive back pull.',
  form_tips = 'Set up with the bar over mid-foot and torso nearly parallel\nPull the bar to the lower chest in one explosive motion\nLet the bar settle on the floor between every rep\nKeep the spine neutral — no rounding at the bottom'
WHERE name = 'Pendlay Row' AND is_default = true;

-- LEGS (7)

UPDATE exercises SET
  description = 'A machine squat with the torso supported on an angled back pad, letting you push quads hard with no spinal load.',
  form_tips = 'Set shoulder pads so your hips sit deep in the seat\nPlace feet shoulder-width on the platform, toes slightly out\nDescend until your thighs break parallel to the pad\nDrive up through the whole foot to near lockout'
WHERE name = 'Hack Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A wide-stance deadlift variant with hands inside the knees that shortens the pull and loads the inner thighs.',
  form_tips = 'Take a stance roughly twice shoulder-width with toes flared\nGrip the bar inside the knees with straight arms\nChest up, hips down — push the floor away as you stand\nLock out by squeezing glutes without leaning back'
WHERE name = 'Sumo Deadlift' AND is_default = true;

UPDATE exercises SET
  description = 'A lunge pattern where each step advances forward, training single-leg strength and loaded balance.',
  form_tips = 'Hold a dumbbell in each hand at your sides\nStep far enough that the front knee stacks over the ankle\nLower until the back knee almost grazes the floor\nDrive through the front heel to step into the next rep'
WHERE name = 'Walking Lunges' AND is_default = true;

UPDATE exercises SET
  description = 'A single-leg exercise where you step onto an elevated box or bench, building quad and glute strength unilaterally.',
  form_tips = 'Use a box height that gives you a 90-degree knee on top\nHold a dumbbell in each hand at your sides\nPlant the full foot on the box and stand up tall\nStep down under control, leading with the same leg every rep'
WHERE name = 'Step-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A seated calf-raise machine that isolates the soleus by flexing the knee out of the movement.',
  form_tips = 'Set the thigh pad snug just above the knees\nPosition the balls of the feet on the foot plate\nLower the heels as far as the machine allows for a full stretch\nPush up high and squeeze briefly before the next rep'
WHERE name = 'Seated Calf Raise' AND is_default = true;

UPDATE exercises SET
  description = 'A machine exercise that targets the outer glutes and hip abductors by pressing the thighs apart against pads.',
  form_tips = 'Sit tall with the lower back pressed into the pad\nPlace the outer thighs against the pads\nPush the pads outward in a steady arc — do not swing\nReturn slowly to feel the abductors lengthen under load'
WHERE name = 'Leg Abductor' AND is_default = true;

UPDATE exercises SET
  description = 'A machine exercise that trains the inner-thigh adductors by squeezing the pads together from a seated position.',
  form_tips = 'Set the pads so you start with a comfortable stretch\nSit upright with the lower back against the pad\nSqueeze the pads together under control\nRelease slowly — do not let the weight stack pull the legs apart'
WHERE name = 'Leg Adductor' AND is_default = true;

-- SHOULDERS (3)
-- Upright Row keeps the single documented-injury-mechanism caveat.

UPDATE exercises SET
  description = 'A vertical barbell pull along the torso that hits the side delts and upper traps through a short range.',
  form_tips = 'Grip the bar at shoulder width with an overhand grip\nPull the bar straight up, leading with the elbows\nStop when elbows reach shoulder height — pulling higher risks shoulder impingement\nLower the bar under control back to the thighs'
WHERE name = 'Upright Row' AND is_default = true;

UPDATE exercises SET
  description = 'A plate-loaded or selectorized shoulder press that locks you into a fixed path for safe heavy pressing.',
  form_tips = 'Adjust the seat so the handles align with your shoulders\nGrip the handles and press overhead without locking out hard\nKeep shoulder blades tucked against the back pad\nLower the handles until they sit at the top of the shoulders'
WHERE name = 'Machine Shoulder Press' AND is_default = true;

UPDATE exercises SET
  description = 'A cable lateral raise that keeps constant tension on the side delt through the full range of motion.',
  form_tips = 'Stand side-on to a low pulley holding the handle in one hand\nRaise the arm out to the side up to shoulder height\nLead with the elbow, keeping a soft bend throughout\nLower under control — resist the cable on the way down'
WHERE name = 'Cable Lateral Raise' AND is_default = true;

-- ARMS (5)

UPDATE exercises SET
  description = 'A barbell curl performed on a preacher bench that pins the upper arms and isolates the biceps.',
  form_tips = 'Set the bench so your armpits rest at the top of the pad\nGrip the bar at shoulder width, palms facing up\nCurl the bar under control — no shoulder swing\nLower slowly until arms are nearly straight, then reverse'
WHERE name = 'Preacher Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell curl performed lying back on an incline bench, placing the biceps in a long stretched position.',
  form_tips = 'Set the bench to roughly 45-60 degrees and lie back\nLet the arms hang straight down with palms forward\nCurl both dumbbells up while keeping elbows back\nLower until arms are fully extended for the stretch'
WHERE name = 'Incline Dumbbell Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A narrow-grip barbell bench press that shifts the work onto the triceps while still loading chest and front delts.',
  form_tips = 'Grip the bar roughly shoulder-width apart, not narrower\nTuck elbows close to the ribs as you lower the bar\nLower the bar to the lower chest and press to lockout\nKeep wrists stacked over the elbows throughout'
WHERE name = 'Close-Grip Bench Press' AND is_default = true;

UPDATE exercises SET
  description = 'A cable tricep extension performed overhead with a rope that emphasizes the long head through a deep stretch.',
  form_tips = 'Face away from the stack with the rope held overhead\nKeep the elbows pointing forward and close to the ears\nExtend the arms fully by straightening only at the elbows\nLower behind the head until you feel the tricep stretch'
WHERE name = 'Overhead Tricep Extension' AND is_default = true;

UPDATE exercises SET
  description = 'A cable pushdown using a rope that lets you separate the ends at the bottom for a harder tricep contraction.',
  form_tips = 'Grip the rope with thumbs on top, elbows pinned at your sides\nPush down until the rope ends split past your thighs\nSqueeze the triceps briefly at full extension\nReturn the rope to the start under control — no bouncing'
WHERE name = 'Rope Pushdown' AND is_default = true;

-- CORE (4)

UPDATE exercises SET
  description = 'A crunching variation that adds a twist so each rep trains both the upper abs and the obliques.',
  form_tips = 'Lie on your back with hands lightly behind the ears\nBring one knee in while rotating the opposite elbow toward it\nAlternate sides in a steady rhythm without yanking the neck\nKeep the lower back pressed into the floor throughout'
WHERE name = 'Bicycle Crunch' AND is_default = true;

UPDATE exercises SET
  description = 'A kneeling cable crunch that loads the abs heavy by flexing the spine under a rope attachment.',
  form_tips = 'Kneel facing the stack with a rope held near the forehead\nRound the spine down by pulling the elbows toward the hips\nKeep the hips stationary — the movement is at the spine, not the hip\nReverse slowly until the abs lengthen again'
WHERE name = 'Cable Crunch' AND is_default = true;

UPDATE exercises SET
  description = 'An anti-rotation cable exercise where you resist twisting forces, building deep core stability.',
  form_tips = 'Stand side-on to a cable set at chest height\nPress the handle straight out in front of the sternum\nResist the pull of the cable — do not let your torso rotate\nHold for a breath, then return and repeat'
WHERE name = 'Pallof Press' AND is_default = true;

UPDATE exercises SET
  description = 'A forearm plank held on one side that trains the obliques and lateral core stabilizers isometrically.',
  form_tips = 'Prop on one forearm with elbow directly under the shoulder\nStack the feet and lift the hips into one straight line\nSqueeze the glutes and obliques to hold the line steady\nSwitch sides after the set for balanced work'
WHERE name = 'Side Plank' AND is_default = true;

-- CARDIO (5)

UPDATE exercises SET
  description = 'A steady or interval run on a motorized belt that builds aerobic base and conditioning.',
  form_tips = 'Step on with the belt stopped, then start at a walking pace\nLook forward, not down at your feet, for a natural stride\nLand mid-foot under the hips, not out in front\nUse the emergency clip so the belt stops if you slip'
WHERE name = 'Treadmill' AND is_default = true;

UPDATE exercises SET
  description = 'A seated rowing ergometer that trains the full posterior chain and drives hard cardiovascular conditioning.',
  form_tips = 'Strap in the feet and grip the handle with both hands\nDrive with the legs first, then lean back, then pull with the arms\nReverse the sequence on the return: arms, torso, then legs\nKeep the back flat — no rounding as you reach forward'
WHERE name = 'Rowing Machine' AND is_default = true;

UPDATE exercises SET
  description = 'A seated or upright stationary bike that delivers low-impact cardio with easy resistance control.',
  form_tips = 'Adjust the seat so the knee is slightly bent at the pedal bottom\nKeep hands relaxed on the bars — do not hunch the shoulders\nPedal in smooth circles rather than stomping down\nDial resistance up for hills or intervals as needed'
WHERE name = 'Stationary Bike' AND is_default = true;

UPDATE exercises SET
  description = 'A skipping-rope drill that builds calf endurance, footwork, and raises heart rate fast in small spaces.',
  form_tips = 'Size the rope so the handles reach your armpits when you stand on it\nKeep the elbows pinned to your sides and spin from the wrists\nBounce only a couple of inches off the floor on each pass\nStay on the balls of the feet — heels never touch down'
WHERE name = 'Jump Rope' AND is_default = true;

UPDATE exercises SET
  description = 'A standing machine that moves the feet through an elliptical path, giving full-body low-impact cardio.',
  form_tips = 'Step on with both feet planted and grip the moving handles\nDrive with the legs and pull-push with the arms together\nKeep the torso upright — do not slump over the console\nReverse direction occasionally to work opposing muscle groups'
WHERE name = 'Elliptical' AND is_default = true;

-- =========================
-- New from 00019 (58)
-- =========================

-- CHEST (6)

UPDATE exercises SET
  description = 'A dumbbell fly performed on an incline bench that emphasizes the upper-chest fibers through a wide arc.',
  form_tips = 'Set the bench to 30-45 degrees and lie back\nStart with dumbbells pressed overhead, palms facing each other\nLower in a wide arc with a soft bend in the elbows\nSqueeze the upper chest to bring the weights back together'
WHERE name = 'Incline Dumbbell Fly' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell press on a decline bench that biases load toward the lower-chest fibers.',
  form_tips = 'Secure the feet under the pads before unracking the dumbbells\nStart with the weights at lower-chest level, palms forward\nPress up and slightly together without clanking at the top\nLower under control to a deep stretch at the bottom'
WHERE name = 'Decline Dumbbell Press' AND is_default = true;

UPDATE exercises SET
  description = 'A single-arm press with the barbell anchored in a landmine, giving a safe arcing press for chest and front delts.',
  form_tips = 'Stand in a staggered stance with the bar end at one shoulder\nPress the bar up and slightly across the body\nKeep the core braced — do not let the torso twist\nLower the bar under control back to the shoulder'
WHERE name = 'Landmine Press' AND is_default = true;

UPDATE exercises SET
  description = 'A push-up with hands close together forming a diamond shape, shifting work onto the triceps and inner chest.',
  form_tips = 'Place hands under the chest so thumbs and index fingers touch\nKeep elbows tucked close to the ribs on the descent\nLower until the chest nearly touches the hands\nPress back up without letting the hips sag or pike'
WHERE name = 'Diamond Push-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A push-up with the hands elevated on a bench or box, an accessible progression toward the standard push-up.',
  form_tips = 'Place hands on a sturdy bench, fingers pointing forward\nWalk the feet back so the body forms one straight line\nLower the chest to the bench edge with elbows at 45 degrees\nPress away fully without locking the elbows hard'
WHERE name = 'Incline Push-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A push-up with the feet elevated on a bench, shifting emphasis to the upper chest and front delts.',
  form_tips = 'Place feet on a sturdy bench and hands on the floor\nKeep the body in a straight line from head to heels\nLower until the chest nearly touches the floor\nPress back up without letting the hips drop or pike'
WHERE name = 'Decline Push-Up' AND is_default = true;

-- BACK (9)

UPDATE exercises SET
  description = 'A bodyweight hip extension performed face-down on a 45-degree bench that trains the glutes and spinal erectors.',
  form_tips = 'Set the pad so hips sit right at the edge and can fold freely\nCross the arms on the chest and hinge down at the hips\nRaise the torso until it lines up with the legs\nAvoid hyperextending — stop at a straight line'
WHERE name = 'Hyperextension' AND is_default = true;

UPDATE exercises SET
  description = 'A loaded back extension on a machine or bench that lets you progressively overload the posterior chain.',
  form_tips = 'Hold a plate against the chest for added resistance\nHinge down at the hips with a long, flat spine\nRaise the torso until it is in line with the legs\nSqueeze the glutes at the top — do not overextend'
WHERE name = 'Back Extension' AND is_default = true;

UPDATE exercises SET
  description = 'A horizontal bodyweight row under a fixed bar that builds the mid-back with scalable difficulty.',
  form_tips = 'Set a bar at roughly hip height in a rack or on rings\nHang underneath with the body in a straight plank line\nPull the chest toward the bar by driving the elbows back\nLower slowly under full control — no hip swinging'
WHERE name = 'Inverted Row' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell row with the chest braced on an incline bench that removes cheat momentum and isolates the lats.',
  form_tips = 'Lie face-down on an incline bench with a dumbbell in each hand\nLet the arms hang straight down to start\nRow both dumbbells up by driving the elbows toward the hips\nSqueeze the shoulder blades at the top before lowering'
WHERE name = 'Chest-Supported Row' AND is_default = true;

UPDATE exercises SET
  description = 'A barbell row performed prone on a raised bench so the bar hangs free, enforcing strict pull mechanics.',
  form_tips = 'Lie face-down on a bench elevated enough to clear the bar\nHang the barbell at arms length with a shoulder-width grip\nRow the bar up to the chest by squeezing shoulder blades\nLower under full control — no dropping or dead-stopping'
WHERE name = 'Seal Row' AND is_default = true;

UPDATE exercises SET
  description = 'A cable lat isolation performed with straight arms, driving the shoulder through adduction for pure lat work.',
  form_tips = 'Stand facing a high pulley with a straight bar attachment\nHinge slightly at the hips with arms extended forward\nPull the bar down to the thighs in a sweeping arc\nKeep elbows locked straight — movement is at the shoulder'
WHERE name = 'Straight-Arm Pulldown' AND is_default = true;

UPDATE exercises SET
  description = 'A lat pulldown taken with a narrow grip that lengthens the lats and biases the lower-lat fibers.',
  form_tips = 'Use a narrow neutral or supinated grip on the bar\nSit tall with a slight backward lean at the start\nPull the bar to the upper chest, driving elbows down and back\nReturn the bar overhead slowly under full control'
WHERE name = 'Close-Grip Lat Pulldown' AND is_default = true;

UPDATE exercises SET
  description = 'A pull-up performed with hands set wide on the bar, biasing upper-lat engagement and overall back width.',
  form_tips = 'Grip the bar well wider than shoulder width, palms forward\nPull up by driving the elbows down and back\nClear the chin past the bar at the top of each rep\nLower under control to a full dead hang before the next rep'
WHERE name = 'Wide-Grip Pull-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A single-arm kettlebell row that trains the lat and mid-back unilaterally and challenges anti-rotation.',
  form_tips = 'Hinge at the hips with one hand braced on a bench or rack\nHold the kettlebell at arms length with a neutral grip\nRow the bell toward the hip, elbow tracking close to the ribs\nLower under control without rotating the torso'
WHERE name = 'Kettlebell Row' AND is_default = true;

-- LEGS (14)

UPDATE exercises SET
  description = 'A bodyweight hip lift that strengthens the glutes and hamstrings, a cornerstone warm-up or beginner exercise.',
  form_tips = 'Lie on your back with knees bent and feet flat on the floor\nDrive through the heels to lift the hips up\nSqueeze the glutes at the top with ribs pulled down\nLower the hips slowly — do not drop them'
WHERE name = 'Glute Bridge' AND is_default = true;

UPDATE exercises SET
  description = 'A glute bridge performed on one leg at a time, exposing side-to-side imbalances and loading each glute hard.',
  form_tips = 'Lie on your back with one knee bent, the other leg straight out\nDrive through the planted heel to lift the hips\nKeep the hips level — do not let one side sag\nLower slowly and repeat before switching sides'
WHERE name = 'Single-Leg Glute Bridge' AND is_default = true;

UPDATE exercises SET
  description = 'A lower-body power jump onto a raised box that develops explosive leg drive and coordination.',
  form_tips = 'Stand roughly a foot from a sturdy box at a reachable height\nLoad a quick countermovement dip with the arms pulled back\nSwing the arms and jump onto the box, landing soft on both feet\nStep back down — do not reverse-jump off the box'
WHERE name = 'Box Jump' AND is_default = true;

UPDATE exercises SET
  description = 'A knee-dominant hamstring exercise where you lower a straightened body with the feet anchored.',
  form_tips = 'Kneel on a pad with the ankles locked under a secure anchor\nKeep the body in a straight line from knees to shoulders\nLower forward as slowly as possible using the hamstrings\nCatch yourself with the hands if needed, then push back up'
WHERE name = 'Nordic Curl' AND is_default = true;

UPDATE exercises SET
  description = 'An isometric squat hold against a wall that builds quad endurance with no equipment.',
  form_tips = 'Lean back against a flat wall with feet a stride forward\nSlide down until knees and hips are at 90 degrees\nKeep the back and head pressed flat to the wall\nHold for time — breathe steadily and do not slump'
WHERE name = 'Wall Sit' AND is_default = true;

UPDATE exercises SET
  description = 'A bodyweight glute drill performed on hands and knees, kicking one foot up to isolate glute contraction.',
  form_tips = 'Start on all fours with hands under shoulders and knees under hips\nKeep the working knee bent at 90 degrees\nDrive the foot toward the ceiling by squeezing the glute\nLower with control — do not arch the lower back'
WHERE name = 'Donkey Kick' AND is_default = true;

UPDATE exercises SET
  description = 'A fundamental bodyweight squat that builds mobility, pattern, and quad-glute endurance with no load.',
  form_tips = 'Stand with feet shoulder-width and toes slightly flared\nSit down and back as if reaching for a low chair\nDescend to at least parallel while keeping chest tall\nDrive through the full foot to stand all the way up'
WHERE name = 'Bodyweight Squat' AND is_default = true;

UPDATE exercises SET
  description = 'A lunge pattern where each step goes backward, easing load on the front knee and emphasizing glute work.',
  form_tips = 'Hold a dumbbell in each hand at your sides\nStep one foot back into a long lunge stance\nLower until the back knee almost touches the floor\nDrive through the front heel to return to standing'
WHERE name = 'Reverse Lunges' AND is_default = true;

UPDATE exercises SET
  description = 'A calf raise loaded with dumbbells held at the sides, isolating the gastrocnemius through plantarflexion.',
  form_tips = 'Stand with the balls of the feet on a low plate or step\nHold a dumbbell in each hand at the sides\nPush up onto the toes as high as you can\nLower the heels below the step to stretch the calves'
WHERE name = 'Dumbbell Calf Raise' AND is_default = true;

UPDATE exercises SET
  description = 'A leg press performed one leg at a time, building unilateral quad strength and exposing side-to-side gaps.',
  form_tips = 'Set a moderate weight and place one foot centered on the platform\nLower the sled until the working knee is at roughly 90 degrees\nPress through the whole foot back to near lockout\nFinish all reps on one leg before switching sides'
WHERE name = 'Single-Leg Leg Press' AND is_default = true;

UPDATE exercises SET
  description = 'A machine exercise that loads the glutes and hamstrings via hip extension, with no spinal compression.',
  form_tips = 'Set up face-down on the pad with hips at the machine edge\nGrip the handles and let the legs hang down to start\nDrive the legs back and up until level with the torso\nLower the legs slowly — do not let them swing'
WHERE name = 'Reverse Hyperextension' AND is_default = true;

UPDATE exercises SET
  description = 'A standing cable exercise that isolates the glute by kicking one leg straight back against resistance.',
  form_tips = 'Attach an ankle strap to a low pulley and the working leg\nFace the stack and brace on the frame with both hands\nDrive the leg back by squeezing the glute\nReturn under control without rotating the hips'
WHERE name = 'Cable Glute Kickback' AND is_default = true;

UPDATE exercises SET
  description = 'A hip-hinge between the legs with a low cable rope that loads the glutes and hamstrings like a kettlebell swing.',
  form_tips = 'Face away from a low pulley with the rope between the legs\nHinge back at the hips with a soft knee bend\nSnap the hips forward to stand tall, squeezing the glutes\nLet the rope pull you back into the hinge for the next rep'
WHERE name = 'Cable Pull-Through' AND is_default = true;

UPDATE exercises SET
  description = 'A hip-hinge deadlift with a kettlebell held between the legs, ideal for learning the pattern at scalable loads.',
  form_tips = 'Straddle the kettlebell with feet shoulder-width apart\nHinge at the hips and grip the handle with both hands\nDrive through the floor to stand tall with the bell\nLower by pushing hips back — do not round the lower back'
WHERE name = 'Kettlebell Deadlift' AND is_default = true;

-- SHOULDERS (7)

UPDATE exercises SET
  description = 'A barbell shrug that loads the upper traps through simple shoulder elevation for a dense neck-trap tie-in.',
  form_tips = 'Hold the bar in front of the thighs with a shoulder-width grip\nShrug the shoulders straight up toward the ears\nHold the top briefly to feel the traps squeeze\nLower under control — do not let the bar drop'
WHERE name = 'Barbell Shrug' AND is_default = true;

UPDATE exercises SET
  description = 'A shrug performed with dumbbells at the sides, allowing a longer stretch than the barbell version.',
  form_tips = 'Hold a dumbbell in each hand at your sides\nShrug the shoulders straight up as high as possible\nKeep the arms relaxed — do not bend the elbows\nLower slowly to a full stretch before the next rep'
WHERE name = 'Dumbbell Shrug' AND is_default = true;

UPDATE exercises SET
  description = 'A cable rear delt fly that keeps constant tension on the rear delts through the arc.',
  form_tips = 'Set two pulleys to shoulder height and cross the cables\nGrip the opposite handle in each hand at centerline\nPull the arms apart in a wide arc to chest height\nSqueeze the rear delts briefly before the slow return'
WHERE name = 'Cable Rear Delt Fly' AND is_default = true;

UPDATE exercises SET
  description = 'A cable front raise that isolates the front deltoid with constant tension through the full arc.',
  form_tips = 'Stand facing away from a low pulley holding the handle\nRaise the arm out in front to shoulder height\nKeep a slight elbow bend throughout — do not lock out\nLower the handle slowly, resisting the cable'
WHERE name = 'Cable Front Raise' AND is_default = true;

UPDATE exercises SET
  description = 'A machine reverse fly that isolates the rear delts with a chest-supported, fixed path for clean form.',
  form_tips = 'Adjust the seat so the handles align with the shoulders\nPress the chest firmly into the pad throughout\nPull the handles back in a wide arc, leading with the elbows\nSqueeze the shoulder blades at the back, then return slowly'
WHERE name = 'Reverse Pec Deck' AND is_default = true;

UPDATE exercises SET
  description = 'A shoulder press with the bar anchored in a landmine that produces a safe arcing press for the front delts.',
  form_tips = 'Stand in a staggered stance with the bar end at the shoulder\nPress the bar up and slightly across the midline\nKeep the core tight — avoid leaning back excessively\nLower the bar under control to the starting shoulder position'
WHERE name = 'Landmine Shoulder Press' AND is_default = true;

UPDATE exercises SET
  description = 'A kettlebell overhead press that challenges shoulder stability with an offset load against the forearm.',
  form_tips = 'Clean a kettlebell to the rack position with the bell behind the forearm\nPress straight up until the arm locks out overhead\nKeep the core braced — do not arch the lower back\nLower the bell back to the rack under full control'
WHERE name = 'Kettlebell Press' AND is_default = true;

-- ARMS (10)

UPDATE exercises SET
  description = 'A strict bicep curl performed face-down on an incline bench that pins the arms and removes cheat.',
  form_tips = 'Lie face-down on an incline bench with a dumbbell in each hand\nLet the arms hang straight down with palms facing forward\nCurl the dumbbells up without swinging the shoulders\nLower slowly to full extension for the stretch'
WHERE name = 'Spider Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A dumbbell curl that rotates from supinated to pronated at the top, training the biceps and brachioradialis.',
  form_tips = 'Start with arms at your sides, palms facing forward\nCurl the dumbbells up to shoulder level with palms up\nAt the top, rotate the palms to face down\nLower in the pronated grip, then rotate back at the bottom'
WHERE name = 'Zottman Curl' AND is_default = true;

UPDATE exercises SET
  description = 'An overhand-grip barbell curl that trains the brachioradialis and forearms alongside the biceps.',
  form_tips = 'Grip the bar at shoulder width with palms facing down\nKeep the elbows tucked at the sides throughout\nCurl the bar up without swinging the torso\nLower slowly to a full arm extension'
WHERE name = 'Reverse Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A forearm exercise that trains the wrist flexors by rolling a dumbbell up with the palms facing up.',
  form_tips = 'Sit on a bench with the forearms resting on the thighs, palms up\nLet the dumbbells roll down to the fingertips\nCurl the weights back up by flexing the wrists\nMove only the wrists — keep the forearms flat on the thighs'
WHERE name = 'Wrist Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A forearm exercise that trains the wrist extensors by lifting a dumbbell with the palms facing down.',
  form_tips = 'Sit on a bench with the forearms resting on the thighs, palms down\nLet the dumbbells hang off the end of the knees\nLift the weights by extending only at the wrists\nLower slowly under control between reps'
WHERE name = 'Reverse Wrist Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A loaded carry with heavy dumbbells that builds grip strength, core bracing, and overall conditioning.',
  form_tips = 'Deadlift a heavy dumbbell into each hand with a tight grip\nStand tall with shoulders pulled back and chest up\nWalk forward with short steady steps, keeping the load steady\nSet the weights down under control at the end of each set'
WHERE name = 'Farmer''s Walk' AND is_default = true;

UPDATE exercises SET
  description = 'A neutral-grip cable curl that trains the brachialis and biceps with constant tension through the arc.',
  form_tips = 'Attach a rope to a low pulley and grip with palms facing each other\nKeep the elbows pinned at the sides throughout\nCurl the rope up without rotating the wrists\nLower slowly — do not let the stack crash down'
WHERE name = 'Cable Hammer Curl' AND is_default = true;

UPDATE exercises SET
  description = 'A triceps exercise where you dip behind a bench with the feet on the floor or elevated for progression.',
  form_tips = 'Sit on a bench with the hands gripping the edge beside the hips\nWalk the feet forward so the hips hover in front of the bench\nLower by bending the elbows until they reach 90 degrees\nPress back up without locking the elbows hard'
WHERE name = 'Bench Dip' AND is_default = true;

UPDATE exercises SET
  description = 'A push-up with the hands placed close together, biasing load toward the triceps and inner chest.',
  form_tips = 'Place hands under the chest at roughly shoulder-width or closer\nKeep elbows tucked close to the ribs on the way down\nLower until the chest nearly touches the hands\nPress back up without flaring the elbows wide'
WHERE name = 'Close-Grip Push-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A hybrid press and extension that loads the long head of the triceps with barbell-level weight.',
  form_tips = 'Lie on a flat bench with a narrow grip on the barbell\nLower the bar by bending at the elbows, tucking them inward\nLet the bar travel down near the neck, like a blended skull crusher\nExtend the arms back to lockout, squeezing the triceps'
WHERE name = 'JM Press' AND is_default = true;

-- CORE (12)

UPDATE exercises SET
  description = 'A full-range crunch coming up to a seated position, training the abs and hip flexors through a long arc.',
  form_tips = 'Lie on your back with knees bent and feet flat\nCross the arms on the chest or keep hands light behind the ears\nCurl up to a seated position by flexing the abs\nLower slowly — do not flop back down'
WHERE name = 'Sit-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A dynamic plank where the knees drive alternately toward the chest, training the core and raising heart rate.',
  form_tips = 'Start in a high plank with hands under the shoulders\nDrive one knee toward the chest without lifting the hips\nSwitch legs quickly in a steady running rhythm\nKeep the body in one straight line from head to heels'
WHERE name = 'Mountain Climber' AND is_default = true;

UPDATE exercises SET
  description = 'A supine exercise where you reach both arms toward the toes, training the upper abs through a short spinal flex.',
  form_tips = 'Lie on your back with legs straight up toward the ceiling\nReach both hands up toward the toes\nCurl the shoulders off the floor by contracting the abs\nLower under control — do not yank on the neck'
WHERE name = 'Toe Touch' AND is_default = true;

UPDATE exercises SET
  description = 'An isometric core hold where the body forms a shallow banana shape, training deep ab bracing.',
  form_tips = 'Lie on your back with arms extended overhead and legs straight\nPress the lower back flat to the floor\nLift the shoulders and legs a few inches off the ground\nHold the position steady — breathe without letting the back lift'
WHERE name = 'Hollow Body Hold' AND is_default = true;

UPDATE exercises SET
  description = 'A full-body crunch where arms and legs rise to meet in the middle, hammering the entire abdominal wall.',
  form_tips = 'Lie on your back with arms extended overhead and legs straight\nSimultaneously raise arms and legs to meet above the hips\nTouch the hands toward the shins at the top\nLower under control without letting the heels hit the floor'
WHERE name = 'V-Up' AND is_default = true;

UPDATE exercises SET
  description = 'A supine exercise where the legs flutter up and down continuously, building lower-ab endurance.',
  form_tips = 'Lie on your back with hands under the lower back for support\nRaise both legs a few inches off the floor\nAlternate each leg up and down in small, quick motions\nKeep the lower back pressed flat throughout'
WHERE name = 'Flutter Kick' AND is_default = true;

UPDATE exercises SET
  description = 'A crunch variation that curls the pelvis toward the ribs, targeting the lower portion of the abs.',
  form_tips = 'Lie on your back with knees bent and feet lifted\nCurl the hips up off the floor by contracting the lower abs\nBring the knees toward the chest at the top of each rep\nLower the hips slowly — do not let them slam down'
WHERE name = 'Reverse Crunch' AND is_default = true;

UPDATE exercises SET
  description = 'A supine exercise where the straight legs rise and lower, training the lower abs and hip flexors.',
  form_tips = 'Lie on your back with hands under the lower back\nRaise both straight legs up toward the ceiling\nLower them slowly until just above the floor\nKeep the lower back pressed flat throughout'
WHERE name = 'Leg Raise' AND is_default = true;

UPDATE exercises SET
  description = 'A rotational core exercise where the legs sweep side to side in a controlled arc, training the obliques.',
  form_tips = 'Lie on your back with arms out wide, legs pointing up\nLower the legs together to one side without touching the floor\nReverse and lower to the opposite side with control\nKeep the shoulders planted throughout'
WHERE name = 'Windshield Wiper' AND is_default = true;

UPDATE exercises SET
  description = 'A dynamic plank that alternates between forearms and hands, training the core and shoulder stabilizers.',
  form_tips = 'Start in a forearm plank with the body in a straight line\nPress up onto one hand, then the other, into a high plank\nReverse back down onto the forearms one arm at a time\nKeep the hips as still as possible throughout'
WHERE name = 'Plank Up-Down' AND is_default = true;

UPDATE exercises SET
  description = 'A short-range oblique crunch where the hands tap the heels from a bent-knee hook position.',
  form_tips = 'Lie on your back with knees bent and feet flat on the floor\nLift the shoulders slightly off the ground\nReach the hand down to tap the same-side heel\nAlternate sides in a steady rhythm without resting the shoulders'
WHERE name = 'Heel Touch' AND is_default = true;

UPDATE exercises SET
  description = 'A loaded hip hinge and rotation holding a kettlebell overhead, training shoulder stability and oblique strength.',
  form_tips = 'Press a kettlebell overhead with one arm and lock the elbow\nKeep the eyes on the bell throughout the movement\nHinge at the hips and reach the free hand toward the opposite foot\nReverse the movement to stand tall with the bell still pressed'
WHERE name = 'Kettlebell Windmill' AND is_default = true;

-- Reload PostgREST schema cache so the new description/form_tips are fresh.
NOTIFY pgrst, 'reload schema';
