# Phase 2D Spec — Interactive Widgets

## Status
Drafted 2026-03-18.

Phase 2D should ship as a **follow-up to the current Phase 2 PR**, not as part of the already-open branch review unless review feedback explicitly asks for it.

## Recommendation
- **Keep the current Phase 2 PR open** for comments and CI/review.
- **Do not merge blind.** Let comments land, then iterate.
- Build Phase 2D as the next focused PR after feedback on the current branch is absorbed.

Reason: the current PR already bundles 2A + 2B + 2C groundwork and partial 2D deep linking. Adding interactive widget actions now will make review noisier and blur the boundary between "build verified groundwork" and "new widget UX behavior."

---

## What Phase 2D Actually Means

Current TODO says:
- Deep link from widget tap → specific magnet in app ✅
- Widget button: quick-post text directly from widget (iOS 26 interactive) ⏳

Important constraint: **widgets cannot support arbitrary keyboard text entry inline** the way a full app screen can.

So "quick-post text directly from widget" should mean:

> **one-tap preset text actions from the widget**, powered by `AppIntent`, without opening the app.

If we ever want arbitrary freeform text from the home screen, that is a separate feature and likely requires opening the app into a focused composer state.

---

## Existing Groundwork Already In Repo

The repo already contains a strong starting point:

- `widgetURL(entry.destinationURL)` already deep-links into the correct magnet.
- `PostToMagnetIntent` already exists in `ios/MagnetsWidget/Intents/PostToMagnetIntent.swift`.
- That intent already:
  - receives `magnetID`
  - receives `quickMessage`
  - creates a `Post`
  - saves through the shared SwiftData container
  - reloads widget timelines

So Phase 2D is **not** "invent interactive widgets from scratch."
It is mostly:
1. define the widget interaction model,
2. surface buttons in the widget views,
3. make the quick actions configurable enough for v1,
4. verify the interaction path on device.

---

## Product Goal

Let a user post a lightweight update to a Magnet in **one tap from the home screen**.

Examples:
- "On my way"
- "Running late"
- "Love this"
- "GM"
- "Need coffee"

This makes Magnets feel alive even before full OpenClaw agent posting lands in Phase 3.

---

## Scope for v1

### In scope
- Interactive widget buttons for **preset text actions**
- Actions post into the selected magnet without opening the app
- Widget refreshes after action completes
- Deep link tap behavior remains intact for the main body of the widget
- Medium and large widget layouts get action affordances
- Small widget keeps simple tap-through behavior unless layout still looks excellent with one compact action

### Out of scope
- Arbitrary freeform text entry inside the widget
- Photo posting from the widget
- Per-user permissions / moderation logic
- CloudKit sharing completion
- APNs-driven widget push validation
- Agent-authored widget actions

---

## UX Decision

### Widget families

#### Small widget
- Keep current behavior: tap widget → open magnet
- No inline quick-post button in v1 unless it looks obviously clean and not cramped

#### Medium widget
- Show latest post + **1 primary quick action**
- Example action: `Button(intent: PostToMagnetIntent(..., quickMessage: "On my way"))`
- Keep the rest of the card tappable into the app

#### Large widget
- Show recent posts + **up to 3 quick actions**
- Example defaults:
  - On my way
  - Running late
  - ❤️ Thinking of you

### Action style
- Short labels only
- Strong visual affordance, but not louder than the content
- Use system symbols or emoji sparingly
- Avoid turning the widget into a control panel mess

---

## Data / Config Model

For v1, use **default preset quick actions** rather than user-editable per-magnet actions.

### Default preset set
Proposed defaults:
- `On my way`
- `Running late`
- `Love this`

These should be centralized in one shared type, for example:
- `WidgetQuickActionPreset`
  - `id`
  - `title`
  - `message`
  - `symbolName` (optional)

### Why fixed presets first
- avoids premature settings UI work
- keeps review small
- proves the interaction loop before adding configuration complexity
- makes Phase 2D shippable now

### Follow-up after v1
If the interaction works well, Phase 2D.1 can add:
- per-magnet custom presets
- reorder/hide actions in app settings
- one "Open Composer" action for freeform text

---

## Technical Plan

