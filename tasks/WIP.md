# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## fix/subscription-reconcile-vault — Use Supabase Vault for reconcile cron secrets

**Branch:** `fix/subscription-reconcile-vault`
**Why:** Hosted Supabase blocks `ALTER DATABASE/ROLE SET app.settings.*` (42501 permission denied) at every level — Studio runs as restricted `postgres` role. Phase 16a Stage 2 setup is blocked until the reconcile function reads from Vault instead of `current_setting('app.settings.*')`.

**Scope:** Small follow-up fix to already-merged Phase 16a (PR #93). Not a new phase.

### Tasks

- [x] Create `supabase/migrations/00027_subscription_reconcile_use_vault.sql`
  - `CREATE OR REPLACE FUNCTION public.reconcile_subscription(p_user_id uuid)` — swap `current_setting('app.settings.edge_functions_url', true)` / `current_setting('app.settings.service_role_key', true)` for `SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = '...'`
  - Keep the same graceful no-op + `RAISE NOTICE` when secrets are missing (do NOT raise — a misconfigured reconciler must not poison the scheduler)
  - Keep function signature, SECURITY DEFINER, search_path, and the `net.http_post` call-shape identical (no behavior change beyond secret source)
  - Header comment must explain why Vault (hosted Supabase restriction) and reference this fix in migration history
- [x] Update `docs/phase-16a-setup.md` Section 2 — replace the `ALTER DATABASE postgres SET app.settings.*` SQL block with Vault UI steps (Project Settings → Vault → New secret) for names `edge_functions_url` and `service_role_key`. Update the "Verify" block to query `vault.decrypted_secrets` instead of `current_setting`.
- [x] `dart format .` + `dart analyze` (no Dart changes expected, but run anyway for hygiene)
- [ ] Open PR, review, merge
- [ ] After merge: `npx supabase db push` to apply 00027 to hosted Supabase
- [ ] User adds 2 secrets to Vault via UI (separately, not part of merge)

### Acceptance

- Cron function reads from `vault.decrypted_secrets` by name (`edge_functions_url`, `service_role_key`)
- Function still no-ops gracefully when secrets are absent
- Setup doc tells the user how to add secrets via Vault UI, no SQL required
- No changes to `net.http_post` call-shape, function signature, or batch scheduler
