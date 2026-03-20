# Backend Scaffold — Supabase `agent-post`

## Status
- Added a non-deployed Supabase Edge Function scaffold at `supabase/functions/agent-post/index.ts`.
- Current behavior: validate request, enforce bearer auth, return structured JSON, and expose explicit backend/APNs integration status in the response.
- Real APNs signing + delivery are now wired.
- Current non-goals: no real CloudKit write path yet, no durable server-side token store yet, no deployment, no real secrets committed.

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
| `MAGNETS_CLOUDKIT_CONTAINER_ID` | Yes | CloudKit container identifier, currently `iCloud.com.groupthinking.magnets` |
| `MAGNETS_CLOUDKIT_BRIDGE_BASE_URL` | Yes for real backend write | Future backend/CloudKit bridge base URL |
| `MAGNETS_CLOUDKIT_MANAGEMENT_TOKEN` | Optional | Schema/config automation token if you later automate CloudKit management tasks |
| `MAGNETS_APNS_KEY_ID` | Yes for real APNs send | Apple APNs auth key id (`U43LDC7HYX`) |
| `MAGNETS_APNS_TEAM_ID` | Yes for real APNs send | Apple Developer team id (`6DR32PXU4V`) |
| `MAGNETS_APNS_TOPIC` | Yes for real APNs send | Widget push topic; current bundle id is `com.groupthinking.magnets.widget` |
| `MAGNETS_APNS_ENV` | Recommended | `development` (default) or `production` APNs host selection |
| `MAGNETS_APNS_P8_PRIVATE_KEY` | Yes for real APNs send | Contents of the APNs `.p8` private key, stored only as a local or hosted secret |
| `MAGNETS_WIDGET_PUSH_TOKEN_MAP_JSON` | Yes for current test path | Temporary JSON map of `magnet_id -> [pushToken]` for early APNs testing |

## Secret Handling Rules
- Do not commit secrets.
- Do not paste secrets into docs, source, examples, or git history.
- Do not ask for or use a CloudKit User Token. That token is tied to an end-user session and is not the right primitive for this server-side path.
- Rotate the CloudKit management token that was pasted into chat earlier; treat chat history as exposed.
- If CloudKit server-side automation is needed later, use a dedicated management/server token flow, not an end-user token.

## What Works Now
1. Payload validation
2. Bearer auth
3. APNs JWT signing with the `.p8` private key
4. APNs request delivery to Apple using `fetch`
5. Structured per-token delivery results in the JSON response

## What Still Does Not Work End-to-End
1. The function does **not** persist posts anywhere yet.
2. The function does **not** look up widget/device tokens from a real database yet.
3. The APNs payload is currently a **generic silent-push scaffold**. It may need adjustment once the exact `WidgetPushHandler` server payload contract is finalized.

## Wiring Plan When Infra Exists
1. Copy `supabase/.env.example` to an untracked local env file such as `supabase/.env.local`.
2. Replace placeholders locally or in hosted secret storage only.
3. Replace `MAGNETS_WIDGET_PUSH_TOKEN_MAP_JSON` with real token storage keyed by `magnet_id`.
4. Implement the `writePostToBackend` stub in `supabase/functions/agent-post/index.ts`.
5. Verify the exact WidgetPushHandler APNs payload shape on a physical device and tune the payload builder accordingly.
6. When ready, deploy the function through normal Supabase workflows. This repo change does not deploy anything.

## Local Validation
- `deno check supabase/functions/agent-post/index.ts`
- `deno fmt --check supabase/functions/agent-post/index.ts`

Those commands only validate the scaffold locally; they do not hit CloudKit, APNs, or Supabase hosted infrastructure.
