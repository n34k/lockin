# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Friction** is an iOS app that blocks distracting apps on a schedule and makes users solve a puzzle to get back in. The core product insight: friction-as-theater, not an unbeatable lock. The mascot/personality is the differentiator; the blocking is table stakes.

## Building & Running

This is a native Swift/SwiftUI Xcode project. All builds and tests go through Xcode or `xcodebuild`.

```bash
# Build all targets
xcodebuild -project Friction.xcodeproj -scheme Friction -destination 'platform=iOS Simulator,name=iPhone 16'

# Run unit tests
xcodebuild test -project Friction.xcodeproj -scheme Friction -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -project Friction.xcodeproj -scheme Friction -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FrictionTests/FrictionTests
```

**Critical:** The Screen Time / FamilyControls entitlement requires a **real device** — the simulator cannot test the blocking loop end-to-end. Entitlement failures surface silently (no crash, just "nothing happens"). Always test the cross-process wiring on hardware.

**Never launch the iOS Simulator.** Do not run anything that boots the simulator or Simulator.app (e.g. `-destination 'platform=iOS Simulator,...'`, `xcrun simctl`) to verify changes. The simulator can't exercise this app's core anyway, and the user verifies on a real device. After editing, stop at "compiles / written to disk." If a build check is genuinely needed, ask first and use a compile-only or real-device destination only.

## Apple Documentation

Use the `apple-docs` MCP server to look up Apple framework APIs rather than relying on training data. The Screen Time APIs (`FamilyControls`, `DeviceActivity`, `ManagedSettings`, `ManagedSettingsUI`) and Foundation Models are the most relevant frameworks for this project and change frequently.

```
mcp__apple-docs__search_symbols   — find a specific class, protocol, or method
mcp__apple-docs__get_documentation — read a symbol's full doc page
mcp__apple-docs__discover_technologies — browse available frameworks
```

## Four-Target Architecture

The Screen Time API forces a four-target structure. All four communicate **only** through the shared App Group (`group.ndenterprises.Friction`) via `UserDefaults(suiteName:)` and shared files. Writing to standard `UserDefaults` instead of the suite is a silent failure.

| Target | Role | Key file |
|---|---|---|
| **Friction** (main app) | SwiftUI UI, onboarding, puzzle/unlock screen, settings | `ContentView.swift`, `UnlockView.swift` |
| **DeviceActivityMonitor** | `intervalDidStart` → apply shield; `intervalDidEnd` → remove shield | `DeviceActivityMonitorExtension.swift` |
| **ShieldConfiguration** | Styles the system block screen (title, subtitle, button labels only — no custom UI) | `ShieldConfigurationExtension.swift` |
| **ShieldAction** | Handles taps on shield buttons; fires a local notification to bounce the user into the main app | `ShieldActionExtension.swift` |

`SharedState.swift` is the single source of truth for the App Group contract — all cross-process reads/writes go through it.

## The Unlock Flow

Shield button tap → `ShieldAction` writes pending token + type to App Group defaults → fires `friction.unlock` local notification → user taps notification → `AppDelegate.userNotificationCenter(_:didReceive:)` reads token from App Group → sets `AppState.shared.showingUnlock = true` → `UnlockView` sheet appears → puzzle solved → `ManagedSettingsStore` shield removed.

`AppState` is the in-process signal bus (`@Published` properties). `SharedState` is the cross-process shared store. They serve different roles — don't conflate them.

## Platform Constraints (design around these)

- **No custom UI on the shield.** The shield is a system screen: only background, icon, title, subtitle, and two button labels. All interactive UI (puzzle, mascot) must live in the main app, reached via the notification bounce.
- **`ShieldAction` cannot open the app directly.** It can only return `.defer`, `.close`, or `.allow`. The local notification is the only bridge.
- **DeviceActivity monitoring is flaky** for threshold/continuous tracking. Prefer schedule-based blocking (`DeviceActivitySchedule` with two wall-clock events per day). Once applied, a shield persists across reboots until removed — only the triggering side is unreliable, not the shield itself.
- **Shield removal is reliable.** `store.shield.applications = nil` is synchronous. The unlock path is trustworthy.

## Planned LLM Layer (not yet built)

Phase 3 will replace the math puzzle with a mascot conversation behind a `MascotBrain` protocol:

```swift
protocol MascotBrain {
    func respond(to userPlea: String, context: MascotContext) async throws -> MascotReply
}
```

Two implementations: `OnDeviceBrain` (Apple Foundation Models, free, default) and `CloudBrain` (Anthropic Haiku 4.5, premium). The protocol is the seam — never couple to a concrete implementation. See `project.md` §3.3 for the full routing logic and `MascotContext` definition.

## Key Files

- `project.md` — full roadmap, architecture decisions, phased plan, and known gotchas (the authoritative design doc)
- `locky.md` — mascot character design: identity, voice, escalation rules, two-version strategy (in-app vs marketing)
- `onboarding.md` — screen-by-screen onboarding design with copy and conversion rationale
- `SharedState.swift` — App Group ID, all cross-process keys, and encode/decode helpers
- `AppState.swift` — in-process observable state (`showingUnlock`, pending token)
