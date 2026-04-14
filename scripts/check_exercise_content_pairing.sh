#!/usr/bin/env bash
# Enforce the P9 rule: any PR that INSERTs default exercise rows MUST also
# UPDATE description (and, by implication, form_tips) for every inserted
# row — either in the same migration file or in a sibling migration in the
# same PR.
#
# The check is row-level, not set-level: every inserted exercise name must
# appear in a matching `WHERE name = '...'` clause in some UPDATE statement
# in the same PR. A PR that inserts 10 new exercises but only updates 3 of
# them fails — no silent partial compliance.
#
# Detection model:
#   * Any `INSERT INTO exercises (...)` block in a changed migration is
#     treated as a default-exercise insert. Migrations only seed default
#     rows — user-created exercises never come in via SQL files — so this
#     is the correct conservative default.
#   * For each INSERT block, extract the first quoted string from every
#     VALUES `(...)` tuple (skipping the column-list tuple which contains
#     no single-quoted strings). That string is the exercise `name`.
#   * For each `UPDATE exercises SET ... description = ...` block, extract
#     every `WHERE name = '...'` target.
#   * An inserted name is "paired" iff some UPDATE targets it by name.
#   * Any inserted names with no matching UPDATE cause a non-zero exit
#     that lists exactly which rows need content.
#
# Portable POSIX-ish bash using only awk/grep/sed/sort/comm — no GNU-only
# flags. Runs on GitHub Actions Ubuntu runners.
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

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

inserted_names_file="${tmpdir}/inserted_names.txt"
updated_names_file="${tmpdir}/updated_names.txt"
inserter_files="${tmpdir}/inserter_files.txt"
updater_files="${tmpdir}/updater_files.txt"
: > "${inserted_names_file}"
: > "${updated_names_file}"
: > "${inserter_files}"
: > "${updater_files}"

# awk programs kept as here-docs for clarity.

# Extracts exercise names from every `INSERT INTO exercises (...)` block.
# Uses a per-statement flag that turns on at the INSERT and resets at the
# statement terminator `;`, so later UPDATEs or SELECTs in the same file are
# never misattributed.
read -r -d '' EXTRACT_INSERTED_NAMES <<'AWK' || true
BEGIN { ins = 0; buf = "" }
function flush_tuples(text,    i, n, parts, p, open, tup, rest, name, j, c, q1) {
  # Split on ")" so every element up to position `n-1` is a tuple body
  # preceded by "(". Walk each, take the first single-quoted string.
  n = split(text, parts, /\)/)
  for (i = 1; i <= n; i++) {
    p = parts[i]
    open = index(p, "(")
    if (open == 0) continue
    tup = substr(p, open + 1)
    # The column-list tuple contains no quoted strings — skip it.
    if (index(tup, "\x27") == 0) continue
    q1 = index(tup, "\x27")
    rest = substr(tup, q1 + 1)
    name = ""
    j = 1
    while (j <= length(rest)) {
      c = substr(rest, j, 1)
      if (c == "\x27") {
        # Doubled single-quote = literal apostrophe.
        if (substr(rest, j + 1, 1) == "\x27") {
          name = name "\x27"
          j = j + 2
          continue
        } else {
          break
        }
      }
      name = name c
      j++
    }
    if (length(name) > 0) print name
  }
}
{
  line = $0
  if (ins == 0) {
    if (match(line, /INSERT[[:space:]]+INTO[[:space:]]+exercises[[:space:]]*\(/)) {
      ins = 1
      buf = ""
    }
  }
  if (ins == 1) {
    buf = buf " " line
    if (index(line, ";") > 0) {
      flush_tuples(buf)
      ins = 0
      buf = ""
    }
  }
}
AWK

# Extracts `WHERE name = '...'` targets from any UPDATE statement in a file
# that contains `UPDATE exercises SET` and a `description =` clause.
read -r -d '' EXTRACT_UPDATED_NAMES <<'AWK' || true
{
  line = $0
  while (match(line, /name[[:space:]]*=[[:space:]]*\x27/) > 0) {
    rest = substr(line, RSTART + RLENGTH)
    name = ""
    j = 1
    while (j <= length(rest)) {
      c = substr(rest, j, 1)
      if (c == "\x27") {
        if (substr(rest, j + 1, 1) == "\x27") {
          name = name "\x27"
          j = j + 2
          continue
        } else {
          break
        }
      }
      name = name c
      j++
    }
    if (length(name) > 0) print name
    line = substr(rest, j + 1)
  }
}
AWK

for f in ${changed}; do
  [ -f "${f}" ] || continue

  # Does the file contain any INSERT INTO exercises statement?
  if grep -q -E "INSERT[[:space:]]+INTO[[:space:]]+exercises[[:space:]]*\(" "${f}"; then
    echo "${f}" >> "${inserter_files}"
    awk "${EXTRACT_INSERTED_NAMES}" "${f}" >> "${inserted_names_file}"
  fi

  # Does the file contain an UPDATE exercises SET ... description = ... pattern?
  if grep -q -E "UPDATE[[:space:]]+exercises[[:space:]]+SET" "${f}" && \
     grep -q -E "description[[:space:]]*=" "${f}"; then
    echo "${f}" >> "${updater_files}"
    awk "${EXTRACT_UPDATED_NAMES}" "${f}" >> "${updated_names_file}"
  fi
done

# --- No inserters? Skip. --------------------------------------------------
if [ ! -s "${inserter_files}" ]; then
  echo "No exercise inserts in the PR — pairing check skipped."
  exit 0
fi

# --- File-level fail-fast: at least one updater must exist. ---------------
if [ ! -s "${updater_files}" ]; then
  echo "FAIL: migration(s) insert exercises without any paired"
  echo "      UPDATE exercises SET description = ... in the same PR."
  echo ""
  echo "  offending insert(s):"
  sed 's/^/    /' "${inserter_files}"
  echo ""
  echo "  fix: add a sibling migration (or append to the same file) that runs"
  echo "       UPDATE exercises SET description = '...', form_tips = '...'"
  echo "       for every inserted row. See CLAUDE.md -> Exercise content"
  echo "       pairing rule."
  exit 1
fi

# --- Row-level check: every inserted name must have a matching UPDATE. -----
sort -u "${inserted_names_file}" -o "${inserted_names_file}"
sort -u "${updated_names_file}"  -o "${updated_names_file}"

# Lines in inserted_names that are NOT in updated_names.
missing=$(comm -23 "${inserted_names_file}" "${updated_names_file}" || true)

if [ -n "${missing}" ]; then
  echo "FAIL: these inserted names have no matching UPDATE ... SET description"
  echo "      in the same PR:"
  # Iterate line by line — names may contain spaces.
  while IFS= read -r n; do
    [ -n "${n}" ] && echo "    - ${n}"
  done <<EOF
${missing}
EOF
  echo ""
  echo "  fix: add matching UPDATE exercises SET description = '...',"
  echo "       form_tips = '...' WHERE name = '<name>' AND is_default = true"
  echo "       rows — either in the same migration file or in a sibling"
  echo "       migration in this PR."
  exit 1
fi

paired_count=$(wc -l < "${inserted_names_file}" | tr -d ' ')

echo "OK: default-exercise inserts paired with description updates."
echo "  paired names: ${paired_count}"
echo "  inserts in:"
sed 's/^/    /' "${inserter_files}"
echo "  updates in:"
sed 's/^/    /' "${updater_files}"
exit 0
