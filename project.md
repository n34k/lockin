# PROJECT.md — Friction-App Roadmap

> **Working title:** _TBD_ (the name "Friction" is already taken on the App Store as of ~3 months ago — see Open Decisions).
> **One-liner:** An iOS app that blocks time-wasting apps on a schedule and makes you _earn_ your way back in through a deliberately effortful, slightly humiliating ritual — culminating in a sassy AI mascot you have to grovel to.

---

## 1. North Star

The product is **friction, not lockdown.**

The bar is never "make it impossible to get back into Instagram." Apple guarantees the user can always back out of restrictions they set on themselves (revoke Screen Time permission, or delete the app). That ceiling is fixed by the platform and we don't fight it.

The bar is: **enough activation energy that you don't cave on autopilot.** Just having the thing installed creates the friction you signed up for. Dismantling it takes conscious, deliberate effort — and that's the whole point.

**Differentiation is personality, not mechanism.** Anyone can build "block app, add friction." Nobody's moat is the blocking. The market is crowded with earnest, wellness-coded, calm-gradient apps. Our wedge is a _funny, antagonistic, genuinely entertaining_ character. The mascot is the product; the blocking is table stakes.

---

## 2. Product Principles (non-negotiables)

1. **Friction is theater, not a vault.** The mascot always lets you in _eventually_. The friction is the awkward, effortful ritual of getting there — not an unbeatable lock.
2. **Never a real gatekeeper.** If the mascot is persuadable, we've built something _easier_ to bypass than a password. If it's an immovable wall, people rage-quit and delete. The resolution: you always get in, but you feel stupid doing it.
3. **Cute form + sharp tongue.** The contrast is the comedy. A character that looks mean and acts mean is just hostile. Disarmingly adorable + withering = lovable.
4. **Don't market it as unbreakable.** People enjoy breaking security claims. Theater is shareable. Users trying to jailbreak the mascot IS the viral loop — lean into it with memeable refusals.
5. **The LLM is swappable from day one.** On-device (free) ↔ cloud (premium) must be a one-line swap behind an abstraction, never a rewrite.

---

## 3. Architecture Overview

### 3.1 The four-target structure (forced by the Screen Time API)

| Target                              | Role                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------- |
| **Main app** (SwiftUI)              | Onboarding, app selection, schedule config, the puzzle/mascot UI, settings |
| **DeviceActivityMonitor extension** | Receives `intervalDidStart` / `intervalDidEnd`; applies/removes the shield |
| **ShieldConfiguration extension**   | Styles the block screen (background, icon, title, subtitle, 2 buttons)     |
| **ShieldAction extension**          | Handles taps on the shield's buttons                                       |

All four communicate **only** through a shared **App Group** container (shared `UserDefaults` suite + shared files). This is the contract; get it wrong and things fail _silently_.

### 3.2 Hard platform constraints (design around these, don't fight them)

- **You cannot render custom UI on the shield.** It's a system screen — only background, icon, title, subtitle, and two button labels. No puzzle, no mascot, no interactive view lives here.
- **You cannot open your app from the shield action.** The extension can only return do-nothing / close / defer. **Workaround:** the shield button fires a _local notification_; the user taps it; that launches the app; deep-link straight to the puzzle/mascot.
- **DeviceActivity monitoring is flaky** for continuous/threshold tracking (throttled, delayed, silently dropped). **Mitigation:** prefer _schedule-based_ blocking (two wall-clock events/day) over usage-threshold tracking. Once a shield is applied it persists on its own across reboots until removed — so we only need two reliable events per day, not 8 hours of babysitting.
- **Shield removal is the reliable half.** `store.shield.applications = nil` is synchronous and dependable. The unlock is trustworthy; only the _monitoring_ side is shaky.
- **Can't fully test in the simulator.** Real device required. Entitlement problems specifically surface at the TestFlight step.

### 3.3 The swappable LLM layer (the part that matters long-term)

Everything in the app talks to **one protocol**, never to a concrete model. The mascot feature has no idea whether it's running on-device or in the cloud.

```swift
// The single seam the whole app depends on.
protocol MascotBrain {
    func respond(to userPlea: String, context: MascotContext) async throws -> MascotReply
}

struct MascotContext {
    let appBeingRequested: String?   // opaque token label, may be unknown
    let timeOfDay: Date
    let pleaCountToday: Int          // escalate sass with persistence
    let history: [MascotTurn]        // multi-turn within one unlock attempt

    // Populated from onboarding — passed into system prompt
    let userName: String?
    let dailyWasteHours: Double?     // parsed number from their estimate
    let dailyWasteQuote: String?     // their exact words ("way too much")
    let occupation: String?          // their typed response
    let reasonForCuttingBack: String? // their typed response
    let blockedAppNames: [String]    // human-readable labels of blocked apps/categories
}

struct MascotReply {
    let line: String                 // the witty/sassy text shown to the user
    let verdict: Verdict             // .stillBlocked, .grantAccess, .grantWithGuilt
}
```

