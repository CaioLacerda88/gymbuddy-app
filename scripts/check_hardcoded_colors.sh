#!/usr/bin/env bash
# Fails if any file under `lib/features/` contains an out-of-palette color.
#
# The pixel-art direction (§17.0) locks all color to 20 palette tokens in
# `AppColors`. Any of the following are considered palette violations:
#
#   1. Raw `Color(0x…)` literals  — new color leaking in without palette review.
#   2. `Colors.black` / `Colors.black12…` / `Colors.black87`, i.e. any
#      `Colors.black*` — `deepVoid` (or a `deepVoid.withValues(alpha:)` overlay)
#      must be used instead. Pure `#000000` is not a palette token.
#   3. `Colors.white` / `Colors.white10…` / `Colors.white70`, i.e. any
#      `Colors.white*` — `pureWhite` (or a `pureWhite.withValues(alpha:)`
#      overlay) must be used instead.
#
# Explicitly allowed:
#   - `Colors.transparent` — structural, not a color choice.
#
# Opt-out: add `// ignore: hardcoded_color` at end of the offending line when
# the literal is intentional (e.g. a test fixture recreating a specific pixel,
# or a structural true-black border that the palette intentionally does not
# cover). The ignore must be explicit so it surfaces in code review.
#
# Usage: bash scripts/check_hardcoded_colors.sh
# Exit: 0 on clean, 1 on any unapproved hit.

set -eu

# Resolve repo root regardless of where the script is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_DIR="$REPO_ROOT/lib/features"

if [[ ! -d "$SCAN_DIR" ]]; then
  echo "check_hardcoded_colors: $SCAN_DIR does not exist; nothing to scan."
  exit 0
fi

# Combined pattern:
#   - Color(0x…)          raw hex literal
#   - Colors.black(\d+)?  Colors.black, Colors.black12, Colors.black87, …
#   - Colors.white(\d+)?  Colors.white, Colors.white10, Colors.white70, …
# `Colors.transparent` is intentionally excluded (no \b boundary on black/white
# tail means `Colors.blackNNN` matches but `Colors.transparent` does not match
# this pattern at all — the word after `Colors.` is neither `black` nor `white`).
PATTERN='Color\(0x[0-9A-Fa-f]+|Colors\.black[0-9]*|Colors\.white[0-9]*'

# Grep every match, then strip lines with the opt-out marker.
# The `--` guards against any path that happens to start with `-`.
HITS="$(grep -rn --include='*.dart' -E "$PATTERN" -- "$SCAN_DIR" \
  | grep -v 'ignore: hardcoded_color' || true)"

if [[ -n "$HITS" ]]; then
  echo "check_hardcoded_colors: found out-of-palette color literals under lib/features/:" >&2
  echo "$HITS" >&2
  echo "" >&2
  echo "Migrate to an AppColors palette token (use .withValues(alpha: …) for" >&2
  echo "translucent overlays), or annotate the line with" >&2
  echo "'// ignore: hardcoded_color' if the literal is intentional." >&2
  exit 1
fi

echo "check_hardcoded_colors: clean (0 hits under lib/features/)."
exit 0
