#!/usr/bin/env bash
# Enforce the P9 rule: any PR that INSERTs is_default = true exercises MUST
# also UPDATE description + form_tips for those rows — either in the same
# migration file or in a sibling migration in the same PR.
#
# Fails fast in CI before the slow Flutter build so offenders find out in
# seconds, not minutes. Portable POSIX-ish bash; runs on Linux CI runners.
#
# Usage:
#   scripts/check_exercise_content_pairing.sh [BASE_REF]
#
# BASE_REF defaults to "origin/main". In GitHub PR context, set it to
# "origin/${GITHUB_BASE_REF}" so only the PR's changed migrations are scanned.

set -euo pipefail

BASE_REF="${1:-origin/main}"
MIGRATIONS_DIR="supabase/migrations"

# Collect changed migrations relative to the base ref. Fall back to the full
# migrations directory if the base ref is unavailable (e.g. shallow clone on
# push to main — in which case every file is "changed" and the check still
# makes sense).
if git rev-parse --verify --quiet "${BASE_REF}" >/dev/null 2>&1; then
  changed=$(git diff --name-only --diff-filter=AM "${BASE_REF}"...HEAD -- "${MIGRATIONS_DIR}" || true)
else
  echo "warn: base ref ${BASE_REF} not found, scanning all migrations" >&2
  changed=$(ls "${MIGRATIONS_DIR}"/*.sql 2>/dev/null || true)
fi

if [ -z "${changed}" ]; then
  echo "No migration changes — pairing check skipped."
  exit 0
fi

# Does ANY changed migration add default exercises?
inserters=""
for f in ${changed}; do
  [ -f "${f}" ] || continue
  # Match inserts into exercises that flag is_default = true somewhere in the
  # file. Multiline (awk) so an INSERT on one line and the boolean several
  # lines later still counts. Heuristic but good enough for the P9 governance
  # goal — worst case a false positive forces the author to add content, which
  # is the right outcome.
  if awk '/INSERT[[:space:]]+INTO[[:space:]]+exercises/{ins=1} /is_default[[:space:]]*=[[:space:]]*true/ && ins{found=1} END{exit !found}' "${f}"; then
    inserters="${inserters}${f}
"
  fi
done

if [ -z "${inserters}" ]; then
  echo "No default-exercise inserts in the PR — pairing check skipped."
  exit 0
fi

# Does ANY migration in the PR populate description (and by implication
# form_tips)? We only require description here; form_tips without description
# would be a strange partial update, and reviewers catch that.
updaters=""
for f in ${changed}; do
  [ -f "${f}" ] || continue
  if grep -q -E "UPDATE[[:space:]]+exercises[[:space:]]+SET" "${f}" && \
     grep -q -E "description[[:space:]]*=" "${f}"; then
    updaters="${updaters}${f}
"
  fi
done

if [ -n "${updaters}" ]; then
  echo "OK: default-exercise inserts paired with description updates."
  echo "  inserts in:"
  printf '    %s\n' ${inserters}
  echo "  updates in:"
  printf '    %s\n' ${updaters}
  exit 0
fi

echo "FAIL: migration(s) insert is_default = true exercises without any paired"
echo "      UPDATE exercises SET description = ... in the same PR."
echo ""
echo "  offending insert(s):"
printf '    %s\n' ${inserters}
echo ""
echo "  fix: add a sibling migration (or append to the same file) that runs"
echo "       UPDATE exercises SET description = '...', form_tips = '...'"
echo "       for every inserted row. See CLAUDE.md -> Exercise content"
echo "       pairing rule."
exit 1
