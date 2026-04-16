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
- B6: PR #69 merged (commit `e605e77`) — ProGuard/R8 minify + resource shrinking on release. Narrow keep rules (attributes, JNI, Flutter embedding, Play Core `-dontwarn`, Sentry, OkHttp/Conscrypt/BouncyCastle/OpenJSSE TLS), no wildcards. `arm64-v8a` APK 25.83MB → 22.83MB (-11.6%); `classes.dex` -64.7%. 5-flow on-device smoke on Samsung S25 Ultra green. Reviewer findings (2 Important) closed in-cycle. Phase 13 Exit Criterion #5 + #6 MET. **Sprint C complete.**

**Sprint C Remaining:** none — all items merged.

**Phase 13 Exit Criteria still open:** #2 (image 404 walkthrough), #3 (new-user CTA E2E verification), #7 (full CI + 145/145 E2E + zero critical bugs). Remaining work is verification, not feature development.

**Backlog items surfaced this session (non-blocker):**
- BL-1 — `N sessions logged` copy is misleading when user logs 2+ workouts per day (calendar-day aggregation).
- BL-2 — `active-plan` home wastes ~900px below fold; `Last: X, Today` is a token gesture.
- BL-3 — Exercise progress chart fails at every density; full rebuild with e1RM / PR ring / axes / trend copy (PO+UX converged spec in `tasks/backlog.md`).

**Local repo state:** on `main` at `e605e77`, working tree clean post-merge.

**Hosted Supabase:** up to date through `00021_input_length_limits.sql`. Seed data present on caiolacerda88@gmail.com: 11 Barbell Bench Press workouts for BL-3 rich-data verification, marker `notes='seed:bench-60d'`, removable via one DELETE (documented in BL-3).

**Next:** no active WIP. Phase 13 wind-down is verification-only (exit criteria #2, #3, #7). Next feature sprint = Phase 14 (offline).
