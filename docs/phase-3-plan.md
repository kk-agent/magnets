# Phase 3 Plan — AI Integration

**Date:** 2026-03-18
**Status:** Planning
**Prerequisite:** Phase 2 code merged ✅ — Phase 2 infra validation still pending (see blockers below)

## Update — 2026-03-20

- Repo scaffold now includes `supabase/functions/agent-post/index.ts`, `supabase/config.toml`, and `supabase/.env.example`.
- The scaffold is intentionally non-deployed and non-secret-bearing.
- Real CloudKit persistence and APNs widget push remain TODOs pending Apple/Supabase infra setup.

---

## Phase 2 Blockers That Affect Phase 3

These don't block Phase 3A (on-device AI) but they block 3B (webhook posting):

| Blocker | Owner | What's needed |
|---------|-------|---------------|
| Apple Developer CloudKit container | **Hayden** | Create `iCloud.com.groupthinking.magnets` in Apple Developer portal, attach to app + widget bundle IDs, assign paid team |
| APNs server-side push | **KK** (code) + **Hayden** (certs) | Edge Function or lightweight server that sends APNs requests using a `.p8` key from Apple Developer |
| Physical device testing | **Hayden** | Run on a real iPhone with iCloud signed in. Simulator can't validate CloudKit sync, push tokens, or interactive widget taps |

**Decision needed:** Do we gate Phase 3 on finishing these, or start 3A (on-device AI) in parallel since it has zero infra dependencies?

**Recommendation:** Start 3A now. It's purely client-side Swift code with no Apple Developer dependency.

---

## Phase 3A — Foundation Models (On-Device AI)

### What it is
Use Apple's Foundation Models framework (iOS 26+) to generate text content directly on-device. No API calls, no cost, no latency.

### Scope
- Import Foundation Models framework
- Add "AI Compose" button in MagnetDetailView composer area
- Prompt templates for common use cases:
  - Morning greeting / daily briefing
  - Inspirational quote
  - Post summary (condense recent posts)
  - Custom freeform prompt
- Generated text goes into the composer draft — user confirms before posting
- Graceful fallback on devices without Apple Intelligence (show disabled state, not crash)

### Technical approach
- `FoundationModels` framework, `LanguageModel` API
- Check `LanguageModel.isAvailable` before showing AI features
- Use `LanguageModel.default` for generation
- Keep prompts short and focused — on-device models are smaller than cloud models
- All generation is local — no network, no API key, no privacy concern

### Owner
**KK** — full implementation. No Hayden dependency.

