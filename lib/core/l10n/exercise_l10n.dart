import '../../l10n/app_localizations.dart';

/// Derives a slug from an English exercise name.
///
/// ```
/// exerciseSlug('Barbell Bench Press') == 'barbell_bench_press'
/// exerciseSlug("Farmer's Walk")       == 'farmer_s_walk'
/// ```
String exerciseSlug(String englishName) {
  return englishName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Returns the localized exercise name for a default exercise.
///
/// User-created exercises (where `isDefault == false`) return their
/// original [name] unchanged. For default exercises the name is looked
/// up via the ARB `exerciseName_<slug>` key; if there is no matching
/// key the original English name is returned as a safe fallback.
String localizedExerciseName({
  required String name,
  required bool isDefault,
  required AppLocalizations l10n,
}) {
  if (!isDefault) return name;
  final slug = exerciseSlug(name);
  final getter = _exerciseNames[slug];
  return getter != null ? getter(l10n) : name;
}

/// Returns the localized routine name for a default routine.
///
/// User-created routines return their original [name]. Default routines
/// are matched by exact English name; if there is no mapping the
/// original name is returned.
String localizedRoutineName({
  required String name,
  required bool isDefault,
  required AppLocalizations l10n,
}) {
  if (!isDefault) return name;
  final getter = _routineNames[name];
  return getter != null ? getter(l10n) : name;
}

// ---------------------------------------------------------------------------
// Slug -> l10n getter maps
// ---------------------------------------------------------------------------

typedef _L10nGetter = String Function(AppLocalizations);

const Map<String, _L10nGetter> _routineNames = {
  'Push Day': _routinePushDay,
  'Pull Day': _routinePullDay,
  'Leg Day': _routineLegDay,
  'Full Body': _routineFullBody,
  'Upper/Lower \u2014 Upper': _routineUpperLowerUpper,
  'Upper/Lower \u2014 Lower': _routineUpperLowerLower,
  '5x5 Strength': _routineFiveByFiveStrength,
  'Full Body Beginner': _routineFullBodyBeginner,
  'Arms & Abs': _routineArmsAndAbs,
};

String _routinePushDay(AppLocalizations l) => l.routineNamePushDay;
String _routinePullDay(AppLocalizations l) => l.routineNamePullDay;
String _routineLegDay(AppLocalizations l) => l.routineNameLegDay;
String _routineFullBody(AppLocalizations l) => l.routineNameFullBody;
String _routineUpperLowerUpper(AppLocalizations l) =>
    l.routineNameUpperLowerUpper;
String _routineUpperLowerLower(AppLocalizations l) =>
    l.routineNameUpperLowerLower;
String _routineFiveByFiveStrength(AppLocalizations l) =>
    l.routineNameFiveByFiveStrength;
String _routineFullBodyBeginner(AppLocalizations l) =>
    l.routineNameFullBodyBeginner;
String _routineArmsAndAbs(AppLocalizations l) => l.routineNameArmsAndAbs;

const Map<String, _L10nGetter> _exerciseNames = {
  // -- CHEST (migration 00007) --
  'barbell_bench_press': _exBarbellBenchPress,
  'incline_barbell_bench_press': _exInclineBarbellBenchPress,
  'decline_barbell_bench_press': _exDeclineBarbellBenchPress,
  'dumbbell_bench_press': _exDumbbellBenchPress,
  'incline_dumbbell_press': _exInclineDumbbellPress,
  'dumbbell_fly': _exDumbbellFly,
  'cable_crossover': _exCableCrossover,
  'machine_chest_press': _exMachineChestPress,
  'push_up': _exPushUp,

  // -- BACK --
  'barbell_bent_over_row': _exBarbellBentOverRow,
  'deadlift': _exDeadlift,
  't_bar_row': _exTBarRow,
  'dumbbell_row': _exDumbbellRow,
  'dumbbell_pullover': _exDumbbellPullover,
  'cable_row': _exCableRow,
  'lat_pulldown': _exLatPulldown,
  'pull_up': _exPullUp,
  'chin_up': _exChinUp,
  'machine_row': _exMachineRow,

  // -- LEGS --
  'barbell_squat': _exBarbellSquat,
  'front_squat': _exFrontSquat,
  'romanian_deadlift': _exRomanianDeadlift,
  'hip_thrust': _exHipThrust,
  'dumbbell_lunges': _exDumbbellLunges,
  'bulgarian_split_squat': _exBulgarianSplitSquat,
  'goblet_squat': _exGobletSquat,
  'leg_press': _exLegPress,
  'leg_extension': _exLegExtension,
  'leg_curl': _exLegCurl,
  'calf_raise': _exCalfRaise,

  // -- SHOULDERS --
  'overhead_press': _exOverheadPress,
  'push_press': _exPushPress,
  'dumbbell_shoulder_press': _exDumbbellShoulderPress,
  'arnold_press': _exArnoldPress,
  'lateral_raise': _exLateralRaise,
  'front_raise': _exFrontRaise,
  'rear_delt_fly': _exRearDeltFly,
  'cable_face_pull': _exCableFacePull,

  // -- ARMS --
  'barbell_curl': _exBarbellCurl,
  'ez_bar_curl': _exEzBarCurl,
  'skull_crusher': _exSkullCrusher,
  'dumbbell_curl': _exDumbbellCurl,
  'hammer_curl': _exHammerCurl,
  'concentration_curl': _exConcentrationCurl,
  'dumbbell_tricep_extension': _exDumbbellTricepExtension,
  'tricep_pushdown': _exTricepPushdown,
  'cable_curl': _exCableCurl,
  'dips': _exDips,

  // -- CORE --
  'plank': _exPlank,
  'hanging_leg_raise': _exHangingLegRaise,
  'crunches': _exCrunches,
  'ab_rollout': _exAbRollout,
  'russian_twist': _exRussianTwist,
  'dead_bug': _exDeadBug,
  'cable_woodchop': _exCableWoodchop,

  // -- BANDS --
  'band_pull_apart': _exBandPullApart,
  'band_face_pull': _exBandFacePull,
  'band_squat': _exBandSquat,

  // -- KETTLEBELL --
  'kettlebell_swing': _exKettlebellSwing,
  'kettlebell_goblet_squat': _exKettlebellGobletSquat,
  'kettlebell_turkish_get_up': _exKettlebellTurkishGetUp,

  // -- CHEST (migration 00014) --
  'pec_deck': _exPecDeck,
  'cable_chest_press': _exCableChestPress,
  'wide_push_up': _exWidePushUp,

  // -- BACK (migration 00014) --
  'face_pull': _exFacePull,
  'rack_pull': _exRackPull,
  'good_morning': _exGoodMorning,
  'pendlay_row': _exPendlayRow,

  // -- LEGS (migration 00014) --
  'hack_squat': _exHackSquat,
  'sumo_deadlift': _exSumoDeadlift,
  'walking_lunges': _exWalkingLunges,
  'step_up': _exStepUp,
  'seated_calf_raise': _exSeatedCalfRaise,
  'leg_abductor': _exLegAbductor,
  'leg_adductor': _exLegAdductor,

  // -- SHOULDERS (migration 00014) --
  'upright_row': _exUprightRow,
  'machine_shoulder_press': _exMachineShoulderPress,
  'cable_lateral_raise': _exCableLateralRaise,

  // -- ARMS (migration 00014) --
  'preacher_curl': _exPreacherCurl,
  'incline_dumbbell_curl': _exInclineDumbbellCurl,
  'close_grip_bench_press': _exCloseGripBenchPress,
  'overhead_tricep_extension': _exOverheadTricepExtension,
  'rope_pushdown': _exRopePushdown,

  // -- CORE (migration 00014) --
  'bicycle_crunch': _exBicycleCrunch,
  'cable_crunch': _exCableCrunch,
  'pallof_press': _exPallofPress,
  'side_plank': _exSidePlank,

  // -- CARDIO (migration 00014) --
  'treadmill': _exTreadmill,
  'rowing_machine': _exRowingMachine,
  'stationary_bike': _exStationaryBike,
  'jump_rope': _exJumpRope,
  'elliptical': _exElliptical,

  // -- CHEST (migration 00019) --
  'incline_dumbbell_fly': _exInclineDumbbellFly,
  'decline_dumbbell_press': _exDeclineDumbbellPress,
  'landmine_press': _exLandminePress,
  'diamond_push_up': _exDiamondPushUp,
  'incline_push_up': _exInclinePushUp,
  'decline_push_up': _exDeclinePushUp,

  // -- BACK (migration 00019) --
  'hyperextension': _exHyperextension,
  'back_extension': _exBackExtension,
  'inverted_row': _exInvertedRow,
  'chest_supported_row': _exChestSupportedRow,
  'seal_row': _exSealRow,
  'straight_arm_pulldown': _exStraightArmPulldown,
  'close_grip_lat_pulldown': _exCloseGripLatPulldown,
  'wide_grip_pull_up': _exWideGripPullUp,
  'kettlebell_row': _exKettlebellRow,

  // -- LEGS (migration 00019) --
  'glute_bridge': _exGluteBridge,
  'single_leg_glute_bridge': _exSingleLegGluteBridge,
  'box_jump': _exBoxJump,
  'nordic_curl': _exNordicCurl,
  'wall_sit': _exWallSit,
  'donkey_kick': _exDonkeyKick,
  'bodyweight_squat': _exBodyweightSquat,
  'reverse_lunges': _exReverseLunges,
  'dumbbell_calf_raise': _exDumbbellCalfRaise,
  'single_leg_leg_press': _exSingleLegLegPress,
  'reverse_hyperextension': _exReverseHyperextension,
  'cable_glute_kickback': _exCableGluteKickback,
  'cable_pull_through': _exCablePullThrough,
  'kettlebell_deadlift': _exKettlebellDeadlift,

  // -- SHOULDERS (migration 00019) --
  'barbell_shrug': _exBarbellShrug,
  'dumbbell_shrug': _exDumbbellShrug,
  'cable_rear_delt_fly': _exCableRearDeltFly,
  'cable_front_raise': _exCableFrontRaise,
  'reverse_pec_deck': _exReversePecDeck,
  'landmine_shoulder_press': _exLandmineShoulderPress,
  'kettlebell_press': _exKettlebellPress,

  // -- ARMS (migration 00019) --
  'spider_curl': _exSpiderCurl,
  'zottman_curl': _exZottmanCurl,
  'reverse_curl': _exReverseCurl,
  'wrist_curl': _exWristCurl,
  'reverse_wrist_curl': _exReverseWristCurl,
  'farmer_s_walk': _exFarmersWalk,
  'cable_hammer_curl': _exCableHammerCurl,
  'bench_dip': _exBenchDip,
  'close_grip_push_up': _exCloseGripPushUp,
  'jm_press': _exJmPress,

  // -- CORE (migration 00019) --
  'sit_up': _exSitUp,
  'mountain_climber': _exMountainClimber,
  'toe_touch': _exToeTouch,
  'hollow_body_hold': _exHollowBodyHold,
  'v_up': _exVUp,
  'flutter_kick': _exFlutterKick,
  'reverse_crunch': _exReverseCrunch,
  'leg_raise': _exLegRaise,
  'windshield_wiper': _exWindshieldWiper,
  'plank_up_down': _exPlankUpDown,
  'heel_touch': _exHeelTouch,
  'kettlebell_windmill': _exKettlebellWindmill,
};

// ---------------------------------------------------------------------------
// Exercise name getters — one per exercise
// ---------------------------------------------------------------------------

// CHEST (00007)
String _exBarbellBenchPress(AppLocalizations l) =>
    l.exerciseName_barbell_bench_press;
String _exInclineBarbellBenchPress(AppLocalizations l) =>
    l.exerciseName_incline_barbell_bench_press;
String _exDeclineBarbellBenchPress(AppLocalizations l) =>
    l.exerciseName_decline_barbell_bench_press;
String _exDumbbellBenchPress(AppLocalizations l) =>
    l.exerciseName_dumbbell_bench_press;
String _exInclineDumbbellPress(AppLocalizations l) =>
    l.exerciseName_incline_dumbbell_press;
String _exDumbbellFly(AppLocalizations l) => l.exerciseName_dumbbell_fly;
String _exCableCrossover(AppLocalizations l) => l.exerciseName_cable_crossover;
String _exMachineChestPress(AppLocalizations l) =>
    l.exerciseName_machine_chest_press;
String _exPushUp(AppLocalizations l) => l.exerciseName_push_up;

// BACK (00007)
String _exBarbellBentOverRow(AppLocalizations l) =>
    l.exerciseName_barbell_bent_over_row;
String _exDeadlift(AppLocalizations l) => l.exerciseName_deadlift;
String _exTBarRow(AppLocalizations l) => l.exerciseName_t_bar_row;
String _exDumbbellRow(AppLocalizations l) => l.exerciseName_dumbbell_row;
String _exDumbbellPullover(AppLocalizations l) =>
    l.exerciseName_dumbbell_pullover;
String _exCableRow(AppLocalizations l) => l.exerciseName_cable_row;
String _exLatPulldown(AppLocalizations l) => l.exerciseName_lat_pulldown;
String _exPullUp(AppLocalizations l) => l.exerciseName_pull_up;
String _exChinUp(AppLocalizations l) => l.exerciseName_chin_up;
String _exMachineRow(AppLocalizations l) => l.exerciseName_machine_row;

// LEGS (00007)
String _exBarbellSquat(AppLocalizations l) => l.exerciseName_barbell_squat;
String _exFrontSquat(AppLocalizations l) => l.exerciseName_front_squat;
String _exRomanianDeadlift(AppLocalizations l) =>
    l.exerciseName_romanian_deadlift;
String _exHipThrust(AppLocalizations l) => l.exerciseName_hip_thrust;
String _exDumbbellLunges(AppLocalizations l) => l.exerciseName_dumbbell_lunges;
String _exBulgarianSplitSquat(AppLocalizations l) =>
    l.exerciseName_bulgarian_split_squat;
String _exGobletSquat(AppLocalizations l) => l.exerciseName_goblet_squat;
String _exLegPress(AppLocalizations l) => l.exerciseName_leg_press;
String _exLegExtension(AppLocalizations l) => l.exerciseName_leg_extension;
String _exLegCurl(AppLocalizations l) => l.exerciseName_leg_curl;
String _exCalfRaise(AppLocalizations l) => l.exerciseName_calf_raise;

// SHOULDERS (00007)
String _exOverheadPress(AppLocalizations l) => l.exerciseName_overhead_press;
String _exPushPress(AppLocalizations l) => l.exerciseName_push_press;
String _exDumbbellShoulderPress(AppLocalizations l) =>
    l.exerciseName_dumbbell_shoulder_press;
String _exArnoldPress(AppLocalizations l) => l.exerciseName_arnold_press;
String _exLateralRaise(AppLocalizations l) => l.exerciseName_lateral_raise;
String _exFrontRaise(AppLocalizations l) => l.exerciseName_front_raise;
String _exRearDeltFly(AppLocalizations l) => l.exerciseName_rear_delt_fly;
String _exCableFacePull(AppLocalizations l) => l.exerciseName_cable_face_pull;

// ARMS (00007)
String _exBarbellCurl(AppLocalizations l) => l.exerciseName_barbell_curl;
String _exEzBarCurl(AppLocalizations l) => l.exerciseName_ez_bar_curl;
String _exSkullCrusher(AppLocalizations l) => l.exerciseName_skull_crusher;
String _exDumbbellCurl(AppLocalizations l) => l.exerciseName_dumbbell_curl;
String _exHammerCurl(AppLocalizations l) => l.exerciseName_hammer_curl;
String _exConcentrationCurl(AppLocalizations l) =>
    l.exerciseName_concentration_curl;
String _exDumbbellTricepExtension(AppLocalizations l) =>
    l.exerciseName_dumbbell_tricep_extension;
String _exTricepPushdown(AppLocalizations l) => l.exerciseName_tricep_pushdown;
String _exCableCurl(AppLocalizations l) => l.exerciseName_cable_curl;
String _exDips(AppLocalizations l) => l.exerciseName_dips;

// CORE (00007)
String _exPlank(AppLocalizations l) => l.exerciseName_plank;
String _exHangingLegRaise(AppLocalizations l) =>
    l.exerciseName_hanging_leg_raise;
String _exCrunches(AppLocalizations l) => l.exerciseName_crunches;
String _exAbRollout(AppLocalizations l) => l.exerciseName_ab_rollout;
String _exRussianTwist(AppLocalizations l) => l.exerciseName_russian_twist;
String _exDeadBug(AppLocalizations l) => l.exerciseName_dead_bug;
String _exCableWoodchop(AppLocalizations l) => l.exerciseName_cable_woodchop;

// BANDS (00007)
String _exBandPullApart(AppLocalizations l) => l.exerciseName_band_pull_apart;
String _exBandFacePull(AppLocalizations l) => l.exerciseName_band_face_pull;
String _exBandSquat(AppLocalizations l) => l.exerciseName_band_squat;

// KETTLEBELL (00007)
String _exKettlebellSwing(AppLocalizations l) =>
    l.exerciseName_kettlebell_swing;
String _exKettlebellGobletSquat(AppLocalizations l) =>
    l.exerciseName_kettlebell_goblet_squat;
String _exKettlebellTurkishGetUp(AppLocalizations l) =>
    l.exerciseName_kettlebell_turkish_get_up;

// CHEST (00014)
String _exPecDeck(AppLocalizations l) => l.exerciseName_pec_deck;
String _exCableChestPress(AppLocalizations l) =>
    l.exerciseName_cable_chest_press;
String _exWidePushUp(AppLocalizations l) => l.exerciseName_wide_push_up;

// BACK (00014)
String _exFacePull(AppLocalizations l) => l.exerciseName_face_pull;
String _exRackPull(AppLocalizations l) => l.exerciseName_rack_pull;
String _exGoodMorning(AppLocalizations l) => l.exerciseName_good_morning;
String _exPendlayRow(AppLocalizations l) => l.exerciseName_pendlay_row;

// LEGS (00014)
String _exHackSquat(AppLocalizations l) => l.exerciseName_hack_squat;
String _exSumoDeadlift(AppLocalizations l) => l.exerciseName_sumo_deadlift;
String _exWalkingLunges(AppLocalizations l) => l.exerciseName_walking_lunges;
String _exStepUp(AppLocalizations l) => l.exerciseName_step_up;
String _exSeatedCalfRaise(AppLocalizations l) =>
    l.exerciseName_seated_calf_raise;
String _exLegAbductor(AppLocalizations l) => l.exerciseName_leg_abductor;
String _exLegAdductor(AppLocalizations l) => l.exerciseName_leg_adductor;

// SHOULDERS (00014)
String _exUprightRow(AppLocalizations l) => l.exerciseName_upright_row;
String _exMachineShoulderPress(AppLocalizations l) =>
    l.exerciseName_machine_shoulder_press;
String _exCableLateralRaise(AppLocalizations l) =>
    l.exerciseName_cable_lateral_raise;

// ARMS (00014)
String _exPreacherCurl(AppLocalizations l) => l.exerciseName_preacher_curl;
String _exInclineDumbbellCurl(AppLocalizations l) =>
    l.exerciseName_incline_dumbbell_curl;
String _exCloseGripBenchPress(AppLocalizations l) =>
    l.exerciseName_close_grip_bench_press;
String _exOverheadTricepExtension(AppLocalizations l) =>
    l.exerciseName_overhead_tricep_extension;
String _exRopePushdown(AppLocalizations l) => l.exerciseName_rope_pushdown;

// CORE (00014)
String _exBicycleCrunch(AppLocalizations l) => l.exerciseName_bicycle_crunch;
String _exCableCrunch(AppLocalizations l) => l.exerciseName_cable_crunch;
String _exPallofPress(AppLocalizations l) => l.exerciseName_pallof_press;
String _exSidePlank(AppLocalizations l) => l.exerciseName_side_plank;

// CARDIO (00014)
String _exTreadmill(AppLocalizations l) => l.exerciseName_treadmill;
String _exRowingMachine(AppLocalizations l) => l.exerciseName_rowing_machine;
String _exStationaryBike(AppLocalizations l) => l.exerciseName_stationary_bike;
String _exJumpRope(AppLocalizations l) => l.exerciseName_jump_rope;
String _exElliptical(AppLocalizations l) => l.exerciseName_elliptical;

// CHEST (00019)
String _exInclineDumbbellFly(AppLocalizations l) =>
    l.exerciseName_incline_dumbbell_fly;
String _exDeclineDumbbellPress(AppLocalizations l) =>
    l.exerciseName_decline_dumbbell_press;
String _exLandminePress(AppLocalizations l) => l.exerciseName_landmine_press;
String _exDiamondPushUp(AppLocalizations l) => l.exerciseName_diamond_push_up;
String _exInclinePushUp(AppLocalizations l) => l.exerciseName_incline_push_up;
String _exDeclinePushUp(AppLocalizations l) => l.exerciseName_decline_push_up;

// BACK (00019)
String _exHyperextension(AppLocalizations l) => l.exerciseName_hyperextension;
String _exBackExtension(AppLocalizations l) => l.exerciseName_back_extension;
String _exInvertedRow(AppLocalizations l) => l.exerciseName_inverted_row;
String _exChestSupportedRow(AppLocalizations l) =>
    l.exerciseName_chest_supported_row;
String _exSealRow(AppLocalizations l) => l.exerciseName_seal_row;
String _exStraightArmPulldown(AppLocalizations l) =>
    l.exerciseName_straight_arm_pulldown;
String _exCloseGripLatPulldown(AppLocalizations l) =>
    l.exerciseName_close_grip_lat_pulldown;
String _exWideGripPullUp(AppLocalizations l) =>
    l.exerciseName_wide_grip_pull_up;
String _exKettlebellRow(AppLocalizations l) => l.exerciseName_kettlebell_row;

// LEGS (00019)
String _exGluteBridge(AppLocalizations l) => l.exerciseName_glute_bridge;
String _exSingleLegGluteBridge(AppLocalizations l) =>
    l.exerciseName_single_leg_glute_bridge;
String _exBoxJump(AppLocalizations l) => l.exerciseName_box_jump;
String _exNordicCurl(AppLocalizations l) => l.exerciseName_nordic_curl;
String _exWallSit(AppLocalizations l) => l.exerciseName_wall_sit;
String _exDonkeyKick(AppLocalizations l) => l.exerciseName_donkey_kick;
String _exBodyweightSquat(AppLocalizations l) =>
    l.exerciseName_bodyweight_squat;
String _exReverseLunges(AppLocalizations l) => l.exerciseName_reverse_lunges;
String _exDumbbellCalfRaise(AppLocalizations l) =>
    l.exerciseName_dumbbell_calf_raise;
String _exSingleLegLegPress(AppLocalizations l) =>
    l.exerciseName_single_leg_leg_press;
String _exReverseHyperextension(AppLocalizations l) =>
    l.exerciseName_reverse_hyperextension;
String _exCableGluteKickback(AppLocalizations l) =>
    l.exerciseName_cable_glute_kickback;
String _exCablePullThrough(AppLocalizations l) =>
    l.exerciseName_cable_pull_through;
String _exKettlebellDeadlift(AppLocalizations l) =>
    l.exerciseName_kettlebell_deadlift;

// SHOULDERS (00019)
String _exBarbellShrug(AppLocalizations l) => l.exerciseName_barbell_shrug;
String _exDumbbellShrug(AppLocalizations l) => l.exerciseName_dumbbell_shrug;
String _exCableRearDeltFly(AppLocalizations l) =>
    l.exerciseName_cable_rear_delt_fly;
String _exCableFrontRaise(AppLocalizations l) =>
    l.exerciseName_cable_front_raise;
String _exReversePecDeck(AppLocalizations l) => l.exerciseName_reverse_pec_deck;
String _exLandmineShoulderPress(AppLocalizations l) =>
    l.exerciseName_landmine_shoulder_press;
String _exKettlebellPress(AppLocalizations l) =>
    l.exerciseName_kettlebell_press;

// ARMS (00019)
String _exSpiderCurl(AppLocalizations l) => l.exerciseName_spider_curl;
String _exZottmanCurl(AppLocalizations l) => l.exerciseName_zottman_curl;
String _exReverseCurl(AppLocalizations l) => l.exerciseName_reverse_curl;
String _exWristCurl(AppLocalizations l) => l.exerciseName_wrist_curl;
String _exReverseWristCurl(AppLocalizations l) =>
    l.exerciseName_reverse_wrist_curl;
String _exFarmersWalk(AppLocalizations l) => l.exerciseName_farmer_s_walk;
String _exCableHammerCurl(AppLocalizations l) =>
    l.exerciseName_cable_hammer_curl;
String _exBenchDip(AppLocalizations l) => l.exerciseName_bench_dip;
String _exCloseGripPushUp(AppLocalizations l) =>
    l.exerciseName_close_grip_push_up;
String _exJmPress(AppLocalizations l) => l.exerciseName_jm_press;

// CORE (00019)
String _exSitUp(AppLocalizations l) => l.exerciseName_sit_up;
String _exMountainClimber(AppLocalizations l) =>
    l.exerciseName_mountain_climber;
String _exToeTouch(AppLocalizations l) => l.exerciseName_toe_touch;
String _exHollowBodyHold(AppLocalizations l) => l.exerciseName_hollow_body_hold;
String _exVUp(AppLocalizations l) => l.exerciseName_v_up;
String _exFlutterKick(AppLocalizations l) => l.exerciseName_flutter_kick;
String _exReverseCrunch(AppLocalizations l) => l.exerciseName_reverse_crunch;
String _exLegRaise(AppLocalizations l) => l.exerciseName_leg_raise;
String _exWindshieldWiper(AppLocalizations l) =>
    l.exerciseName_windshield_wiper;
String _exPlankUpDown(AppLocalizations l) => l.exerciseName_plank_up_down;
String _exHeelTouch(AppLocalizations l) => l.exerciseName_heel_touch;
String _exKettlebellWindmill(AppLocalizations l) =>
    l.exerciseName_kettlebell_windmill;
