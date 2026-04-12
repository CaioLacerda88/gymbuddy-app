# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## ACTIVE: E2E Infrastructure Fix — Full Regression Suite

**Branch:** `fix/e2e-infra-full-regression`
**Spec:** Plan file `functional-imagining-moler.md`

### Problem
- `npx http-server` crashes under 147 tests x 2 workers, causing `net::ERR_CONNECTION_REFUSED`
- PRs only run 61 smoke tests; 86 full tests only run on push to main
- CLAUDE.md incorrectly documents server as `python -m http.server`

### Checklist
- [x] Write `test/e2e/static-server.cjs` — custom Node.js static file server (zero deps)
- [x] Update `test/e2e/playwright.config.ts` — swap server, consolidate to single `regression` project
- [x] Update `test/e2e/package.json` — remove http-server dep, update scripts
- [x] Run `npm install` to update package-lock.json (48 packages removed, 0 vulnerabilities)
- [x] Update `.github/workflows/e2e.yml` — swap server, remove PR/push split, timeout 30min
- [x] Update `CLAUDE.md` — fix server docs, update running commands
- [x] Update `test/e2e/README.md` — update server and project references
- [ ] Verify: `flutter build web` + full regression suite locally (0 ERR_CONNECTION_REFUSED)
- [ ] Commit, push, open PR

---
