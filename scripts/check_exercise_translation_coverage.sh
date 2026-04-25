#!/usr/bin/env bash
# Phase 15f Stage 5 — enforce that every default-exercise insert in a PR is
# paired with `exercise_translations` rows for BOTH `'en'` AND `'pt'` for the
# same slug. Replaces `scripts/check_exercise_content_pairing.sh` (which
# guarded the pre-15f schema where description/form_tips lived on
# `exercises` itself).
#
# Detection model (post-Stage-4 schema):
#
#   1. Slug introduction: collect every slug introduced by the PR's changed
#      migrations.
#        a) `INSERT INTO exercises (...)` — the slug column position is parsed
#           from the column list. After Stage 4, the `slug` column MUST be
#           present in any default-exercise insert; if it is not, the script
#           fails with a clear message.
#        b) `UPDATE exercises SET slug = '<value>' WHERE is_default = true
#           AND name = '<name>'` — the 00030 backfill pattern. Future
#           migrations should not need this (Stage 4 dropped `name`), but the
#           parser recognizes it defensively for backfill-style migrations.
#
#   2. Translation coverage: collect every `(slug, locale)` pair the PR's
#      `INSERT INTO exercise_translations (...)` blocks cover. Two shapes
#      are recognized:
#        a) Explicit `(VALUES ('slug_a', ...), ('slug_b', ...))` pattern
#           (00033 / canonical going forward) — slugs appear as the first
#           single-quoted string of each VALUES tuple; locale is the
#           hardcoded literal in the SELECT list (`SELECT e.id, '<locale>',
#           v.name, ...`).
#        b) Implicit-coverage pattern (00032 EN backfill):
#             SELECT e.id, '<locale>', e.name, e.description, e.form_tips
#             FROM exercises e
#           This covers EVERY slug present in `exercises` at apply time. For
#           coverage purposes the script treats it as a wildcard match for
#           that locale: any slug introduced in the same PR is considered
#           covered.
#
#   3. Pairing rule: every introduced slug must appear in some `'en'`
#      translation coverage AND some `'pt'` translation coverage in the
#      same PR. Missing-locale slugs are listed; exit nonzero.
#
# Self-test mode (`--self-test`): runs the parser against
# `scripts/fixtures/fixture_complete.sql` (must pass) and
# `scripts/fixtures/fixture_pt_missing.sql` (must fail). Lets the script's
# own correctness be verified independently of any real PR diff.
#
# Portable POSIX-ish bash using only awk/grep/sed/sort/comm — no GNU-only
# flags. Runs on GitHub Actions Ubuntu runners.
#
# Usage:
#   scripts/check_exercise_translation_coverage.sh [BASE_REF]
#   scripts/check_exercise_translation_coverage.sh --self-test
#
# BASE_REF defaults to "origin/main". In GitHub PR context, set it to
# "origin/${GITHUB_BASE_REF}" so only the PR's changed migrations are scanned.

set -euo pipefail

# -----------------------------------------------------------------------------
# awk programs (kept as here-docs so the parser is auditable in one place).
# -----------------------------------------------------------------------------

