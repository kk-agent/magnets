# Magnets — Full Phased Build Plan

**Repo:** https://github.com/kk-agent/magnets
**Local:** ~/.openclaw/workspace/projects/magnets/
**Build target:** iPhone 17 Pro Simulator (iOS 26.2)
**Build command:** `xcodebuild -scheme Magnets -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

---

## ✅ Phase 1 — Foundation (COMPLETE)
*Build verified: compiles clean on Xcode 26.3 / iOS 26.2 simulator*

- [x] Xcode project with 2 targets (Magnets app + MagnetsWidget extension)
- [x] SwiftData models: Magnet, Post, MagnetMember
- [x] Shared App Group container (`group.com.magnets.shared`)
- [x] HomeView — magnet list with hero card, empty state, magnet cards
- [x] MagnetDetailView — post feed with text input + photo picker
- [x] CreateMagnetView — name input + color selection
- [x] PostRowView — colored cards with timestamps
- [x] SettingsView — placeholder
- [x] Widget extension: Small/Medium/Large views
- [x] TimelineProvider reading from shared container
- [x] WidgetPushHandler stub
- [x] Color palette system (MagnetPalette)
- [x] SharedMediaStore for photo persistence
- [x] Color(hex:) extension
- [x] GitHub repo + CI workflows + Copilot agent config
- [x] `xcodebuild build` — **BUILD SUCCEEDED**

### Phase 1 Self-Check Results
| Check | Result |
|-------|--------|
| All 17 Swift files compile | ✅ |
| App target builds | ✅ |
| Widget extension builds + embeds | ✅ |
| Code signing (simulator) | ✅ |
| Asset catalog processes | ✅ |
| No warnings (besides expected App Intents) | ✅ |

---

## 🔧 Phase 2 — Push, Sharing & CloudKit
*Goal: Real-time widget updates + multi-user magnets*

### 2A — WidgetPushHandler (APNs)
- [x] Implement `WidgetPushHandler` protocol properly
  - `pushTokenDidChange` now persists token + widget metadata into App Group JSON
  - Push handler is registered on the widget configuration
- [x] Add Push Notification entitlement to widget extension
- [x] Add local Supabase backend scaffold for future APNs widget push wiring
  - `supabase/functions/agent-post` validates POST requests, signs APNs JWTs, and can attempt APNs delivery using env-provided test token routing
  - `supabase/.env.example` and `docs/backend-supabase-agent-post.md` document required env vars and secret handling
- [ ] Server-side push: Edge Function to send APNs requests end-to-end via real token storage + verified WidgetPushHandler payload
- [ ] Test: post in app → widget updates within seconds
- [x] **BUILD before moving on**

### 2B — CloudKit Integration
- [x] Enable CloudKit groundwork on both targets (app + widget)
  - Added iCloud/CloudKit entitlements for app + widget
  - Shared SwiftData container now prefers `.automatic` on device and keeps a simulator/local fallback
- [x] Add CloudKit container identifier in code: `iCloud.com.groupthinking.magnets`
- [x] Mark SwiftData models as CloudKit-compatible
  - Backed enum-like values with CloudKit-safe scalars
  - Ensured to-one relationships are optional and stored properties have defaults
- [x] Add CloudKit sync status indicator in HomeView
  - Simulator shows the intentional local fallback
  - Device path is wired to `CKContainer.accountStatus`
- [x] Simulator build verified after CloudKit groundwork
- [ ] Provision the real Apple Developer CloudKit container + capabilities
  - Requires a paid team, bundle/container wiring in Apple Developer, and physical device validation
- [ ] Verify sync between signed-in devices
- [ ] **TEST on signed-in device**

### 2C — Sharing & Invites
- [x] Deep-link invite codes (`magnets://join/<code>`)
- [x] URL scheme already registered in `Info.plist` (`magnets`)
- [x] QR code generation for invite sharing
- [x] Join flow: paste invite code or tap deep link → resolve local magnet / CloudKit-ready placeholder
- [ ] CloudKit sharing: `CKShare` for magnet access control
- [x] Invite sheet UI in MagnetDetailView
- [x] Simulator build verified after invite/share changes
- [ ] **TEST CloudKit sharing on signed-in device**

### 2D — Interactive Widgets
- [x] Deep link from widget tap → specific magnet in app
- [x] Phase 2D spec drafted in `docs/phase-2d-interactive-widgets.md`
- [ ] Widget button: quick-post text directly from widget (implemented as one-tap preset actions via AppIntent)
- [ ] **BUILD + TEST**

### Phase 2 Verification Checklist
- [x] `xcodebuild build` passes
- [ ] Widget refreshes via APNs push (not just timeline)
- [ ] Data syncs between signed-in physical devices via CloudKit
- [ ] Invite link creates membership via CloudKit sharing
- [ ] Widget tap opens correct magnet

---

## 🧠 Phase 3 — AI Integration
*Goal: On-device AI + OpenClaw agent posting*

### 3A — Foundation Models (On-Device AI)
- [ ] Import Foundation Models framework
- [ ] Text generation: "Generate a morning greeting" → post to widget
- [ ] Summarize: condense recent posts into a summary post
- [ ] UI: "AI Compose" button in MagnetDetailView
- [ ] Prompt templates: morning briefing, daily quote, weather summary
- [ ] Reference: ~/Dev/AppleDev/ WWDC25 Foundation Models code-along
- [ ] **BUILD + TEST**

