# App Clips + MCP — Idea Notes

**Source:** Hayden's `app-clips.rtf` (2026-03-21)
**Status:** Idea / Future exploration — NOT blocking Magnets core development

## Core Concept
App Clips as **physical-world entry points** into an MCP agent network.
- Scan QR → App Clip opens → triggers MCP agent → returns output
- App Clip = thin client / trigger layer (ephemeral, ~15MB, no background)
- MCP runtime = external (Vercel Edge Functions → agent orchestration)

## Architecture
```
App Clip (UI) → Vercel API Gateway → MCP Agent Runtime → Response → App Clip
```

## Key Constraints (Apple)
- App Clips are ephemeral — killed quickly, no persistent state
- Size limit ~15MB
- No background execution
- No long-lived memory
- Cannot run autonomous agent loops locally

## Low-Hanging Fruit Ideas
1. **QR → Instant Ad Generation** (fastest ROI)
2. **Scan to Build SaaS** (strongest leverage with existing stack)
3. **Lead Capture → Agent Qualification** (immediate monetization)
4. **Scan → Content Engine** (TikTok/Shorts scripts)
5. **Agent Launcher** (AgentSwitch Lite — button grid → MCP calls)

## Relationship to Magnets
- **Separate project** — App Clips are a different distribution mechanism
- Magnets could potentially USE an App Clip for onboarding (scan QR → join magnet)
- But the MCP agent execution platform is a bigger standalone play
- Don't let this sidetrack Magnets core development

## Competition
- Direct: weak/fragmented (Jasper, Copy.ai, Bubble, Replit — none have scan-to-trigger)
- Indirect: Apple could add AI to App Clips; OpenAI/Google circling
- Window: 3–6 months to establish

## Decision
- Filed for future reference
- Focus stays on shipping Magnets Phase 2 → App Store
- Revisit after Magnets v1 ships