Two implementations behind it:

- **`OnDeviceBrain`** — Apple **Foundation Models** framework. Free, offline, private, no API key, no per-token cost. ~3B-param model. Apple explicitly lists _on-the-fly character dialog for games_ as a supported use case, which is exactly our mascot.
- **`CloudBrain`** — Anthropic **Haiku 4.5** via API (`$1 / $5` per Mtok, ~90% off cached system prompt). Sharper wit; used for the premium tier and as a fallback on devices that can't run the on-device model.

**Routing** picks the implementation at runtime:

```
if !deviceSupportsAppleIntelligence { use CloudBrain }   // iPhone 15 Pro+ required for on-device
else if user.isPremium               { use CloudBrain }   // premium pays for sharper mascot
else                                 { use OnDeviceBrain } // free default, $0 to run
```

**iOS 27 bonus (WWDC 2026):** Apple opened the Foundation Models framework to cloud providers. Anthropic/Google ship Swift packages so Claude/Gemini are callable through the _same_ `LanguageModelSession` API. This makes on-device ↔ cloud a near-literal one-line swap and reinforces this whole design. Keep `MascotBrain` as our own seam anyway (don't couple directly to Apple's protocol) so we stay portable.

---

## 4. Phased Roadmap

### Phase 0 — Foundations & Unblocking

**Goal:** Remove the things that can't be rushed later.

- [ ] **Submit the Family Controls (Distribution) entitlement request immediately** — for _all four_ bundle IDs (app + 3 extensions), not just the main app. Expect anywhere from a few days to 4+ weeks; opaque process, often no confirmation. Do this before writing meaningful code; there's no reason for the clock to run _after_ dev work instead of during it.
- [ ] Keep developing with the **Development** entitlement (no approval needed) on a real device.
- [ ] Stand up the Xcode project: 4 targets + App Group + entitlements.
- [ ] Swift ramp: lean on C#/TS instincts. SwiftUI ≈ React (`@State` ≈ `useState`). Main new concept: ARC / `weak` refs.
      **Done when:** project compiles with all four targets wired to a shared App Group, and the entitlement request is filed.

### Phase 1 — Core Blocking Loop (MVP, no puzzle, no mascot)

**Goal:** Prove the cross-process wiring is sound. This is the riskiest plumbing; everything else bolts onto it.

- [ ] Onboarding: personalized question flow → impact screen → paywall → Family Controls auth + `FamilyActivityPicker`. Full design in [`onboarding.md`](onboarding.md).
- [ ] `DeviceActivitySchedule` for a work-hours window (e.g. 9:00–17:00).
- [ ] Monitor: `intervalDidStart` → apply shield; `intervalDidEnd` → remove shield.
- [ ] Custom shield text via ShieldConfiguration.
- [ ] A button on the shield that removes the shield (temporary, for testing the round-trip).
      **Done when:** pick one app → it shields on schedule → shield shows → a tap lifts it → it re-shields next window. Survives app kill / reboot.
      **Why first:** the wiring breaks _silently_ (wrong App Group ID, writing to standard vs suite UserDefaults, an extension reading state never shared to it). No crash, just "nothing happens." Build trust in the frame before adding features.

### Phase 2 — Friction Unlock v1 (puzzle)

**Goal:** Validate that the _core behavior change_ is real and retains — on the cheap mechanism, before spending on personality.

