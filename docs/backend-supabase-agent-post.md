# Backend Scaffold — Supabase `agent-post`

## Status
- Added a non-deployed Supabase Edge Function scaffold at `supabase/functions/agent-post/index.ts`.
- Current behavior: validate request, enforce bearer auth, persist the post into Supabase, and expose explicit backend/APNs integration status in the response.
- Real APNs signing + delivery are now wired.
- Widget/device token lookup now reads from a Supabase table instead of an env var map.
- Current non-goals: no deployment, no real secrets committed.

## Request Contract
- Method: `POST` only
- Auth: `Authorization: Bearer <shared token>`
- Content-Type: `application/json`
- JSON body:

```json
{
  "magnet_id": "UUID-or-backend-record-id",
  "content_type": "text",
  "text_content": "Morning briefing is ready.",
  "media_url": "https://example.invalid/briefing.png",
  "author_name": "Orbit"
}
```

## Content Type Notes
- Canonical values are `text`, `photo`, and `aiGenerated` to match the iOS app model.
- The scaffold also normalizes `ai`, `ai_generated`, and `ai-generated` into `aiGenerated` for external callers.

## Required Environment Variables
See `supabase/.env.example` for placeholders.

| Variable | Required | Purpose |
|---|---|---|
| `MAGNETS_AGENT_POST_BEARER_TOKEN` | Yes | Shared bearer token for the endpoint |
| `SUPABASE_URL` | Yes | Supabase project URL used by the edge function admin client |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Supabase service-role key used to write `posts` and read `widget_push_tokens` |
| `MAGNETS_APNS_KEY_ID` | Yes for real APNs send | Apple APNs auth key id (`GJSN7LZ8SP`) |
| `MAGNETS_APNS_TEAM_ID` | Yes for real APNs send | Apple Developer team id (`6DR32PXU4V`) |
| `MAGNETS_APNS_TOPIC` | Yes for real APNs send | Widget push topic; current bundle id is `com.groupthinking.magnets.widget` |
| `MAGNETS_APNS_ENV` | Recommended | `development` (default) or `production` APNs host selection |
| `MAGNETS_APNS_P8_PRIVATE_KEY` | Yes for real APNs send | Contents of the APNs `.p8` private key, stored only as a local or hosted secret |

## Secret Handling Rules
- Do not commit secrets.
- Do not paste secrets into docs, source, examples, or git history.
- The local APNs `.p8` file currently lives at `~/.config/gcp-secrets/AuthKey_GJSN7LZ8SP.p8`; load it into local or hosted secret storage, but never commit the file contents.

## What Works Now
1. Payload validation
2. Bearer auth
3. Post persistence into the `posts` table
4. Widget/device token lookup from the `widget_push_tokens` table
5. APNs JWT signing with the `.p8` private key
6. APNs request delivery to Apple using `fetch`
7. Structured per-token delivery results in the JSON response

## What Still Does Not Work End-to-End
1. The APNs payload is currently a **generic silent-push scaffold**. It may need adjustment once the exact `WidgetPushHandler` server payload contract is finalized.
2. This repo change does not deploy the function or provision hosted secrets automatically.

## Wiring Plan When Infra Exists
1. Copy `supabase/.env.example` to an untracked local env file such as `supabase/.env.local`.
2. Replace placeholders locally or in hosted secret storage only.
3. Apply `supabase/migrations/001_initial_schema.sql` so `posts` and `widget_push_tokens` exist before invoking the edge function.
4. Load widget/device tokens into `widget_push_tokens`, keyed by `magnet_id`.
5. Verify the exact WidgetPushHandler APNs payload shape on a physical device and tune the payload builder accordingly.
6. When ready, deploy the function through normal Supabase workflows. This repo change does not deploy anything.

## Local Validation
- `deno check supabase/functions/agent-post/index.ts`
- `deno fmt --check supabase/functions/agent-post/index.ts`

Those commands only validate the scaffold locally; they do not hit APNs or Supabase hosted infrastructure.
