# TODOS

## Phase 0 — Immediate truth + cleanup
- [x] Inspect Xcode Coding Assistant history on disk
- [x] Attach to Xcode directly with Peekaboo
- [x] Confirm whether hidden uncommitted Codex work exists in Xcode
- [x] Normalize the current product truth into a durable task file

## Phase 1 — Live bugs / short path to confidence
- [x] Fix widget quick-post glyph/icon rendering from live screenshots
- [x] Fix widget text wrapping / button layout (`Post instant-ly` class of issue)
- [x] Rebuild and verify in Simulator after the fix
- [x] Commit only the real product/UI changes

## Phase 2 — Complete the real push loop
- [ ] Build to a physical iPhone
- [ ] Capture the real widget push token from `WidgetPushHandler`
- [ ] Insert token into `widget_push_tokens`
- [ ] Fire a real `agent-post` request through Supabase
- [ ] Confirm widget refreshes on-device from server push
- [ ] Document the exact device/push verification procedure

## Phase 3 — Hardening from Codex review
- [x] Decide whether to re-encode images to JPEG or preserve original file extensions correctly
- [x] Add invite-code uniqueness validation
- [x] Add rate-limiting / safety around widget refresh triggers for higher post volume (WidgetRefreshCoordinator, 15s debounce, commit `c8f4001`)
- [x] Create a real `MagnetsTests` target (commit `0533983`)
- [ ] Add minimal tests for:
  - [x] deep link parsing (5 tests in `MagnetsDeepLinkTests`)
  - [x] widget push state serialization (4 tests in `WidgetPushStateTests`)
  - [x] Fix App Group fallback so tests run in Simulator without entitlements (commit `eeb97d2`)
  - [x] shared media save/load (11 tests in `SharedMediaStoreTests`, commit `2d68012`)
  - [x] AI Compose availability gating (8 tests in `AIComposeTests`, commit `2468720`)
  - [x] Additional deep link HTTPS tests (2 Swift Testing, commit `536da58`)
  - [x] WidgetPushStateStore persistence tests (3 Swift Testing, commit `536da58`)
  - [x] Fix Swift Testing parallelism race (`.serialized` annotation, commit `536da58`)

## Phase 4 — Product capability lift
- [x] Define remote join/sync strategy → `docs/remote-join-sync-strategy.md` (commit `2a48be6`): hybrid CloudKit (person-to-person) + Supabase (agents + invite lookup)
- [x] Define Connected Agents data model (`AgentConnection` SwiftData, 4 types, 3 schedules) — commit `f67b47c`
- [x] Build Connected Agents UI: list view in Settings, add/remove/toggle per Magnet (commit `cf65c28`)
- [x] Add AgentConnection tests: enums, defaults, effectivePrompt, scheduleDescription, relationships, cascade delete (16 tests, commit `4fa3fb0`)
- [ ] Wire agent posting trigger (cron → Supabase agent-post → APNs)
- [ ] Define agent posting flows that feel useful, not gimmicky
- [ ] Strengthen invite/join/share UX
- [ ] Add device-observable diagnostics for widget push + sync failures

## Phase 5 — Market-competitive 2026 layer
- [x] Run a competitive scan on 2026 private social / memory / family / relationship widget apps → `docs/competitive-analysis-2026.md` (commit `a4333f8`)
- [x] Distill 3–5 differentiators that Magnets can plausibly win on → 5 differentiators: AI Agents, On-Device AI Compose, Group-Native, Widget as Dashboard, Privacy-First
- [x] Convert differentiators into an execution roadmap → P0/P1/P2 priority table in competitive analysis
- [x] Tighten App Store / launch positioning → Recommended tagline, subtitle, keywords, positioning statement
- [ ] Transfer repo to `groupthinking` when launch/admin timing is right

## Subagent workstreams
- [ ] ACP Codex implementation stream: widget bugs + repo hardening
- [ ] Product research subagent: competitive landscape + moat recommendations
- [ ] Backend/sync subagent: remote join, sync, push-token reliability plan
- [ ] QA subagent: regression checklist + release criteria