# Extract introduced slugs from `INSERT INTO exercises (col1, col2, ...) VALUES
# (...)`. The slug column position is parsed from the column list. If the
# slug column is missing from the insert, emit a sentinel line
# `__MISSING_SLUG_COL__` for the calling script to fail loudly on.
#
# The parser walks the statement char-by-char so that:
#   * multi-line VALUES tuples are tolerated;
#   * single-quoted string literals (including doubled `''` apostrophes)
#     parse correctly;
#   * commas inside string literals are not mistaken for tuple separators.
read -r -d '' EXTRACT_INTRODUCED_SLUGS_FROM_INSERT <<'AWK' || true
BEGIN { ins = 0; buf = "" }
function trim(s) {
  sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s
}
function parse_columns(text, positions,    op, cp, list, n, i, parts, name) {
  # text is the full INSERT statement up to (and including) the column-list
  # closing paren. The column list is between the first "(" after "exercises"
  # and the matching ")". Populates the caller's `positions` array:
  #   positions["slug"]       = 1-based column index, or 0 if absent
  #   positions["is_default"] = 1-based column index, or 0 if absent
  positions["slug"] = 0
  positions["is_default"] = 0
  op = index(text, "(")
  if (op == 0) return
  cp = index(text, ")")
  if (cp == 0 || cp <= op) return
  list = substr(text, op + 1, cp - op - 1)
  n = split(list, parts, /,/)
  for (i = 1; i <= n; i++) {
    name = trim(parts[i])
    if (name == "slug")       positions["slug"] = i
    if (name == "is_default") positions["is_default"] = i
  }
}
function emit_slugs_from_values(values_text, slug_pos, is_default_pos,
                                file_for_missing,
                                i, n, depth, j, c, in_str, tup) {
  # Walk values_text and collect each top-level "(...)" tuple. A tuple is at
  # depth 1 (depth = 0 outside, 1 inside). For each tuple, classify it as
  # default vs user via `is_default_pos`; only emit the slug for default
  # tuples (and only if it is a quoted literal).
  n = length(values_text)
  depth = 0
  in_str = 0
  tup = ""
  for (j = 1; j <= n; j++) {
    c = substr(values_text, j, 1)
    if (in_str) {
      if (c == "\x27") {
        # Doubled '' = literal apostrophe.
        if (substr(values_text, j + 1, 1) == "\x27") {
          tup = tup c "\x27"
          j++
          continue
        } else {
          in_str = 0
          tup = tup c
          continue
        }
      }
      tup = tup c
      continue
    }
    if (c == "\x27") { in_str = 1; tup = tup c; continue }
    if (c == "(") {
      depth++
      if (depth == 1) { tup = ""; continue }
      tup = tup c
      continue
    }
    if (c == ")") {
      if (depth == 1) {
        # End of a tuple — classify and (maybe) extract slug.
        emit_slug_from_tuple(tup, slug_pos, is_default_pos, file_for_missing)
        tup = ""
        depth--
        continue
      }
      depth--
      tup = tup c
      continue
    }
    if (depth >= 1) tup = tup c
  }
}
function emit_slug_from_tuple(tup, slug_pos, is_default_pos, file_for_missing,
                              n, depth, j, c, in_str, field, idx, fields,
                              val, isd) {
  # Split tup by top-level commas (ignoring commas inside strings or nested
  # parens, though tuples shouldn't have nested parens — be defensive).
  n = length(tup)
  depth = 0
  in_str = 0
  field = ""
  idx = 0
  for (j = 1; j <= n; j++) {
    c = substr(tup, j, 1)
    if (in_str) {
      if (c == "\x27") {
        if (substr(tup, j + 1, 1) == "\x27") {
          field = field c "\x27"
          j++
          continue
        } else {
          in_str = 0
          field = field c
          continue
        }
      }
      field = field c
      continue
    }
    if (c == "\x27") { in_str = 1; field = field c; continue }
    if (c == "(") { depth++; field = field c; continue }
    if (c == ")") { depth--; field = field c; continue }
    if (c == "," && depth == 0) {
      idx++
      fields[idx] = field
      field = ""
      continue
    }
    field = field c
  }
  # Last field (no trailing comma).
  idx++
  fields[idx] = field

  # Classify the tuple by is_default_pos. If is_default_pos is 0, the column
  # is absent → DB default applies (which is `false`), so this is a user
  # row, not a default. Skip silently.
  if (is_default_pos < 1 || is_default_pos > idx) return
  isd = trim(fields[is_default_pos])
  if (isd != "true") return

  # This is a default-exercise tuple. Slug column MUST be present (post-
  # Stage-4 schema). Emit the missing-slug sentinel if not.
  if (slug_pos < 1) {
    print "__MISSING_SLUG_COL__\t" file_for_missing
    return
  }
  if (slug_pos > idx) return
  val = trim(fields[slug_pos])
  # Only emit when slug is a single-quoted literal. Non-literal slug
  # expressions (e.g. `v_new_slug` inside an RPC function body) are not
  # data introductions — they're computed at call time and don't belong
  # to the migration's seed footprint.
  if (substr(val, 1, 1) != "\x27") return
  val = substr(val, 2)
  # Find the closing quote (handling doubled apostrophes).
  out = ""
  n2 = length(val)
  k = 1
  while (k <= n2) {
    cc = substr(val, k, 1)
    if (cc == "\x27") {
      if (substr(val, k + 1, 1) == "\x27") {
        out = out "\x27"
        k += 2
        continue
      }
      break
    }
    out = out cc
    k++
  }
  val = out
  if (length(val) > 0) print val
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
      # 1. Find slug + is_default column positions from the column list.
      delete positions
      parse_columns(buf, positions)
      # 2. Locate VALUES (...) and walk tuples. Per-tuple classification
      #    decides whether the row is a default-exercise (is_default=true)
      #    introduction; only those emit slug introductions or missing-
      #    slug-col sentinels.
      col_close = index(buf, ")")
      if (col_close > 0) {
        rest = substr(buf, col_close + 1)
        if (match(rest, /VALUES[[:space:]]*/)) {
          values_text = substr(rest, RSTART + RLENGTH)
          emit_slugs_from_values(values_text, positions["slug"],
                                 positions["is_default"], FILENAME)
        }
      }
      ins = 0
      buf = ""
    }
  }
}
AWK

