---
name: magnets-2026-market-ship
title: Magnets 2026 Market-Competitive Ship
status: active
created_at: 2026-03-22 05:51:37 CDT
updated_at: 2026-03-22 05:55:00 CDT
---

# Purpose
Drive Magnets from the current iOS prototype to a stable, market-competitive 2026 product: fix live widget UX bugs, complete the physical-device widget push loop, harden reliability, add remote join/sync, flesh out Connected Agents, and keep a durable execution system running while work continues asynchronously.

# Current Confirmed State
- Repo: `kk-agent/magnets` (`main` active, Xcode project at `projects/magnets/ios/Magnets.xcodeproj`)
- Apple signing already points at Hayden’s team (`6DR32PXU4V`), bundle uses `com.groupthinking.magnets`
- Supabase project is live: `fhncotobwstskprfsoie`
- Edge Function `agent-post` is deployed and tested
- DB tables exist: `posts`, `widget_push_tokens`
- Real backend push path is blocked only by obtaining a physical-device widget push token
- Widget source now includes March 22 fixes for the live screenshot bugs:
  - quick-post and fallback widget glyphs now resolve through safe symbol fallbacks instead of missing-glyph boxes
  - medium/large quick-post buttons now use compact single-line labels to avoid `Post instant-ly` style wrapping/truncation
- Simulator build verification passed after the widget and media fixes (`xcodebuild -project .../Magnets.xcodeproj -scheme Magnets -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/magnets-derived CODE_SIGNING_ALLOWED=NO build`)
- Shared media storage now preserves the imported image file extension instead of always forcing `.jpg`
- Xcode Coding Assistant history was inspected directly; it contained the older March 21 implementation thread, not hidden new work

# Important Decisions
- Treat the inline chat screenshots as the current source of truth; screenshots in `projects/magnets/screenshots` are historical.
- Use the repo + task files as the durable source of truth, not transient Xcode/Codex UI state.
- Prioritize in this order:
  1. Live widget UX bugs
  2. Physical-device push token / end-to-end widget refresh
  3. Product hardening from Codex review (media correctness, invite-code safety, tests)
  4. Market-competitive feature layer (remote join/sync, Connected Agents, differentiated social/agent features)
- Keep GitHub hosting on `kk-agent/magnets` for now; transfer to `groupthinking` later, closer to ship.
- Use long-running task files + subagents + cron orchestration rather than ad-hoc chat memory.

# Codex Review Findings To Carry Forward
These came directly from the Xcode/Codex history and are now part of the durable backlog:
- AI Compose gating had been too high (iOS 26 vs intended lower deployment target); prior work adjusted this to iOS 18.
- Create Magnet needed user-facing failure UI; prior work added an alert path.
- Feed/widget image decoding needed caching and thumbnailing; prior work added `NSCache` + thumbnail loads.
- Media storage extension mismatch was addressed by preserving the imported image file extension on 2026-03-22; a broader re-encode policy is still optional future work.
- ~~Invite-code uniqueness is still not guaranteed.~~ Fixed in `879adb0` — `makeUniqueInviteCode(in:)` checks existing codes.
- No tests exist in the scheme.
- Remote join/sync remains product-incomplete if we want multi-device or remote collaboration.
- `Connected Agents` is still a placeholder and should become a real differentiator.

# Suggested Add-Ons / Product Expansion
Normalized from Codex review + current product direction:
- Remote join and sync (CloudKit and/or backend-mediated lookup/join)
- Connected Agents as a real system, not placeholder UI
- Safer media pipeline (re-encode/preserve correct file types)
- Invite-code uniqueness validation
- Tests around deep links, push state, media store, and gating logic
- Widget refresh rate-limiting / push hygiene for agent-generated activity
- Better physical-device instrumentation for push token capture and widget refresh debugging
- Market-positioned features for 2026 competitiveness:
  - agent-authored posts / shared AI memory moments
  - richer share surfaces (photos, reactions, ambient prompts, “send love” flows)
  - stronger collaboration / family / partner utility, not just novelty widgets
  - reliability + polish over raw feature count

# Blockers
- Physical iPhone build still needed to capture a real widget push token and complete the live APNs/widget refresh loop.
- No test target exists yet.
- Xcode-local project churn (`project.pbxproj`, `xcworkspace`, `xcuserdata`) should not be mistaken for real product work.

# Capabilities
- Skills: task-father, peekaboo, acp-router
- Plugins: nodes, cron
- Tools: read, write, edit, exec, sessions_spawn, cron, nodes, image

# Subagent Plan
## Active / Immediate
- **ACP Codex — implementation stream**
  - Fix the current widget glyph/wrap bugs from live screenshots
  - Verify the current repo/Xcode state
  - Commit clean product-facing fixes only

## Planned
- **Product research subagent**
  - Competitive scan for 2026 widget-first private social / relationship / family / memory apps
  - Distill differentiators that matter for Magnets
- **Backend/sync hardening subagent**
  - Push-token loop, remote join model, sync strategy, and agent-post reliability
- **QA subagent**
  - Build a repeatable regression checklist for widgets, deep links, post creation, and push refreshes

