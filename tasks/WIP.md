# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## fix/rtdn-webhook-verify-jwt-config — persist rtdn-webhook gateway-JWT-off setting

**Branch:** `fix/rtdn-webhook-verify-jwt-config`
**Why:** During Stage 3 debugging we discovered Supabase's Edge Function gateway
was rejecting Pub/Sub's Google-OIDC JWTs with 401 before requests reached our handler.
We redeployed rtdn-webhook with `--no-verify-jwt`, which fixed live behavior, but that
flag is not persisted — the next unflagged deploy would regress the gateway fix.

**Scope:** One-line addition to `supabase/config.toml` with a header comment explaining
why the gateway check is off for this specific function. No Dart changes.

### Tasks

- [x] Add `[functions.rtdn-webhook]` block with `verify_jwt = false` in `supabase/config.toml`
- [x] Header comment referencing `_shared/google_play.ts` `verifyPubSubJwt` as the real auth boundary
- [ ] Open PR, review, merge
- [ ] After merge: no-op deploy needed (current deployment already has the fix; this is purely config hygiene)

### Acceptance

- `config.toml` has `[functions.rtdn-webhook]` with `verify_jwt = false`
- Header comment explains the third-party-webhook reasoning
- `validate-purchase` still verifies Supabase JWTs at gateway (its verify_jwt stays on — default)