- [ ] Shield primary button → fire local notification ("Tap to unlock").
- [ ] Notification tap → launch app → deep-link to puzzle screen.
- [ ] Puzzle complete (your own validation) → remove shield → user reopens target app.
- [ ] Keep re-lock rule **dumb**: unlocked until the next day boundary, re-shield then. No precise time-boxed re-locks yet (that's where DeviceActivity flakiness bites).
      **Done when:** the full bounce works reliably and people actually stay blocked / come back. If a dumb math puzzle doesn't change anyone's habits, a witty AI won't either — learn this cheaply here.

### Phase 3 — The Mascot (swappable LLM)

**Goal:** Replace "the puzzle is the friction" with "the conversation is the friction." Same architecture — just what's at the end of the tunnel.

- [ ] Define `MascotBrain` protocol + `MascotContext` / `MascotReply`.
- [ ] `OnDeviceBrain` via Foundation Models as the default. Test whether the 3B model is _funny enough_ — this single question decides whether cloud is even necessary.
- [ ] Mascot conversation UI in-app (post-notification-bounce).
- [ ] Sass escalates with `pleaCountToday`. Always grants eventually.
- [ ] Per-conversation length cap (protects margin + keeps it from being a real wall).
      **Done when:** you can argue with the mascot, it's entertaining, and it always lets you in after effort — with zero network calls on a supported device.

### Phase 4 — Monetization & Premium

**Goal:** Turn the swappable layer into a business.

- [ ] `CloudBrain` (Haiku) wired behind the same protocol.
- [ ] Premium tier ($10/mo) = "smarter mascot" routed to cloud for sharper wit; on-device mascot stays free.
- [ ] Paywall + StoreKit subscription.
- [ ] Enroll in **Apple Small Business Program** (15% cut under $1M/yr).
- [ ] Per-user rate limiting on cloud calls (the obsessive whale costs ~10x average — cap it).
- [ ] Store cloud API credentials in Keychain, never plaintext.
      **Done when:** free tier costs ~$0 to run; premium converts and its inference cost stays a single-digit % of net revenue.

### Phase 5 — Virality & Growth

**Goal:** Make people _want_ to screenshot it.

- [ ] Lean into jailbreak attempts — give the mascot a strong, memeable personality + brilliant refusals.
- [ ] Ludicrous / escalating puzzle modes as shareable content.
- [ ] Easy share of funny mascot exchanges.
- [ ] Do **not** market as unbreakable.
      **Done when:** organic shares are a measurable acquisition channel.

### Phase 6 — Backlog / Future

- Hybrid blocking: schedule defines _when_ rules are live; optional usage-threshold nuance _inside_ the window.
- Multiple mascot characters / personalities.
- Streaks, stats, "how much you groveled this week."
- Android (entirely different platform model — far future).

---

## 5. Monetization Model (summary)

- **Freemium.** On-device mascot = free (zero marginal cost, works offline). Cloud "smarter mascot" = $10/mo premium.
- **Apple's cut:** 15% via Small Business Program.
- **Unit economics (cloud, 1k paying users @ $10):** ~$10k gross → ~$8.5k net. Cloud inference at a "healthy average" (~5 unlock convos/user/day, ~half a cent each) ≈ **~$750/mo, ~9% of net.** Doubles to ~18% under heavy use. Margin stays healthy.
- **Tail risk:** the 1% of whales. Cap conversation length / make the mascot terser after N exchanges.

---

## 6. Known Risks & Gotchas (the landmine map)

- **Entitlement timeline is unpredictable & opaque.** File for all 4 bundle IDs up front. If it black-holes past a few weeks, escalate via a code-level support (DTS) ticket with your team ID.
- **On-device LLM device requirement:** iPhone 15 Pro or later / M-series only. Older devices need the cloud fallback (or the mascot is gated to capable hardware).
- **On-device wit ceiling:** 3B model is clever-ish, not Claude. For a personality-driven product this gap may matter — validate early.
- **Silent cross-process failures** are the #1 debugging pain. Discipline the App Group contract: document who writes what, who reads what, when.
- **DeviceActivity flakiness:** keep scheduling dumb; don't ask it to babysit precise timers.
- **The bypass ceiling is permanent:** Settings-revoke and app-deletion always exist and don't touch the puzzle/mascot. Accept it; design for "conscious effort," not "impossible."
- **No simulator testing**; entitlement issues appear at TestFlight.
- **Mascot persuadability:** never let it be a real gate (too-easy = anti-friction app; too-hard = rage-quit).

---

## 7. Open Decisions (parking lot)

- **App name** — "Friction" is taken. Need a name that signals the funny/antagonistic angle.
- **Mascot design** — **decided: Locky, a small animated lock.** Full character design in [`locky.md`](locky.md). Art direction (expression range, animation style) still TBD.
- **Mascot voice spec** — **decided: disappointed father, not roast comedian.** Empathy-first, escalates to judgment with repeat unlocks, always grants access eventually. See [`locky.md`](locky.md) for escalation rules and voice guidelines.
- **Puzzle types** (for v1 friction and as a fallback/alt mode).
- **Re-lock timing rules** beyond the dumb day-boundary default.

---

## 8. Tech Stack

- **Language/UI:** Native Swift + SwiftUI.
- **Screen Time:** FamilyControls, ManagedSettings, DeviceActivity, ManagedSettingsUI.
- **LLM:** Apple Foundation Models (on-device, free) + Anthropic Haiku 4.5 (cloud, premium/fallback), both behind the `MascotBrain` protocol.
- **State sharing:** App Group (shared UserDefaults suite + files).
- **Payments:** StoreKit subscriptions + Apple Small Business Program.
- **Secrets:** Keychain for any cloud API credentials.

---

_Last updated: June 2026. This doc is the source of truth for the project's direction — update the phases and open decisions as they resolve._
