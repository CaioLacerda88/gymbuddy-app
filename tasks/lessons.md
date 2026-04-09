# Lessons Learned

Patterns and mistakes to avoid. Reviewed at session start.

---

## 2026-04-09: context.go() vs context.push() on Flutter web with GoRouter

**Mistake:** Changed all `context.go('/workout/active')` to `context.push()` to "ensure back-stack entry" for Android back button. This broke 3 E2E tests that rely on page reload.

**Root cause:** On Flutter web, after `page.reload()`, GoRouter re-initializes. The auth redirect cycle (loading → splash → home) means the user always lands on `/home` after reload, regardless of the original URL. The E2E tests then navigate back to the workout via the `_ActiveWorkoutBanner`. With `push()` from inside a ShellRoute to a top-level route, GoRouter 13.x web behavior is unreliable.

**Lesson:** `PopScope(canPop: false)` is sufficient for Android back button — it intercepts ALL back presses. No back-stack entry is needed when `canPop` is false. Don't change `go()` to `push()` for routes outside a ShellRoute unless you verify E2E reload behavior.

**Rule:** Navigation routing changes (`go`↔`push`, route restructuring) are FLOW changes, not visual-only. Always run E2E suite when routing logic changes.

---

## 2026-04-09: Use systematic debugging for CI/E2E failures

**Mistake:** Investigated E2E failure with ad-hoc grep/read cycles, taking multiple rounds to narrow down. Should have used `superpowers:systematic-debugging` skill from the start.

**Lesson:** When CI fails, immediately: (1) read the actual error output, (2) check what changed vs the last green run, (3) form a single hypothesis, (4) test minimally. Don't scatter-search hoping to stumble on the answer.