### 1. Formalize quick action presets
Add a shared model for widget quick actions that both widget UI and intent wiring can use.

Suggested shape:

```swift
struct WidgetQuickActionPreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let message: String
    let symbolName: String?
}
```

Add `static let defaults: [WidgetQuickActionPreset]`.

### 2. Extend `MagnetsEntry`
Include the quick actions the widget should render.

Suggested addition:

```swift
let quickActions: [WidgetQuickActionPreset]
```

For v1 this can be populated from static defaults in `Provider.loadEntry()`.

### 3. Wire buttons into widget views
Update the widget family views to render `Button(intent:)` actions.

Use the existing intent:

```swift
Button(intent: PostToMagnetIntent(magnetID: magnetID.uuidString, quickMessage: preset.message)) {
    // action chip UI
}
```

### 4. Preserve deep-link behavior
The widget still needs to open into the magnet when tapping the main content.

Rule:
- content area → `widgetURL`
- explicit action chips/buttons → `AppIntent`

Do not make the interaction ambiguous.

### 5. Add duplicate-tap protection
Guard against accidental rapid re-posts.

Minimum acceptable v1 behavior:
- allow duplicate content, but avoid obvious accidental double-fire if the system dispatches repeated taps quickly

Possible lightweight approaches:
- short client-side cooldown stored in app group state
- or accept duplicates for v1 and document it explicitly

Recommendation: **accept duplicates for v1** unless testing shows a real problem.

### 6. Improve intent result behavior
`ProvidesDialog` is already in place, but the main user-visible confirmation should be the refreshed widget/feed state.

Success condition:
- tap button
- widget refreshes
- new post appears in app feed and widget snapshot

### 7. Verify target membership
Ensure the intent file is included in the widget target correctly and available for interactive widget execution on device.

---

## Acceptance Criteria

Phase 2D is complete when all of the following are true:

1. **Medium widget** shows at least 1 working quick-post action.
2. **Large widget** shows multiple working quick-post actions.
3. Tapping a quick action **does not launch the app**.
4. Tapping the non-button body of the widget still deep-links into the correct magnet.
5. The quick action creates a `Post` in the shared container.
6. The widget refreshes to reflect the new post.
7. Simulator build passes.
8. Manual test passes on a signed-in physical device.

---

## Test Plan

### Build
```bash
cd ~/.openclaw/workspace/projects/magnets/ios
xcodebuild -scheme Magnets -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Manual simulator smoke test
- Launch app
- Create a magnet with at least one post
- Add medium widget
- Trigger quick action
- Confirm app data changes and widget state updates

### Physical device validation
Required because interactive widgets + real home-screen behavior are what matter.

Test matrix:
- medium widget quick action
- large widget quick action
- body tap deep link
- repeated taps
- app cold state vs warm state
- iCloud signed in

### Failure cases to test
- invalid magnet ID
- empty quick message
- no shared data available
- save failure
- widget stale after intent run

---

## PR Strategy

### Current PR
Keep the existing Phase 2 PR open for review.

### Next PR
Open a **separate PR for Phase 2D interactive widgets** once current review comments are absorbed.

Suggested PR title:
- `Phase 2D: interactive widget quick-post actions`

Suggested PR scope:
- widget quick action model
- widget button UI
- intent wiring cleanup
- TODO/spec updates
- build verification notes

This keeps review clean and makes rollback easy if widget interaction behavior is weird.

---

## Open Questions

1. Should small widgets get one compact quick action or remain tap-only?
   - Recommendation: remain tap-only for v1.

2. Should defaults be emotional/social (`❤️ Love this`) or utility/status (`On my way`)?
   - Recommendation: utility/status first. It is easier to demo and more universally useful.

3. Should quick actions be configurable per magnet now?
   - Recommendation: no. Fixed defaults first.

4. Should action presses create timeline-only local state, or full persistent posts?
   - Recommendation: full persistent posts. Otherwise the action is fake.

---

## Recommendation Summary

**Do this next:**
1. leave current Phase 2 PR open,
2. collect comments,
3. iterate on review feedback,
4. then ship Phase 2D as the next narrow PR.

**Do not do this next:**
- merge the current PR blindly,
- or cram interactive widgets into the same review unless a reviewer explicitly wants that bundle.