# Extract slugs introduced via `UPDATE exercises SET slug = '<value>' WHERE
# is_default = true AND name = '...'` (the 00030 backfill pattern).
read -r -d '' EXTRACT_INTRODUCED_SLUGS_FROM_UPDATE <<'AWK' || true
{
  line = $0
  # Match `UPDATE exercises SET slug = '<value>'` — case-sensitive; matches
  # 00030's literal style.
  if (match(line, /UPDATE[[:space:]]+exercises[[:space:]]+SET[[:space:]]+slug[[:space:]]*=[[:space:]]*\x27/)) {
    rest = substr(line, RSTART + RLENGTH)
    val = ""
    n = length(rest)
    j = 1
    while (j <= n) {
      c = substr(rest, j, 1)
      if (c == "\x27") {
        if (substr(rest, j + 1, 1) == "\x27") {
          val = val "\x27"
          j += 2
          continue
        }
        break
      }
      val = val c
      j++
    }
    # Defensive: only emit slugs from rows guarded by `is_default = true`.
    # The 00030 pattern always includes that guard; user-row migrations
    # (none exist today, but be safe) without it should not be counted as
    # default introductions.
    if (length(val) > 0 && index(line, "is_default = true") > 0) {
      print val
    }
  }
}
AWK

# Extract `(slug, locale)` coverage pairs from
# `INSERT INTO exercise_translations (...)` blocks.
#
# Output lines are one of:
#   <slug>\t<locale>           — explicit VALUES coverage for one slug+locale
#   __WILDCARD__\t<locale>     — implicit `FROM exercises e` coverage (covers
#                                 every slug in the table for that locale)
read -r -d '' EXTRACT_TRANSLATION_COVERAGE <<'AWK' || true
BEGIN { ins = 0; buf = "" }
function trim(s) {
  sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s
}
function emit_explicit_pairs(values_text, locale,    n, j, c, in_str, depth,
                             tup, first_str_done, val) {
  # Walk values_text; for each top-level (...) tuple, take the FIRST
  # single-quoted string. That's the slug.
  n = length(values_text)
  depth = 0
  in_str = 0
  tup = ""
  for (j = 1; j <= n; j++) {
    c = substr(values_text, j, 1)
    if (in_str) {
      if (c == "\x27") {
        if (substr(values_text, j + 1, 1) == "\x27") {
          tup = tup c "\x27"
          j++
          continue
        }
        in_str = 0
        tup = tup c
        continue
      }
      tup = tup c
      continue
    }
    if (c == "\x27") { in_str = 1; tup = tup c; continue }
    if (c == "(") {
      depth++
      if (depth == 1) { tup = ""; continue }
      tup = tup c
      continue
    }
    if (c == ")") {
      if (depth == 1) {
        emit_first_quoted(tup, locale)
        tup = ""
        depth--
        continue
      }
      depth--
      tup = tup c
      continue
    }
    if (depth >= 1) tup = tup c
  }
}
function emit_first_quoted(tup, locale,    n, j, c, in_str, val, started) {
  # Find the first single-quoted string in tup and print "<val>\t<locale>".
  n = length(tup)
  j = 1
  started = 0
  val = ""
  while (j <= n) {
    c = substr(tup, j, 1)
    if (!started) {
      if (c == "\x27") { started = 1; j++; continue }
      j++
      continue
    }
    if (c == "\x27") {
      if (substr(tup, j + 1, 1) == "\x27") {
        val = val "\x27"
        j += 2
        continue
      }
      break
    }
    val = val c
    j++
  }
  if (length(val) > 0) print val "\t" locale
}
function process_block(text,    locale, m_start, m_len, sel, vstart, vt) {
  # 1. Find the locale literal: the SECOND comma-separated expression after
  #    `SELECT` is the locale literal (e.g. `SELECT e.id, 'en', ...`).
  if (match(text, /SELECT[[:space:]]+[^,]+,[[:space:]]*\x27[a-z][a-z]\x27/)) {
    sel = substr(text, RSTART, RLENGTH)
    # Extract the 2-letter locale between the single quotes.
    if (match(sel, /\x27[a-z][a-z]\x27/)) {
      locale = substr(sel, RSTART + 1, 2)
    } else {
      return
    }
  } else {
    return
  }

  # 2. Decide shape:
  #    Shape A (explicit VALUES):    "FROM (VALUES" appears before the FROM exercises.
  #    Shape B (implicit coverage):  the SELECT's FROM is `FROM exercises`
  #                                   (with no VALUES list).
  if (match(text, /FROM[[:space:]]*\([[:space:]]*VALUES[[:space:]]*/)) {
    vstart = RSTART + RLENGTH
    vt = substr(text, vstart)
    emit_explicit_pairs(vt, locale)
  } else if (match(text, /FROM[[:space:]]+exercises([[:space:]]+|;|$)/)) {
    print "__WILDCARD__\t" locale
  }
}
{
  line = $0
  if (ins == 0) {
    if (match(line, /INSERT[[:space:]]+INTO[[:space:]]+exercise_translations[[:space:]]*\(/)) {
      ins = 1
      buf = ""
    }
  }
  if (ins == 1) {
    buf = buf " " line
    if (index(line, ";") > 0) {
      process_block(buf)
      ins = 0
      buf = ""
    }
  }
}
AWK

# -----------------------------------------------------------------------------
# Core check function — operates on a list of file paths (newline-separated
# in `${1}`). Outputs the same banner-style messages as the old script.
#
# Returns 0 on pass, 1 on fail.
# -----------------------------------------------------------------------------
run_check() {
  local files="${1}"
  local label="${2:-PR diff}"
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '${tmpdir}'" RETURN

  local introduced_slugs="${tmpdir}/introduced_slugs.txt"
  local en_explicit="${tmpdir}/en_explicit.txt"
  local pt_explicit="${tmpdir}/pt_explicit.txt"
  local en_wildcard="${tmpdir}/en_wildcard.flag"
  local pt_wildcard="${tmpdir}/pt_wildcard.flag"
  local missing_slug_col="${tmpdir}/missing_slug_col.txt"
  local inserter_files="${tmpdir}/inserter_files.txt"
  local translation_files="${tmpdir}/translation_files.txt"
  : > "${introduced_slugs}"
  : > "${en_explicit}"
  : > "${pt_explicit}"
  : > "${missing_slug_col}"
  : > "${inserter_files}"
  : > "${translation_files}"

  local f
  while IFS= read -r f; do
    [ -z "${f}" ] && continue
    [ -f "${f}" ] || continue

    # 1. INSERT INTO exercises — extract introduced slugs from default
    #    (`is_default = true`) tuples only. RPC bodies with user-row inserts
    #    are filtered out at the tuple-classification step.
    if grep -q -E "INSERT[[:space:]]+INTO[[:space:]]+exercises[[:space:]]*\(" "${f}"; then
      local insert_out
      insert_out=$(awk "${EXTRACT_INTRODUCED_SLUGS_FROM_INSERT}" "${f}" || true)
      if [ -n "${insert_out}" ]; then
        local emitted_any=0
        # Filter sentinel lines (`__MISSING_SLUG_COL__\t<filename>`) into
        # missing_slug_col file; everything else is an introduced slug.
        while IFS= read -r line; do
          [ -z "${line}" ] && continue
          emitted_any=1
          case "${line}" in
            __MISSING_SLUG_COL__*)
              echo "${f}" >> "${missing_slug_col}"
              ;;
            *)
              echo "${line}" >> "${introduced_slugs}"
              ;;
          esac
        done <<EOF_INS
${insert_out}
EOF_INS
        if [ "${emitted_any}" -eq 1 ]; then
          echo "${f}" >> "${inserter_files}"
        fi
      fi
    fi

    # 2. UPDATE exercises SET slug — backfill-pattern slug introductions.
    if grep -q -E "UPDATE[[:space:]]+exercises[[:space:]]+SET[[:space:]]+slug" "${f}"; then
      local update_out
      update_out=$(awk "${EXTRACT_INTRODUCED_SLUGS_FROM_UPDATE}" "${f}" || true)
      if [ -n "${update_out}" ]; then
        printf '%s\n' "${update_out}" >> "${introduced_slugs}"
        echo "${f}" >> "${inserter_files}"
      fi
    fi

    # 3. INSERT INTO exercise_translations — collect coverage.
    if grep -q -E "INSERT[[:space:]]+INTO[[:space:]]+exercise_translations[[:space:]]*\(" "${f}"; then
      local cov_out
      cov_out=$(awk "${EXTRACT_TRANSLATION_COVERAGE}" "${f}" || true)
      if [ -n "${cov_out}" ]; then
        local emitted_any=0
        while IFS= read -r line; do
          [ -z "${line}" ] && continue
          emitted_any=1
          local slug locale
          slug=$(printf '%s' "${line}" | awk -F'\t' '{print $1}')
          locale=$(printf '%s' "${line}" | awk -F'\t' '{print $2}')
          if [ "${slug}" = "__WILDCARD__" ]; then
            if [ "${locale}" = "en" ]; then : > "${en_wildcard}"; fi
            if [ "${locale}" = "pt" ]; then : > "${pt_wildcard}"; fi
          else
            if [ "${locale}" = "en" ]; then echo "${slug}" >> "${en_explicit}"; fi
            if [ "${locale}" = "pt" ]; then echo "${slug}" >> "${pt_explicit}"; fi
          fi
        done <<EOF_COV
${cov_out}
EOF_COV
        if [ "${emitted_any}" -eq 1 ]; then
          echo "${f}" >> "${translation_files}"
        fi
      fi
    fi
  done <<EOF
${files}
EOF

  # ---- No insert / update activity? Skip. ---------------------------------
  if [ ! -s "${inserter_files}" ] && [ ! -s "${introduced_slugs}" ]; then
    echo "No exercise inserts or slug updates in the ${label} — coverage check skipped."
    return 0
  fi

  # ---- Hard fail: any INSERT INTO exercises missing slug column. ----------
  if [ -s "${missing_slug_col}" ]; then
    echo "FAIL: INSERT INTO exercises is missing the slug column."
    echo ""
    echo "  Post-15f schema requires every default-exercise insert to include"
    echo "  the slug column in its column list. After Stage 4, slug is the"
    echo "  join key for exercise_translations and is NOT NULL on the table."
    echo ""
    echo "  offending file(s):"
    sort -u "${missing_slug_col}" | sed 's/^/    /'
    echo ""
    echo "  fix: include slug in the column list and provide a literal slug"
    echo "       value for every VALUES tuple. See"
    echo "       supabase/migrations/00033_seed_exercise_translations_pt.sql"
    echo "       for the canonical pattern, and CLAUDE.md -> Exercise content"
    echo "       translation coverage rule."
    return 1
  fi

  sort -u "${introduced_slugs}" -o "${introduced_slugs}"

  if [ ! -s "${introduced_slugs}" ]; then
    echo "No new default-exercise slugs in the ${label} — coverage check skipped."
    return 0
  fi

  # ---- Pairing check: every introduced slug needs en + pt coverage. -------
  sort -u "${en_explicit}" -o "${en_explicit}"
  sort -u "${pt_explicit}" -o "${pt_explicit}"

  local en_wild=0
  local pt_wild=0
  [ -f "${en_wildcard}" ] && en_wild=1
  [ -f "${pt_wildcard}" ] && pt_wild=1

  local missing_en="${tmpdir}/missing_en.txt"
  local missing_pt="${tmpdir}/missing_pt.txt"
  : > "${missing_en}"
  : > "${missing_pt}"

  if [ "${en_wild}" -eq 1 ]; then
    : # wildcard covers all introduced slugs for en.
  else
    comm -23 "${introduced_slugs}" "${en_explicit}" > "${missing_en}" || true
  fi

  if [ "${pt_wild}" -eq 1 ]; then
    : # wildcard covers all introduced slugs for pt.
  else
    comm -23 "${introduced_slugs}" "${pt_explicit}" > "${missing_pt}" || true
  fi

  if [ -s "${missing_en}" ] || [ -s "${missing_pt}" ]; then
    echo "FAIL: introduced slugs lack paired en and/or pt translations"
    echo "      in exercise_translations within the same ${label}."
    echo ""
    if [ -s "${missing_en}" ]; then
      echo "  missing en translation for slug(s):"
      while IFS= read -r s; do
        [ -n "${s}" ] && echo "    - ${s}"
      done < "${missing_en}"
      echo ""
    fi
    if [ -s "${missing_pt}" ]; then
      echo "  missing pt translation for slug(s):"
      while IFS= read -r s; do
        [ -n "${s}" ] && echo "    - ${s}"
      done < "${missing_pt}"
      echo ""
    fi
    echo "  fix: add INSERT INTO exercise_translations rows for each missing"
    echo "       slug+locale pair — either in the same migration file or in"
    echo "       a sibling migration in the same PR. See"
    echo "       supabase/migrations/00033_seed_exercise_translations_pt.sql"
    echo "       for the canonical (VALUES ...) JOIN exercises e ON e.slug ="
    echo "       v.slug pattern, and CLAUDE.md -> Exercise content"
    echo "       translation coverage rule."
    return 1
  fi

  local intro_count
  intro_count=$(wc -l < "${introduced_slugs}" | tr -d ' ')

  echo "OK: introduced default-exercise slugs paired with en+pt translations."
  echo "  introduced slugs: ${intro_count}"
  if [ "${en_wild}" -eq 1 ]; then
    echo "  en coverage: wildcard (FROM exercises) + $(wc -l < "${en_explicit}" | tr -d ' ') explicit"
  else
    echo "  en coverage: $(wc -l < "${en_explicit}" | tr -d ' ') explicit slug(s)"
  fi
  if [ "${pt_wild}" -eq 1 ]; then
    echo "  pt coverage: wildcard (FROM exercises) + $(wc -l < "${pt_explicit}" | tr -d ' ') explicit"
  else
    echo "  pt coverage: $(wc -l < "${pt_explicit}" | tr -d ' ') explicit slug(s)"
  fi
  if [ -s "${inserter_files}" ]; then
    echo "  introductions in:"
    sort -u "${inserter_files}" | sed 's/^/    /'
  fi
  if [ -s "${translation_files}" ]; then
    echo "  translations in:"
    sort -u "${translation_files}" | sed 's/^/    /'
  fi
  return 0
}

