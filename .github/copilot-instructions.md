# Copilot Instructions — Magnets

## Project
Magnets is a shared AI-powered home screen widget app for iOS 26+.

## Tech Stack
- Swift 6.2, SwiftUI, WidgetKit
- CloudKit for sync/storage
- Foundation Models framework for on-device AI
- WidgetPushHandler for APNs push widget refresh
- iOS 26 Liquid Glass design language

## Coding Standards
- Swift 6.2 strict concurrency (Sendable, actor isolation)
- SwiftUI only — never UIKit
- No third-party dependencies
- MVVM-light: Views + Models, no over-engineering
- App Group `group.com.magnets.shared` for widget data sharing
- All SwiftData models must be CloudKit-compatible

## Build Command
```bash
xcodebuild -scheme Magnets -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## File Structure
- `Magnets/` — main app target
- `MagnetsWidget/` — widget extension target
- `Shared/` — shared models and utilities (both targets)

## Key APIs
- `WidgetPushHandler` protocol for push-based widget updates
- `WidgetCenter.shared.reloadAllTimelines()` after data changes
- `Foundation Models` framework for on-device text generation
- `CloudKit` with `CKContainer.default()` for sync

## When Opening PRs
- Verify build passes before opening
- Include screenshots for UI changes
- Reference the issue number
- Keep PRs focused — one feature per PR
