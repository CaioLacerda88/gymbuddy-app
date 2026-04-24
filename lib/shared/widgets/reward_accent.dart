import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The single widget in the app allowed to emit [AppColors.heroGold].
///
/// RepSaga uses the Arcane Ascent palette (§17.0c) with a variable-ratio
/// reward-scarcity framework: violet is the daily accent, gold is the
/// reward signal. Gold appears ONLY for PRs, level-ups, streak milestones
/// and onboarding "first-week warmth" moments. Sprinkling gold anywhere
/// else dilutes the dopamine hit the palette is engineered to deliver.
///
/// The lint script `scripts/check_reward_accent.sh` greps `lib/` for any
/// file that references `heroGold` or the raw gold hex (`0xFFFFB800`,
/// `0xFFFFC107`, `0xFFFFD54F`) outside this file and `app_theme.dart`.
/// Callers wrap their reward-bearing widget in [RewardAccent] so the
/// payoff color is visually grouped with its narrative intent.
///
/// ### Usage
///
/// ```dart
/// RewardAccent(
///   child: Icon(Icons.emoji_events, size: 24),
/// )
/// ```
///
/// The accent color is applied through an `IconTheme` + `DefaultTextStyle`
/// so wrapped `Icon`s and `Text`s automatically inherit [AppColors.heroGold]
/// without the child widget needing to reference the token directly. Widgets
/// that paint with a `Color` parameter (e.g. ring painters, `CircleAvatar`)
/// should read the color from `RewardAccent.of(context).color`.
class RewardAccent extends StatelessWidget {
  const RewardAccent({required this.child, super.key});

  /// The widget subtree that should render in the reward color.
  ///
  /// `Icon` and `Text` descendants inherit the accent automatically.
  /// Custom painters should look up [RewardAccentData.color] via
  /// [RewardAccent.of].
  final Widget child;

  /// The exposed reward color. Single source of truth for every gold
  /// rendering in the app; duplicating this hex anywhere else is a lint
  /// violation (`scripts/check_reward_accent.sh`).
  static const Color color = AppColors.heroGold;

  /// Returns the [RewardAccentData] an ancestor [RewardAccent] is vending,
  /// or `null` if there is no ancestor. Custom painters that need the
  /// reward color should call this instead of reading `AppColors.heroGold`
  /// directly.
  static RewardAccentData? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RewardAccentScope>()
        ?.data;
  }

  @override
  Widget build(BuildContext context) {
    const data = RewardAccentData(color: color);
    return _RewardAccentScope(
      data: data,
      child: IconTheme.merge(
        data: const IconThemeData(color: color),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: color),
          child: child,
        ),
      ),
    );
  }
}

/// The data exposed by [RewardAccent.of] for custom-paint consumers.
class RewardAccentData {
  const RewardAccentData({required this.color});

  /// The reward-accent color currently in scope.
  final Color color;
}

class _RewardAccentScope extends InheritedWidget {
  const _RewardAccentScope({required this.data, required super.child});

  final RewardAccentData data;

  @override
  bool updateShouldNotify(_RewardAccentScope oldWidget) =>
      data.color != oldWidget.data.color;
}
