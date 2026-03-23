# Connected Agents — Feature Design

_Draft: 2026-03-23 | Status: Implementation starting_

## Overview

Connected Agents lets users attach AI-powered helpers to individual Magnets. Each agent posts content on a schedule — morning greetings, daily quotes, weather updates, or custom prompts. Posts flow through the existing Supabase `agent-post` Edge Function and appear on both the in-app feed and Home Screen widgets.

## Agent Types

| Type | Key | Default Schedule | Description |
|------|-----|-----------------|-------------|
| Morning Briefing | `morningBriefing` | Daily 8:00 AM | Personalized morning greeting or daily overview |
| Daily Quote | `dailyQuote` | Daily 9:00 AM | Inspirational, motivational, or themed quote |
| Weather | `weather` | Daily 7:00 AM | Local weather summary for the day |
| Custom | `custom` | Daily noon | User-defined prompt — the agent generates from it |

## Data Model

### `AgentConnection` (SwiftData)

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `name` | `String` | Display name (e.g., "Morning Bot", "Quote of the Day") |
| `agentTypeValue` | `String` | Raw value of `AgentType` enum (CloudKit-safe) |
| `scheduleValue` | `String` | Raw value of `AgentSchedule` enum |
| `scheduledHour` | `Int` | Hour (0-23) in user's local time for scheduled delivery |
| `scheduledMinute` | `Int` | Minute (0-59) |
| `isEnabled` | `Bool` | Toggle on/off without deleting |
| `customPrompt` | `String?` | User-defined prompt text (for `.custom` type) |
| `lastPostAt` | `Date?` | Timestamp of last successful agent post |
| `lastPostPreview` | `String?` | Snippet of last post content for quick display |
| `createdAt` | `Date` | When the connection was created |
| `magnet` | `Magnet?` | Parent relationship (optional for CloudKit) |

### Enums (stored as raw `String`)

```
AgentType: morningBriefing | dailyQuote | weather | custom
AgentSchedule: hourly | daily | weekly
```

## Backend Integration

The existing `agent-post` Supabase Edge Function already accepts:
```json
{
  "magnet_id": "UUID",
  "content_type": "aiGenerated",
  "text_content": "...",
  "author_name": "Morning Bot"
}
```

**Trigger mechanism (Phase 2 — future):**
1. OpenClaw cron job fires at the agent's scheduled time
2. Cron job calls `agent-post` with the magnet ID and agent config
3. Edge Function writes to `posts` + sends APNs push
4. Device receives push → widget refreshes → post appears in feed

For MVP, agent connections are stored locally. The cron trigger will come when the full Supabase pipeline is live (requires physical device push token).

## UI Plan

### Settings → Connected Agents Card (existing placeholder → real)
- Show list of connected agents with status indicators
- Each row: agent name, type icon, schedule, last post time, enable/disable toggle
- "Add Agent" button → sheet with type picker, name, schedule, optional prompt

### Per-Magnet Agent Management
- MagnetDetailView toolbar button → "Manage Agents" sheet
- Shows agents connected to this specific Magnet
- Quick add from pre-configured types

### Agent Status Indicators
- 🟢 Active — enabled, last post within expected schedule window
- 🟡 Pending — enabled, no posts yet or overdue
- ⚪ Disabled — user toggled off
- 🔴 Error — last attempt failed (future: when backend integration is live)

## Success Criteria
- [ ] `AgentConnection` model compiles and is registered in the shared schema
- [ ] Settings view shows real agent list (empty state + populated state)
- [ ] User can add/remove agent connections per Magnet
- [ ] Build-verified on Simulator
- [ ] Ready for backend wiring when Supabase pipeline is complete