# -----------------------------------------------------------------------------
# Self-test mode.
# -----------------------------------------------------------------------------
run_self_test() {
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  local fixture_complete="${script_dir}/fixtures/fixture_complete.sql"
  local fixture_pt_missing="${script_dir}/fixtures/fixture_pt_missing.sql"

  if [ ! -f "${fixture_complete}" ] || [ ! -f "${fixture_pt_missing}" ]; then
    echo "FAIL: self-test fixtures missing under ${script_dir}/fixtures/"
    echo "  expected: fixture_complete.sql + fixture_pt_missing.sql"
    return 1
  fi

  echo "Self-test: running coverage check against fixture_complete.sql"
  echo "------------------------------------------------------------------"
  local rc_complete=0
  run_check "${fixture_complete}" "complete fixture" || rc_complete=$?
  echo ""

  echo "Self-test: running coverage check against fixture_pt_missing.sql"
  echo "------------------------------------------------------------------"
  local rc_missing=0
  run_check "${fixture_pt_missing}" "pt-missing fixture" || rc_missing=$?
  echo ""

  if [ "${rc_complete}" -ne 0 ]; then
    echo "Self-test FAILED: complete fixture should have passed (got rc=${rc_complete})."
    return 1
  fi
  if [ "${rc_missing}" -eq 0 ]; then
    echo "Self-test FAILED: pt-missing fixture should have failed (got rc=0)."
    return 1
  fi
  echo "Self-test: complete fixture passed; pt-missing fixture correctly failed."
  return 0
}

# -----------------------------------------------------------------------------
# Entry point.
# -----------------------------------------------------------------------------

if [ "${1:-}" = "--self-test" ]; then
  run_self_test
  exit $?
fi

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
  echo "No migration changes — coverage check skipped."
  exit 0
fi

run_check "${changed}" "PR diff"
