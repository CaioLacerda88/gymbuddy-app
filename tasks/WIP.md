# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Roadmap: Phase 13 Sprint A→B Bridge + Sprint B

Sprint A is COMPLETE (PRs #42-#46). Next work follows this dependency chain:

```
PR7  (CI Android build gap)     ~0.5h   Makefile + CLAUDE.md
  → PR6  (Bulk dep upgrade)     ~1 day  Riverpod 3, GoRouter 17, Freezed 3, codegen toolchain
    → Sprint B (Retention)      ~1 week P1 charts, P2 exercises, P4 images, P8 empty-state, UX1-UX8
      → AB-PR1 (Foundation)     ~30-40h New theme, fonts, tokens, shared widgets
        → AB-PR2/3/4 (parallel)         Active workout, celebration, info surfaces
          → AB-PR5 (Polish)             Store screenshots, final animation QA
```

### Next up: PR7 — Close local CI Android build gap

- **Spec:** PLAN.md lines 1465-1540 (fully written)
- **Scope:** Add `flutter build apk --debug --no-shrink` as last step of `make ci` target
- **Files:** `Makefile`, `CLAUDE.md` (Commands section)
- **Verification:** Deliberate Gradle breakage → red, revert → green
- **Effort:** 0.5-1 agent-hour

### Then: PR6 — Bulk Dependency Upgrade + Toolchain Refresh

- **Spec:** PLAN.md lines 1108-1464 (fully written, includes codebase impact assessment)
- **Scope:** 34 outdated packages — Riverpod 2→3, GoRouter 13→17, Freezed 2→3, codegen toolchain
- **Key risks:** Riverpod 243 call sites, GoRouter 71 call sites, codegen output regeneration
- **Blocked packages:** `package_info_plus` 10.0.0 (needs newer Dart SDK), `meta`/`vector_math` (pinned by Flutter SDK)
- **Effort:** ~1 day

### Pending install

Release APK built at `build/app/outputs/flutter-apk/app-release.apk` (63.1MB, 2026-04-11). Phone was disconnected at build time. Install command when phone is connected:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---