### Acceptance criteria
1. "AI Compose" button appears in MagnetDetailView
2. Tapping it shows a prompt picker (morning greeting, quote, summary, custom)
3. Selecting a prompt generates text on-device
4. Generated text populates the composer draft field
5. User can edit before posting
6. On devices without Apple Intelligence, the button is hidden or shows "Not available"
7. Build passes on simulator (generation won't work in sim, but UI + fallback must not crash)

### Estimated effort
Small-medium. ~1 focused PR. The hard part is prompt tuning, not code.

---

## Phase 3B — OpenClaw Agent Webhook

### What it is
A server-side endpoint that lets OpenClaw (or any agent) post content into a Magnet remotely.

### Scope
- Supabase Edge Function: `POST /functions/v1/agent-post`
- Accepts: `{ magnet_id, content_type, text_content, media_url?, author_name? }`
- Writes post into CloudKit (via CloudKit Web Services API or Supabase mirror)
- Triggers APNs widget push to all magnet members
- OpenClaw cron job or skill calls this endpoint on schedule

### Current repo status
- Request validation scaffold exists locally.
- Bearer token auth is wired through env placeholders.
- CloudKit write path is stubbed as a TODO.
- APNs widget push path is stubbed as a TODO.

### Dependencies
- **CloudKit container must be provisioned first** (Hayden)
- **APNs .p8 key must exist** (Hayden)
- Decision: CloudKit Web Services API vs Supabase-mirrored data layer

### Owner
- **Endpoint code:** KK
- **CloudKit provisioning + APNs key:** Hayden
- **OpenClaw skill/cron wiring:** KK

### Technical decisions needed from Hayden
1. **Supabase or pure CloudKit?** Supabase adds a Postgres mirror but means syncing two data stores. Pure CloudKit Web Services is zero-ops but requires server-to-server auth tokens.
2. **Where to host the Edge Function?** Supabase Edge Functions (Deno), Vercel Edge Functions, or Cloudflare Workers?
3. **Agent posting frequency?** Once/day? On-demand? Configurable per-magnet?

### Acceptance criteria
1. `POST /functions/v1/agent-post` creates a post visible in the app
2. Widget refreshes after agent posts (via APNs push)
3. Agent-authored posts show a distinct author name (e.g., "KK" or agent name)
4. OpenClaw can trigger the endpoint via cron or direct call
5. Auth: endpoint requires a bearer token, not open to public

### Estimated effort
Medium. Depends heavily on CloudKit provisioning timeline.

---

## Phase 3C — Agent Management UI

### What it is
In-app settings UI to connect, configure, and monitor OpenClaw agents per-magnet.

### Scope
- Settings → "Connect Agent" flow
- Agent picker: choose agent type + posting schedule
- Agent types (v1):
  - Morning briefing
  - Daily quote
  - Weather summary
  - Custom prompt
- Per-magnet agent assignment
- Agent status display: last post time, next scheduled, enabled/disabled toggle
- Disconnect agent

### Dependencies
- Phase 3B must be working (agent needs to actually post)
- Agent configuration stored in CloudKit (per-magnet metadata) or local SwiftData

### Owner
- **UI code:** KK
- **Backend agent config storage:** KK (local first, CloudKit later)

### Acceptance criteria
1. User can assign an agent type to a magnet
2. Agent schedule is configurable (daily, twice daily, custom)
3. Agent status shows last post and next scheduled
4. User can enable/disable/disconnect agent
5. Config persists across app launches
6. Works in local-only mode (no CloudKit required for v1)

### Estimated effort
Medium. UI is straightforward; the complexity is in schedule persistence and OpenClaw integration.

---

## Execution Order

```
Phase 3A (on-device AI)     ← START NOW — no dependencies
    │
    ▼
Phase 3B (webhook endpoint)  ← blocked on CloudKit + APNs provisioning
    │
    ▼
Phase 3C (agent management)  ← blocked on 3B working
```

### Parallel track (Hayden)
While KK builds 3A:
1. Provision CloudKit container in Apple Developer
2. Generate APNs .p8 key
3. Decide Supabase vs pure CloudKit for backend
4. Test on physical device with iCloud signed in

---

## Responsibility Matrix

| Task | Owner | Blocker |
|------|-------|---------|
| Phase 3A: Foundation Models integration | **KK** | None |
| Phase 3A: AI Compose UI | **KK** | None |
| Phase 3A: Prompt templates | **KK** | None |
| Phase 3A: Graceful fallback for non-AI devices | **KK** | None |
| Phase 3A: PR + build verification | **KK** | None |
| CloudKit container provisioning | **Hayden** | Apple Developer paid team |
| APNs .p8 auth key generation | **Hayden** | Apple Developer portal |
| Physical device testing (Phase 2 validation) | **Hayden** | Device + iCloud account |
| Backend decision (Supabase vs CloudKit Web Services) | **Hayden** | Architecture call |
| Phase 3B: Edge Function endpoint | **KK** | CloudKit + APNs from Hayden |
| Phase 3B: APNs push integration | **KK** | .p8 key from Hayden |
| Phase 3B: OpenClaw cron/skill wiring | **KK** | 3B endpoint working |
| Phase 3C: Agent management UI | **KK** | 3B working |
| Phase 3C: Schedule persistence | **KK** | None (local-first) |

---

## Decisions Needed from Hayden

1. **Start 3A now or wait for Phase 2 infra validation?**
   - Recommendation: start 3A now, it's independent

2. **Supabase or CloudKit Web Services for backend?**
   - Recommendation: Supabase Edge Functions — you already have the account, Postgres gives you flexibility, and it avoids the CloudKit server-to-server token dance

3. **Where to host Edge Function?**
   - Recommendation: Supabase (already in stack)

4. **Agent posting frequency default?**
   - Recommendation: once per day, configurable per-magnet

5. **When can you provision Apple Developer infra?**
   - This is the single biggest bottleneck for everything after 3A
