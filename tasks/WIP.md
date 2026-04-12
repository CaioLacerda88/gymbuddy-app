# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## FIX NEEDED: E2E full suite infrastructure crash

**Problem:** The full E2E project (84 tests) fails with `net::ERR_CONNECTION_REFUSED` — the web server (`npx http-server`) crashes mid-suite. Confirmed on both main and PR6 branches (pre-existing, not a regression).

**Root cause:** `playwright.config.ts` line 44 uses `npx http-server ../../build/web -p 4200 -c-1 --silent` as the web server. This single-process Node.js static server crashes under the load of 147 tests × 2 workers on Windows. The smoke project (61 tests) completes before the crash; the full project tests fail because the server is already dead.

**Evidence:**
- Main branch: 63 passed (all smoke), 83 failed (3 smoke BUG-001 + all 80 full = ERR_CONNECTION_REFUSED)
- PR6 branch: 72 passed (all smoke + some early full), 74 failed (3 smoke BUG-001 + rest full)
- Error in test-results: `page.goto: net::ERR_CONNECTION_REFUSED at http://localhost:4200/`

**Proposed fix (next phase):**
1. Replace `npx http-server` with a more robust server (e.g., `npx serve -l 4200 ../../build/web` or configure `--cors` + connection limits)
2. OR add Playwright `webServer.reuseExistingServer: false` + restart logic between projects
3. OR reduce worker count for the `full` project to `workers: 1` to reduce server pressure
4. Update CLAUDE.md which incorrectly states the server is `python -m http.server` (it's actually `npx http-server`)

**Scope:** This is a test infra fix, not app code. Schedule for Sprint B or a dedicated infra PR.

---
