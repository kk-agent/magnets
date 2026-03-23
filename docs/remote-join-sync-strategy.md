# Remote Join & Sync Strategy

_Draft: 2026-03-23 | Status: Proposal_

## Problem

Magnets currently stores all data in SwiftData with an App Group container. CloudKit scaffolding exists (container `iCloud.com.groupthinking.magnets`, status probe, model relationships marked CloudKit-ready), but there's no way for two people on different devices to share a Magnet. The invite code generates locally and the join flow has no remote lookup.

## Requirements

1. **Person A creates a Magnet** → gets a shareable invite code/link
2. **Person B opens the link** → joins the Magnet, sees existing posts
3. **Both see new posts in near-real-time** (widget refresh + in-app)
4. **Agent-authored posts** from Supabase `agent-post` appear on both devices
5. **Works offline** — posts queue locally, sync when connected
6. **No user accounts required** for MVP — device identity is sufficient

## Options Evaluated

### Option A: CloudKit-Only (SwiftData + CKSyncEngine)

**How it works:** SwiftData's built-in CloudKit integration handles sync via `CKShare`. Creating a Magnet creates a CKShare zone; joining uses the share URL.

**Pros:**
- Zero additional backend infrastructure
- Apple handles conflict resolution, offline queueing, incremental sync
- Already scaffolded — `cloudKitDatabase: .automatic` is one toggle away
- Free tier is generous (10GB asset, 100MB database per user)
- End-to-end encrypted sharing is possible with private CKShare zones

**Cons:**
- Both users need iCloud accounts signed in
- Agent posts from Supabase can't write directly to CloudKit (no server API for CKShare zones)
- No Android path ever
- Share acceptance UX is clunky (system share sheet, not in-app)
- Debugging sync issues is painful

**Verdict:** Good for person-to-person sync. Bad for agent → device push.

### Option B: Supabase-Only (Backend-Mediated)

**How it works:** All data lives in Supabase Postgres. The app reads/writes via Supabase client SDK. Realtime subscriptions push changes. Invite codes resolve via a DB lookup.

**Pros:**
- Agent-post already works (edge function writes to `posts` table)
- Invite code lookup is a simple query
- Realtime subscriptions for live updates
- Works across any platform
- Full control over data model

**Cons:**
- Requires network for everything (no offline)
- Need to build conflict resolution ourselves
- Need user identity / anonymous auth
- Need to mirror the SwiftData model in Postgres schema
- More infra to maintain

**Verdict:** Good for agents and cross-platform. Bad for offline/local-first feel.

### Option C: Hybrid — CloudKit for People, Supabase for Agents (Recommended)

**How it works:**

1. **Local-first:** SwiftData remains the source of truth on-device.
2. **Person-to-person sync:** CloudKit sharing via CKShare for Magnet zones. Two iCloud users share a Magnet natively.
3. **Agent ingestion:** Supabase `agent-post` writes to Postgres. A lightweight bridge (edge function or background task) converts the Supabase post into an APNs push that triggers WidgetKit reload + a background fetch. The app pulls the agent post from Supabase and inserts it into the local SwiftData store.
4. **Invite code resolution:** Supabase handles remote invite lookup. When Person B opens an invite link, the app checks Supabase for the Magnet metadata, then either (a) joins via CKShare if both are on iCloud, or (b) falls back to Supabase-mediated membership.

**Data flow:**

```
Person A (device) ←→ SwiftData ←→ CloudKit ←→ SwiftData ←→ Person B (device)
                                      ↑
                                      |  (background fetch on push)
Agent (Supabase) → agent-post → APNs → Widget refresh + SwiftData insert
```

**Pros:**
- Offline-first for human users (CloudKit)
- Agent posts flow through the existing Supabase pipeline
- Invite codes work remotely via Supabase lookup
- Graceful degradation: no iCloud → Supabase-only mode
- Widget refresh already partially built (WidgetRefreshCoordinator, push state store)

**Cons:**
- Two sync systems to maintain (CloudKit + Supabase bridge)
- Need to handle potential duplicates when agent posts arrive via both paths
- CKShare acceptance UX still needs polish

## Recommended Implementation Plan

### Phase 4A: Remote Invite Lookup (Supabase)

1. **New Supabase table: `magnets`**
   ```sql
   create table magnets (
     id uuid primary key,
     name text not null,
     invite_code text unique not null,
     owner_device_id text not null,
     created_at timestamptz default now()
   );
   create index idx_magnets_invite_code on magnets(invite_code);
   ```

2. **On Magnet creation:** App upserts to Supabase `magnets` table with the invite code.
3. **On invite link open:** App queries `GET /magnets?invite_code=eq.{CODE}` → gets Magnet UUID + name.
4. **Join flow:** App creates a local `MagnetMember` with role `.member` and registers membership in a new `magnet_members` Supabase table.

### Phase 4B: Agent Post Ingestion

1. **Existing:** `agent-post` edge function writes to `posts` table.
2. **New:** After writing, edge function sends APNs push via the existing token in `widget_push_tokens`.
3. **On device:** Background push triggers `BGAppRefreshTask` that fetches new posts from Supabase `posts` where `magnet_id` matches and `created_at > lastSync`. Inserts into local SwiftData.
4. **Dedup:** Use the post UUID as the primary key; skip insert if UUID already exists locally.

### Phase 4C: CloudKit Person-to-Person Sync

1. **Enable CloudKit** on device builds (already gated by `shouldUseCloudKit()`).
2. **Create CKShare** when the first member joins a Magnet.
3. **Share URL** included in invite message alongside the Supabase lookup URL.
4. **Recipient accepts share** → CloudKit syncs the Magnet zone → SwiftData merges.
5. **Fallback:** If CKShare acceptance fails (no iCloud, etc.), the Supabase-only membership path handles it.

### Phase 4D: Diagnostics

1. **Settings view** already shows `CloudKitSyncStatus` — extend with last sync timestamp and pending post count.
2. **Widget push state** is already tracked in `WidgetPushStateStore` — surface in Settings.
3. **Agent post ingestion** status: last fetch, count, errors.

## Schema Mapping

| SwiftData Model | Supabase Table | CloudKit Record Type |
|----------------|----------------|---------------------|
| `Magnet` | `magnets` | `CD_Magnet` (auto) |
| `Post` | `posts` (exists) | `CD_Post` (auto) |
| `MagnetMember` | `magnet_members` (new) | `CD_MagnetMember` (auto) |

## Open Questions

1. **Anonymous auth vs device ID:** Supabase anonymous auth gives a UUID per device. Good enough for MVP? Or should we use Sign in with Apple early?
2. **Conflict resolution for concurrent edits:** CloudKit uses last-writer-wins by default. Is that acceptable for posts (append-only) and Magnet metadata (rarely edited)?
3. **Migration path:** When we turn on CloudKit sync on a device that already has local data, SwiftData should migrate existing records into the CKShare zone automatically. Need to test this.
4. **Rate limits:** Supabase free tier allows 500 concurrent connections and 2GB database. Sufficient for MVP but needs monitoring.

## Success Criteria

- [ ] Person A creates Magnet → invite code is resolvable from Person B's device
- [ ] Person B joins via invite link → sees existing posts within 5 seconds
- [ ] Agent posts from Supabase appear on both devices within 30 seconds
- [ ] App works offline — posts queue and sync when reconnected
- [ ] No duplicate posts from CloudKit + Supabase dual-path
