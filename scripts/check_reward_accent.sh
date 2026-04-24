#!/usr/bin/env bash
# Fails if any file under `lib/` references the heroGold reward color
# outside the two files where it is legitimately defined / consumed.
#
# RepSaga's Arcane Ascent palette (§17.0c) runs a reward-scarcity framework:
# violet is the daily structural accent, gold is the variable-ratio reward
# signal. Scattering gold across features dilutes the dopamine payoff the
# palette is engineered to deliver, so gold rendering is quarantined to a
# single widget (`RewardAccent`).
#
# Violations:
#   1. Any reference to `AppColors.heroGold` outside `app_theme.dart` or
#      `reward_accent.dart`.
#   2. Any raw gold hex literal (`0xFFFFB800`, `0xFFFFC107`, `0xFFFFD54F`)
#      outside those same two files. These are the three "Material yellow
#      reads as gold" hexes that could sneak in during a palette refresh.
#
# Allowed files:
#   - lib/core/theme/app_theme.dart       (token definition)
#   - lib/shared/widgets/reward_accent.dart (the ONLY widget that emits it)
#
# Opt-out: add `// ignore: reward_accent` at end of the offending line when
# the literal is intentional (e.g. a test-only fixture, an in-progress
# migration). Annotations must surface in code review.
#
# Usage: bash scripts/check_reward_accent.sh
# Exit: 0 on clean, 1 on any unapproved hit.

set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_DIR="$REPO_ROOT/lib"

if [[ ! -d "$SCAN_DIR" ]]; then
  echo "check_reward_accent: $SCAN_DIR does not exist; nothing to scan."
  exit 0
fi

# Allowed files — these are the single source of truth for the gold token.
# Stored as repo-relative paths so the grep output (which is absolute) can
# be filtered against them uniformly on Windows (bash) and POSIX alike.
ALLOWED_PATHS=(
  "lib/core/theme/app_theme.dart"
  "lib/shared/widgets/reward_accent.dart"
)

# heroGold symbol + the three gold-range raw hex literals.
PATTERN='heroGold|0xFFFFB800|0xFFFFC107|0xFFFFD54F'

ALL_HITS="$(grep -rn --include='*.dart' -E "$PATTERN" -- "$SCAN_DIR" \
  | grep -v 'ignore: reward_accent' || true)"

HITS=""
if [[ -n "$ALL_HITS" ]]; then
  while IFS= read -r line; do
    keep=true
    for allowed in "${ALLOWED_PATHS[@]}"; do
      if [[ "$line" == *"$allowed"* ]]; then
        keep=false
        break
      fi
    done
    if [[ "$keep" == true ]]; then
      HITS+="$line"$'\n'
    fi
  done <<< "$ALL_HITS"
fi

if [[ -n "$HITS" ]]; then
  echo "check_reward_accent: found unauthorized reward-accent references under lib/:" >&2
  echo "$HITS" >&2
  echo "" >&2
  echo "Wrap reward-bearing widgets in RewardAccent (lib/shared/widgets/reward_accent.dart)" >&2
  echo "instead of referencing AppColors.heroGold directly. If the literal is intentional," >&2
  echo "annotate the line with '// ignore: reward_accent'." >&2
  exit 1
fi

echo "check_reward_accent: clean (0 unauthorized references under lib/)."
exit 0
