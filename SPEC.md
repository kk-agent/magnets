# Magnets — Shared AI Widgets

## Product
Shared home screen widgets powered by OpenClaw agents. Friends post photos/messages to each other's widgets. AI agents are first-class participants — they push content too.

**Tagline:** "Your AI agent lives on your home screen."

## Target
- iOS 26+ (required by App Store April 28, 2026)
- Xcode 26.3, Swift 6.2, SwiftUI, WidgetKit

## Architecture

```
iOS App (SwiftUI)  ──── CloudKit (sync + storage)
       │
Widget Extension   ──── WidgetPushHandler (APNs)
       │
Foundation Models  ──── On-device AI (text gen, summaries)
       │
OpenClaw Gateway   ──── Agent webhook → APNs push
```

## Stack
| Layer | Choice |
|-------|--------|
| UI | SwiftUI + WidgetKit |
| Backend | CloudKit (zero cost, zero ops, iCloud auth) |
| Push | APNs WidgetPushHandler (iOS 26 native) |
| On-device AI | Foundation Models framework |
| Cloud AI | OpenClaw webhook → Edge Function → APNs |
| Auth | iCloud (automatic via CloudKit) |
| Storage | CloudKit Assets (photos/media) |

## Core Features (v1)
1. **Magnets** — shared widget spaces, invite by link/QR
2. **Post to widget** — text, photo, or AI-generated content
3. **Widget sizes** — small (photo/text), medium (photo + caption), large (feed)
4. **Agent slot** — connect OpenClaw agent, posts autonomously
5. **Push refresh** — APNs WidgetPushHandler, seconds not hours
6. **Interactive widgets** — tap to deep-link into app
7. **On-device AI** — Foundation Models for quick content generation
8. **Liquid Glass** — native iOS 26 design language

## Data Model (CloudKit)
- **Magnet** — id, name, ownerRef, inviteCode, createdAt
- **MagnetMember** — magnetRef, userRef, role (owner/member/agent), joinedAt
- **Post** — id, magnetRef, authorRef, contentType (text/photo/ai), textContent, mediaAsset, backgroundColor, createdAt
- **DeviceToken** — userRef, widgetPushToken, updatedAt

## Build Phases
### Phase 1 — Foundation (Week 1)
- Xcode project + widget extension
- CloudKit schema + container
- Basic app: create magnet, post text/photo, view feed
- Widget displays latest post (timeline provider)

### Phase 2 — Push & Sharing (Week 2)
- WidgetPushHandler for APNs push refresh
- Invite links (universal links / QR)
- Multi-member magnets
- Interactive widget (tap → deep link)

### Phase 3 — AI Integration (Week 3)
- Foundation Models: on-device text generation
- OpenClaw agent webhook endpoint
- Agent types: briefing, quote, weather, custom
- Settings: connect/disconnect agent

### Phase 4 — Polish & Ship (Week 4)
- Liquid Glass widget designs
- Photo filters / backgrounds
- Notifications (new post alerts)
- TestFlight → App Store

## Repo
- Local: ~/.openclaw/workspace/projects/magnets/
- GitHub: TBD (groupthinking org or dedicated)

## References
- ~/Dev/AppleDev/BringingAdvancedSpeechToTextCapabilitiesToYourApp/ (Apple sample)
- ~/Dev/AppleDev/ (WWDC25 ML guide, Foundation Models code-along)
- ~/Dev/ai-edge-torch/ (Google AI Edge, for future custom models)
- WWDC25: "What's new in widgets" — WidgetPushHandler, Relevance, CarPlay
- WWDC25: "Bring on-device AI to your app using Foundation Models"
