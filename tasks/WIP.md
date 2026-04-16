# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Session snapshot (for refresh)

**Completed this session:**
- W3b: PR #63 merged — input length limits, CHECK constraints applied to hosted Supabase.
- W3b docs: PR #64 merged — condensed W3b in PLAN.md.
- W3: PR #65 merged — stale workout timeout UX. Tests: 1103 total.
- W3 docs: PR #66 merged — condensed W3 in PLAN.md.
- W8 scoping (Apr 15): original perf refactor premise invalidated — HomeScreen has no long list. Re-scoped via product-owner + ui-ux-critic analysis to a full Home IA refresh. History virtualization analyzed and ruled out (already correct). Plan approved by user.
- W8: PR #67 merged — four-state Home IA refresh (active-plan / brand-new / lapsed / week-complete), unified `_HeroBanner` vocab, scoped-rebuild tree, `hasActivePlanProvider` + `hasAnyWorkoutProvider` derived booleans, starter routines moved off home, E2E state-aware `startEmptyWorkout`, `ResumeWorkoutDialog` midnight-crossing flake fixed via injectable `DateTime? now` seam. Tests: 1087 total. All 14 reviewer findings closed in-cycle.

**Sprint C Remaining:** B6 (ProGuard/R8 optimization). After B6 merges, Phase 13 Exit Criterion #5 met.

**Local repo state:** on `main` at `2b7f6ed`, working tree clean.

**Hosted Supabase:** up to date through `00021_input_length_limits.sql`.

**Next agent to dispatch:** `tech-lead` with B6 ProGuard/R8 scope (keep rules for Supabase + Hive reflection, target 19.7MB → 12-14MB).
