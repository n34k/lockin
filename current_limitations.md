# Current Limitations

A running log of platform constraints we've hit that are **not bugs in our code** —
they're hard limits imposed by Apple's frameworks. Document them here so we stop
re-investigating the same dead ends.

---

## 1. We cannot pass the blocked app's name into the mascot's LLM context

**Status:** Confirmed not possible (June 2026). Closed.

### What we wanted

When the user hits the shield and starts the unlock conversation, give Locky the
name of the app they're trying to get back into ("trying to sneak back into
**Instagram**, huh?"). This means getting the app's display name as a **String**
inside our process so we can put it in the prompt.

### Why it's not possible

The Screen Time / FamilyControls framework is built around a deliberate privacy
wall. Apps are identified by **opaque tokens** (`ApplicationToken`,
`ActivityCategoryToken`) — not bundle IDs, not names. Apple's explicit design goal
is that a blocking app like ours should **never be able to learn which apps the
user has selected or blocked**. The name simply is not available to our code as a
readable string. The system will _display_ it for us, but never _hand it to us_.

We tried every available avenue. All of them fail:

#### Avenue A — `Application.localizedDisplayName` / `Application.bundleIdentifier`

The `Application` struct exposes `localizedDisplayName` and `bundleIdentifier`
properties, so on paper this looks like the answer. In practice both return `nil`
under our authorization mode.

- We use **`.individual`** FamilyControls authorization (a person controlling their
  own device — no Family Sharing child account). Under this mode the system
  **redacts** these properties. They come back `nil`.
- This is true **even inside `ShieldConfigurationExtension`**, where we receive a
  full `Application` object. `application.localizedDisplayName` is `nil` there too
  in current iOS versions.
- Apple's documentation lists these properties with **no caveat**, which is what
  sends everyone down this path. The redaction is undocumented behavior.

> Our `ShieldConfigurationExtension` still _attempts_ this and writes the result to
> the App Group. It's harmless and would opportunistically work if Apple ever
> populated it — but in practice it writes nothing.

#### Avenue B — Render `Label(token)` and OCR it

SwiftUI's `Label(ApplicationToken)` _will_ display the real app name on screen.
The idea: render that label to an image, then run Vision OCR to recover the string.

This fails because of **how** the system renders it. `Label(token)` does not draw
the name from our process — the system composites the name and icon **out of
process** (a privacy "portal" / remote view). Consequences:

- **`ImageRenderer` (offscreen snapshot):** only captures _our_ process's view
  tree. The portal content isn't in our address space, so the snapshot comes back
  **blank**. OCR sees nothing → `nil`. (This was our original `AppNameResolver`.)
- **`drawHierarchy(in:afterScreenUpdates: true)` on a window-attached `Label`:**
  this forces an on-screen update pass and _can_ pull portal content into a bitmap
  in some cases, but for FamilyControls tokens it is unreliable — the portal
  frequently doesn't composite into a programmatic capture, and timing is
  nondeterministic. Not dependable enough to ship. (We prototyped this and backed
  it out.)

The cruel detail that makes this feel solvable: the **on-screen** `Label(token)` in
our unlock UI (e.g. the toolbar in `UnlockView`) renders the name perfectly,
because that goes through the live window where the system _does_ composite the
portal. So we can _see_ the name on screen while our code can never _read_ it. That
visual success is what makes the OCR path look promising — but it's the live window
doing the work, not anything we can capture.

### What actually works (and what doesn't)

| Capability                                                    | Works?                                  |
| ------------------------------------------------------------- | --------------------------------------- |
| **Display** the app name/icon on screen via `Label(token)`    | ✅ Yes                                  |
| Read the app name as a `String` in our process                | ❌ No                                   |
| Get the bundle identifier                                     | ❌ No (redacted under `.individual`)    |
| Persist/compare the same app across launches (token equality) | ✅ Yes (tokens are stable & `Hashable`) |

So we can show the user _which_ app is blocked (visually), and we can tell _whether_
two tokens are the same app — we just can't know the human-readable name in code.

### Current behavior in the app

The unlock prompt builders (`buildOpenerPrompt`, `buildUnlockPrompt` in
`MascotBrain.swift`) guard the app-name line behind `if !context.appName.isEmpty`.
Because `appName` resolves to `""` in practice, **that line is simply omitted** and
Locky talks about "the app" generically. Everything else in the context (schedule
name, the user's stated block reason, unlock count, user profile) is fully
available and _does_ reach the prompt — those don't depend on the token.

### If we ever revisit

Only worth reopening if one of these changes:

1. **Apple lifts the redaction** for `.individual` authorization in a future iOS
   (unlikely — it's a core privacy stance, not an oversight).
2. **We capture the name at selection time, indirectly.** When the user picks apps
   in `FamilyActivityPicker`, we still only get tokens — but we _could_ ask the /user
   to name/label their own block in onboarding, and key Locky's references off that
   user-supplied label instead of the real app name. This sidesteps the limitation
   entirely by never needing the real name.
3. **Pivot the copy** so the missing name is invisible — lean on the schedule name
   and the user's own stated reason, which we _do_ have.

Option 2 is the realistic path if app-specific personality ever becomes important.