### 3B — OpenClaw Agent Webhook
- [ ] Supabase Edge Function: `POST /functions/v1/agent-post`
  - Accepts: `{ magnet_id, content_type, text_content, media_url }`
  - Inserts post into CloudKit (or Supabase mirror)
  - Triggers APNs widget push to all magnet members
- [x] Local scaffold committed for `POST /functions/v1/agent-post`
  - POST-only + bearer auth + structured JSON validation implemented
  - APNs JWT signing + delivery helper implemented with env-based test token routing
  - Real CloudKit/backend write remains TODO
  - Final WidgetPushHandler payload + durable token storage remain TODO
- [ ] OpenClaw skill or cron job: agent posts on schedule
- [ ] Agent types configurable in-app:
  - Morning briefing agent
  - Daily quote agent  
  - Weather agent
  - Custom prompt agent
- [ ] **BUILD + TEST**

### 3C — Agent Management UI
- [ ] Settings → "Connect Agent" flow
- [ ] Agent picker: choose agent type + schedule
- [ ] Agent status: last post, next scheduled, enable/disable
- [ ] Per-magnet agent assignment
- [ ] **BUILD + TEST**

### Phase 3 Verification Checklist
- [ ] Foundation Models generates text on-device (no API cost)
- [ ] OpenClaw agent posts via webhook
- [ ] Widget updates automatically when agent posts
- [ ] Agent schedule works via cron
- [ ] No crashes on devices without Apple Intelligence (graceful fallback)

---

## ✨ Phase 4 — Polish & Ship
*Goal: App Store ready*

### 4A — Design Polish
- [ ] Liquid Glass widget rendering modes (accented, desaturated)
- [ ] Widget previews look great in widget gallery
- [ ] Dark mode support throughout
- [ ] Dynamic Type / accessibility
- [ ] Haptic feedback on interactions
- [ ] App icon design
- [ ] Launch screen
- [ ] **SCREENSHOT ALL WIDGET SIZES**

### 4B — Photo Features
- [ ] Photo filters / overlays for post images
- [ ] Camera capture directly in post flow
- [ ] Image compression for CloudKit storage
- [ ] Photo posts render correctly in all widget sizes
- [ ] **BUILD + TEST**

### 4C — Notifications
- [ ] Push notification when friend posts to your magnet
- [ ] Notification tap → deep link to magnet
- [ ] Notification settings per-magnet (mute option)
- [ ] **BUILD + TEST**

### 4D — App Store Submission
- [ ] Privacy policy (no data collected, CloudKit only)
- [ ] App Store Connect listing
  - Screenshots: iPhone 17 Pro, iPad Pro
  - App preview video
  - Description, keywords, categories
- [ ] TestFlight beta (internal)
- [ ] TestFlight beta (external — 5-10 testers)
- [ ] Address beta feedback
- [ ] Submit for review
- [ ] **SHIP IT** 🚀

### Phase 4 Verification Checklist
- [ ] No crashes in 1-hour usage session
- [ ] All widget sizes render correctly
- [ ] Dark mode works throughout
- [ ] VoiceOver works on all screens
- [ ] App Store screenshots captured
- [ ] Privacy nutrition label complete
- [ ] TestFlight feedback addressed

---

## 🧭 KK Platform / MCP Notes (Parallel R&D)
*User context captured 2026-03-17 — not blocking Magnets Phase 2, but relevant to product architecture*

- [ ] Define **KK as a bi-directional MCP server** — not just an app bot, but an orchestration surface
- [ ] Model **KK's hired team of subagents** as managed workers / on-site operators / contractors-as-needed
- [ ] Evaluate **Google MCP Toolbox** as part of KK's tool fabric
  - LookML authoring thread: https://discuss.google.dev/t/from-prompt-to-production-lookml-authoring-in-mcp-toolbox/280101?u=garvey
  - Release notes: https://github.com/googleapis/genai-toolbox/releases/tag/v0.29.0
- [ ] Decide whether MCP Toolbox belongs in:
  - Magnets backend agent layer
  - KK orchestration runtime
  - separate internal tooling repo

---

## 🔮 Phase 5 — Post-Launch (Future)
*Not blocking v1 ship — track for v1.1+*

- [ ] Android widget (Jetpack Glance) — requires Supabase backend
- [ ] visionOS widget (free if built with iOS 26 SDK)
- [ ] CarPlay widget
- [ ] watchOS relevance widget
- [ ] Genmoji reactions on posts
- [ ] Live Activities for "magnet is heating up" (many posts)
- [ ] AI image generation (DALL-E / Gemini via OpenClaw)
- [ ] Custom on-device models via ai-edge-torch (~/Dev/ai-edge-torch)
- [ ] Monetization: premium agent types, custom themes
- [ ] Transfer repo to groupthinking org

---

## Process Rules (ENFORCED)

### Every phase transition:
1. `xcodebuild build` must pass — no exceptions
2. Manual smoke test on simulator
3. Git commit + push to kk-agent/magnets
4. Update this TODO.md with results
5. Notify Hayden with summary

### For each sub-task:
1. Read existing code before touching it
2. Make the change
3. Build immediately — catch errors at the source
4. Test the specific feature
5. Commit with descriptive message

### Trust but verify:
- Codex/agents write code → KK verifies build → only then it's "done"
- No task is complete until `BUILD SUCCEEDED` is confirmed
- Screenshots or it didn't happen (for UI work)

### Stall prevention:
- OpenClaw watchdog cron re-enables for each phase
- 15-min timeout per agent task — escalate if exceeded
- GitHub Actions chain auto-assigns next issue on PR merge
- Hayden gets Telegram ping on completion OR stall
