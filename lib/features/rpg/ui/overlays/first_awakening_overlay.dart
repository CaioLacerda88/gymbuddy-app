import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_muscle_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/body_part.dart';
import '../widgets/body_part_localization.dart';

/// First-awakening onboarding overlay (Phase 18c, spec §13.4).
///
/// **Choreography (locked, 800ms compressed total):**
///   * Entry: `ScaleTransition` 0.92 → 1.0 (200ms `Curves.easeOut`)
///     simultaneous with `FadeTransition` 0 → 1 (150ms).
///   * 0–800ms: `ColorTween` `textDim @ 0.15` → `hotViolet @ 1.0`
///     (`Curves.easeOut`) — slow linear ignition, no peak/settle staging.
///   * 600–800ms: fade-out `FadeTransition` 1 → 0 (200ms `Curves.easeIn`).
///
/// **Differences from RankUpOverlay (locked):**
///   * Card is 240dp wide (vs RankUp 280dp) — physically smaller =
///     semantically smaller. This is a soft onboarding moment, not a
///     permanent rank transition.
///   * Rune sigil is 48dp (vs RankUp 60dp).
///   * NO backdrop dim — 800ms is too short to dim and recover eyes.
///   * NO tap dismissal — the window is shorter than reaction time, so
///     [IgnorePointer] over the card is the correct contract.
///   * Final color is `hotViolet`, matching the RuneHalo Active steady
///     state — this is the perceptual bridge from "the body part exists"
///     to "the body part is active on the character sheet."
///
/// **Throttle (spec §13.4):** the parent (`ActiveWorkoutNotifier`)
/// session-throttles this to one fire per workout. The widget itself
/// owns no throttle — it's a presentation-only surface.
class FirstAwakeningOverlay extends StatefulWidget {
  const FirstAwakeningOverlay({super.key, required this.bodyPart});

  final BodyPart bodyPart;

  @override
  State<FirstAwakeningOverlay> createState() => _FirstAwakeningOverlayState();
}

class _FirstAwakeningOverlayState extends State<FirstAwakeningOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 800);

  late final AnimationController _timeline;
  late final Animation<double> _scale;
  late final Animation<double> _entryFade;
  late final Animation<double> _exitFade;
  late final Animation<Color?> _ignite;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();

    _timeline = AnimationController(vsync: this, duration: _total);

    // Entry scale 0.92 → 1.0 over 0-200ms.
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0, 200 / 800, curve: Curves.easeOut),
      ),
    );

    // Entry fade 0 → 1 over 0-150ms.
    _entryFade = CurvedAnimation(
      parent: _timeline,
      curve: const Interval(0, 150 / 800, curve: Curves.easeOut),
    );

    // Exit fade 1 → 0 over 600-800ms.
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(600 / 800, 1.0, curve: Curves.easeIn),
      ),
    );

    // Ignition tween across the full window.
    _ignite = ColorTween(
      begin: AppColors.textDim.withValues(alpha: 0.15),
      end: AppColors.hotViolet,
    ).animate(CurvedAnimation(parent: _timeline, curve: Curves.easeOut));

    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bodyPartName = localizedBodyPartName(
      widget.bodyPart,
      l10n,
    ).toUpperCase();
    return AnimatedBuilder(
      animation: _timeline,
      builder: (context, _) {
        final fadeAlpha = _entryFade.value * _exitFade.value;
        return Opacity(
          opacity: fadeAlpha.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.value,
            child: IgnorePointer(
              child: Container(
                width: 240,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.hotViolet.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.hotViolet.withValues(alpha: 0.30),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcons.render(
                      _sigilAssetFor(widget.bodyPart),
                      color: _ignite.value ?? AppColors.hotViolet,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.firstAwakeningHeading(bodyPartName),
                      style: AppTextStyles.headline.copyWith(
                        fontSize: 18,
                        color: AppColors.textCream,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _sigilAssetFor(BodyPart bodyPart) {
  switch (bodyPart) {
    case BodyPart.chest:
      return AppMuscleIcons.chest;
    case BodyPart.back:
      return AppMuscleIcons.back;
    case BodyPart.legs:
      return AppMuscleIcons.legs;
    case BodyPart.shoulders:
      return AppMuscleIcons.shoulders;
    case BodyPart.arms:
      return AppMuscleIcons.arms;
    case BodyPart.core:
      return AppMuscleIcons.core;
    case BodyPart.cardio:
      return AppMuscleIcons.cardio;
  }
}
