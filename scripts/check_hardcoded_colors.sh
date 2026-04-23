#!/usr/bin/env bash
# Fails if any file under `lib/features/` contains a raw `Color(0x…)` literal.
#
# The pixel-art direction (§17.0) locks all color to 20 palette tokens in
# `AppColors`. A raw hex literal means either (a) a new color is leaking in
# without palette-review, or (b) a migration from the pre-pixel-art theme was
# missed. Both cases must fail CI before they ship.
#
# Opt-out: add `// ignore: hardcoded_color` at end of the offending line when
# the literal is intentional (e.g. a test fixture recreating a specific pixel).
# The ignore must be explicit so it surfaces in code review.
#
# Usage: bash scripts/check_hardcoded_colors.sh
# Exit: 0 on clean, 1 on any unapproved hit.

set -u

# Resolve repo root regardless of where the script is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_DIR="$REPO_ROOT/lib/features"

if [[ ! -d "$SCAN_DIR" ]]; then
  echo "check_hardcoded_colors: $SCAN_DIR does not exist; nothing to scan."
  exit 0
fi

# Grep every `Color(0x…)` literal, then strip lines with the opt-out marker.
HITS="$(grep -rn --include='*.dart' -E 'Color\(0x[0-9A-Fa-f]+' "$SCAN_DIR" \
  | grep -v 'ignore: hardcoded_color' || true)"

if [[ -n "$HITS" ]]; then
  echo "check_hardcoded_colors: found hardcoded Color(0x…) literals under lib/features/:" >&2
  echo "$HITS" >&2
  echo "" >&2
  echo "Migrate to an AppColors palette token, or annotate the line with" >&2
  echo "'// ignore: hardcoded_color' if the literal is intentional." >&2
  exit 1
fi

echo "check_hardcoded_colors: clean (0 hits under lib/features/)."
exit 0
