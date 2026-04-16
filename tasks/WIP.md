# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Session snapshot (for refresh)

**Completed this session:**
- W3b: PR #63 merged — input length limits, CHECK constraints applied to hosted Supabase.
- W3b docs: PR #64 merged — condensed W3b in PLAN.md.
- W3: PR #65 merged — stale workout timeout UX. Tests: 1103 total.
- W3 docs: PR #66 merged — condensed W3 in PLAN.md.
- W8 scoping (Apr 15): original perf refactor premise invalidated — HomeScreen has no long list. Re-scoped via product-owner + ui-ux-critic analysis to a full Home IA refresh.
- W8: PR #67 merged — four-state Home IA refresh. Tests: 1087 total.
- W8 docs: PR #68 merged — condensed W8 in PLAN.md.
- B6: PR #69 merged (commit `e605e77`) — ProGuard/R8 minify + resource shrinking on release. Phase 13 Exit Criterion #5 + #6 MET. **Sprint C complete.**
- B6 docs: PR #70 merged (commit `91f8a3f`) — condensed B6 in PLAN.md, captured converged PO + UX spec for BL-3. Admin-merged per docs-only policy.
- Backlog grooming: BL-2 deferred to Phase 15e in PLAN.md. BL-1 folded into BL-3.
- BL-3: PR #71 merged (commit `966505f`) — exercise progress chart full rebuild. e1RM primary metric (Epley), 30d default window, PR gold ring on peak dot, labeled Y-axis with unit + 3 ticks, X-axis always on with dates, trend copy row (state-dependent, uses workoutCount for BL-1 fix), density-aware heights (120dp/200dp), container chrome, metric toggle (e1RM ↔ Weight), weekly-max aggregation for All time. Pipeline: tech-lead (TDD) → ui-ux-critic (2 Important fixed in-cycle) → qa-engineer (+4 tests, E2E selector refresh) → reviewer (1 BLOCKER e1RM ranking bug + 3 Important fixed in-cycle). Tests: 1143 total.

**Sprint C Remaining:** none — all items merged.

**Phase 13 Exit Criteria still open:** #2 (image 404 walkthrough), #3 (new-user CTA E2E verification), #7 (full CI + 145/145 E2E + zero critical bugs). Remaining work is verification, not feature development.

**Backlog status:** all items resolved. BL-1 closed (folded into BL-3). BL-2 deferred (Phase 15e). BL-3 closed (PR #71). `tasks/backlog.md` is empty.

**Local repo state:** on `main` at `966505f`, working tree clean post-merge.

**Hosted Supabase:** up to date through `00021_input_length_limits.sql`. Seed data still present on caiolacerda88@gmail.com: 11 Barbell Bench Press workouts, marker `notes='seed:bench-60d'`. Can be removed now that BL-3 shipped: `DELETE FROM public.workouts WHERE user_id = (SELECT id FROM auth.users WHERE email='caiolacerda88@gmail.com') AND notes='seed:bench-60d';`

**Next:** no active WIP. Phase 13 wind-down is verification-only (exit criteria #2, #3, #7). Next feature sprint = Phase 14 (offline).