# Success Criteria
- Widget UI is clean on-device and in Simulator
- Physical-device push token path works end-to-end
- Core flows are reliable: create magnet, join, post, widget refresh, deep links
- Product has a credible 2026 positioning story and a prioritized moat roadmap
- Task system can continue unattended via cron + subagents without losing context

# Change Log
- 2026-03-22 05:51:37 CDT — Task registered and initialized.
- 2026-03-22 05:51:37 CDT — Enabled queue/done/failed/lock state files.
- 2026-03-22 05:51:37 CDT — State changed to 'active'.
- 2026-03-22 05:51:37 CDT — Initialized from live Xcode/Codex transcript + current Magnets status. Priorities: widget glyph/wrap fixes, physical-device push token loop, backlog normalization, and long-running orchestration.
- 2026-03-22 05:55:00 CDT — Expanded task with confirmed repo/backend/UI state, Codex review findings, add-on backlog, and subagent execution plan.
- 2026-03-22 05:56:00 CDT — Spawned two live workstreams: ACP Codex implementation run and market research subagent run; scheduled isolated cron worker every 2 hours for durable continuation.
- 2026-03-22 05:58:00 CDT — First market research subagent timed out without producing useful differentiation analysis; re-running with a hard-scoped prompt and explicit file targets.
- 2026-03-22 06:00:00 CDT — Queued an external Spine Swarm research prompt as a low-touch fallback for competitive positioning. Do not babysit it; review only if it produces usable signal.
- 2026-03-22 06:01:37 CDT — Fixed widget glyph fallback/rendering in the widget views, tightened quick-post button copy/layout to avoid ugly wrapping, and verified a clean simulator build.
- 2026-03-22 06:01:37 CDT — Hardened `SharedMediaStore.saveImageData` to preserve the imported image file extension instead of always writing `.jpg`.
- 2026-03-22 06:01:37 CDT — Committed the product-facing changes as `c7f5b91` (`Fix widget quick actions and media file extensions`).
- 2026-03-22 12:47:00 CDT — Added invite-code uniqueness validation: `Magnet.makeUniqueInviteCode(in:)` checks existing codes before assigning. CreateMagnetView updated. Build verified, committed as `879adb0`, pushed to main.
- 2026-03-22 14:47:00 CDT — Spawned ACP Codex to create MagnetsTests target with unit tests for deep link parsing and widget push state serialization (Phase 3 — first test coverage).
- 2026-03-22 16:48:00 CDT — ACP Codex session completed: MagnetsTests target + 9 tests (5 deep link, 4 widget push state) landed in `0533983`.
- 2026-03-22 16:54:00 CDT — Tests crashed on first run due to App Group entitlement `fatalError` in unsigned Simulator test host. Fixed `SharedModelContainer` with DEBUG-only Documents directory fallback + `.automatic` groupContainer. Clean build `** TEST SUCCEEDED **` (9/9). Committed `eeb97d2`, pushed to main.
- 2026-03-22 18:49:00 CDT — Hardened `SharedModelContainer.makeContainer`: replaced `assertionFailure` with `print` for CloudKit fallback; added nuke-and-retry for schema-incompatible stores (`deleteExistingStore()`). Prevents crash-loops during schema evolution. Committed `f3bae4b`, pushed to main.
- 2026-03-22 18:59:00 CDT — Added 11 `SharedMediaStoreTests`: save/load round-trip, JPEG/PNG extension detection, disk persistence, thumbnail generation, nil/empty path edge cases. Total test count now 20 (was 9). Committed `2d68012`, pushed to main.
- 2026-03-22 20:55:00 CDT — Added `WidgetRefreshCoordinator`: debounces `reloadAllTimelines()` with 15s cooldown to prevent iOS throttling during burst post activity. Replaced raw calls in 3 sites (CreateMagnet, MagnetDetail, PostToMagnetIntent). 4 new tests (24 total). Committed `c8f4001`, pushed to main.
- 2026-03-23 01:33:00 CDT — AI Compose types extracted for testability, 8 availability gating tests added (commit `2468720`). Layout polish + save logging fix (commit `a2e5c79`).
- 2026-03-23 03:30:00 CDT — Fixed Swift Testing parallelism race in WidgetPushStateStoreTests (`.serialized`), added 2 HTTPS deep link tests + 3 push state store tests (Swift Testing), added App Store listing + privacy policy drafts. Total tests: 37 (32 XCTest + 5 Swift Testing). Committed `536da58`, pushed to main. **Phase 3 testing is now complete.**
- 2026-03-23 03:35:00 CDT — Drafted remote join/sync strategy (`docs/remote-join-sync-strategy.md`). Hybrid approach: CloudKit for person-to-person, Supabase for agents + invite lookup. Committed `2a48be6`, pushed to main. **Phase 4 planning started.**
- 2026-03-23 04:15:00 CDT — Added `AgentConnection` SwiftData model (4 agent types, 3 schedules, CloudKit-safe). Registered in schema, wired inverse on Magnet. Feature design doc at `docs/connected-agents-design.md`. Build verified + 37/37 tests pass. Committed `f67b47c`, pushed to main. **Phase 4 — Connected Agents data layer complete.**
