# Onboarding Design

> **Goal:** By the end of onboarding the user has named their problem, felt the math, configured the app, and _then_ been asked to pay. Paywall comes last — after they've already invested their time and set everything up. At that point they're not deciding whether to try the product; they're deciding whether to keep what they've built.

---

## Philosophy

Most productivity apps front-load the setup (pick your apps, set your schedule) before the user has any emotional reason to care. This onboarding inverts that — but goes further. The paywall isn't just after the emotional moment; it's after the _setup_ is complete. The user has told us their name, confessed their screen time, picked their apps, and set their schedule. Walking away now means losing all of that. That's the buy-in.

The question sequence does two things simultaneously:

1. **Personalizes the experience** — the user feels seen, not processed
2. **Builds the case** — each answer tightens the math that hits them on the impact screen

The tone throughout should match the app: warm enough to feel human, slightly irreverent, never preachy.

---

## Screen-by-Screen Breakdown

### Screen 1 — Name

**Prompt:** "What's your name?"

**Input:** Text field, first name only

**Why:** Personalization increases completion rate and makes every subsequent screen feel like it's talking to them, not at them. Used in copy on the impact screen ("Nick, that's 46 days a year") and the done screen, and optionally in mascot dialogue later.

---

### Screen 2 — Daily Waste Estimate

**Prompt:** "[Name], how much time do you think you waste on your phone each day?"

**Subtext:** "Be honest. We won't judge. (We'll judge a little.)"

**Primary input:** Slider that they can pick any number 0-12+ nours

**Dry reactions (shown as small subtext beneath the input when certain values are typed or selected):**

- 6hrs+: "That's basically a part-time job."
- 8hrs+: "okay. okay."
- 12hrs+: "We're glad you're here."

**Why:** Their own phrasing ("way too much", "more than I want to admit") tells us something about their emotional relationship with the problem — richer mascot fuel than a number alone.

**Parse for math:** Extract a number from free-text for the impact screen. Fall back to chip range if none found. "12+" or unparseable high inputs → use 12.

---

### Screen 3 — What They Do

**Prompt:** "What do you do?"

**Subtext:** "Just so we know what you're supposed to be doing instead."

**Primary input:** Text box — open field. They might write "I'm a nurse", "grad student finishing my thesis", "I work from home but barely work", "stay at home dad." All of this is gold for the mascot.

**Secondary input:** Tap-to-select chips below as quick-fill suggestions (tapping adds to or fills the text box):

- Student
- Work from home
- Office job
- Creative / freelance
- Parent
- Something else

**Why:** "I'm a nurse" gives the mascot something specific to reference. "Office job" gives it nothing. The chips serve users who don't want to type.

**Store as:** full text response + any selected chips, both passed into `MascotContext`.

---

### Screen 4 — Why They're Cutting Back

**Prompt:** "Why are you trying to cut back?"

**Subtext:** "You can just say it."

**Primary input:** Text box — open field. This is the most important free-text capture in the whole onboarding. "I keep picking up my phone when my kid is trying to talk to me" is a completely different mascot brief than "I'm distracted at work."

**Secondary input:** Tap-to-select chips below as prompts, not replacements (tapping appends or fills the box):

- I'm wasting time I don't have
- It's affecting my work / school
- I want to be more present
- It's making me anxious or drained
- I just feel out of control
- Honestly, I'm embarrassed by my screen time

**Why:** The chips serve as permission slips — some users need to see their feeling named before they'll type it. Users who do type something real are the highest-intent users in the funnel, and their words make the mascot feel like it actually knows them.

**Store as:** full text response + any selected chips, both passed into `MascotContext`.

---

### Screen 5 — The Impact Screen _(the moment that sells)_

**Headline:** "[Name], here's what that costs you."

**Math (displayed large, animated counting up):**

```
[X] hours a day
× 365 days
= [Y] hours a year
= [Z] days of your life
```

Example for 3 hours/day:

> **3 hours a day**
> That's **1,095 hours a year.**
> That's **45 days** you'll never get back.

**Follow line (smaller, dry):**

> "That's longer than most people's vacations. Combined."

**The turn:**

> "Friction won't give those days back. But it'll make you actually think before you throw more away."

**Why this works:** The days number is the gut punch. Hours feel abstract; days feel like a life. The snarky follow line releases the tension before it tips into guilt, which keeps the tone on-brand and prevents the user from feeling lectured.

**Do not offer a skip here.** Let the screen sit for 1–2 seconds before the CTA button appears.

**CTA:** "Let's fix it →"

---

### Screen 6 — Permissions + App Setup

Now that they've felt the problem, capture the setup while intent is high. Paywall comes _after_ this — once they've done the work.

**Step A — Notifications**

> "We need to be able to tap you on the shoulder."
> [Allow Notifications]

**Step B — Screen Time / Family Controls**

> "This is the part where you give us the keys."
> [Enable Screen Time Access]

**Step C — Pick Your Apps**

> "What are we keeping you out of?"
> `FamilyActivityPicker` — full screen, no rush

**Step D — Set Your Schedule**

> "When should Friction be on duty?"
> Simple time-range picker. Default: 9am–6pm. Can always change later.

---

### Screen 7 — Paywall _(comes last, after full setup)_

**Why it's here:** The user has now told us their name, confessed their screen time, picked their problem apps, and set their schedule. They've built something. The question now isn't "should I try this?" — it's "should I keep this?" That's a much easier yes.

**Headline:** "You're all set, [Name]."

**Subtext:** "Start your free week. See if Friction changes anything."

---

**Trial offer:**

> **7 days free** — no charge until your trial ends.
> Cancel anytime. We'll remind you before we charge you.

**Notification preference (shown inline):**

> "Remind me to cancel:"
> ○ 1 day before ○ 2 days before ○ 3 days before

This is a trust signal, not just a feature. Showing it _before_ they subscribe communicates that we're not trying to sneak a charge past them. That removes the #1 objection to free trials.

---

**Pricing — shown as a single primary option with a dropdown for alternatives:**

**Default (shown bold, full-width):**

> **$99.99 / year** — 7-day free trial
> _That's $8.33/month. Less than a coffee._

**Dropdown ("See other options →"):**

> $9.99 / month — 7-day free trial

**Why yearly first:** Annual plans have dramatically lower churn. A user who pays $99.99 is 12x more committed than one paying $9.99. Show it first, make it feel like the obvious choice, and let monthly be the "fine, I'll try it" option for the hesitant.

---

**CTA — Primary:** "Start free trial →"
**CTA — Secondary (smaller text below):** "Continue with free version"

**Don't hide the free option.** Users who feel locked in revoke permissions and leave bad reviews. Users who choose free intentionally are more likely to upgrade later.

---

### Screen 8 — Done

> "You're ready, [Name]."
> "Next time you reach for one of those apps, we'll be there."
> [Got it →]

---

## Conversion Notes

- **Paywall at the end is the whole bet.** By Screen 7 the user has a name in the app, their screen time confessed, their apps selected, their schedule set. Leaving means losing all of that. Staying costs $0 for a week. The math is easy.
- **Free-text responses are the mascot's raw material.** A user who typed "I keep checking my phone when my daughter is talking to me" gives the mascot something real to work with. A user who tapped "I want to be more present" gives it a category. Both are useful; one is dramatically better.
- **Chips serve as permission slips, not the answer.** Some users need to see their feeling named before they'll type it. The chips lower the barrier; the text box is where the good stuff comes from.
- **The trial reminder preference is a conversion feature.** It signals honesty, removes the "I'll forget and get charged" fear, and increases trial starts. More trial starts = more conversions.
- **Don't make free feel crippled.** Premium is "sharper mascot," not "unlock core features." Users who feel the free tier is fake churn and leave bad reviews.
- **Yearly pricing anchors the value.** "$8.33/month" feels like a bargain after "$9.99/month" is visible in the dropdown. Show yearly first, always.
- **The name pays off twice** — impact screen and done screen. Those are the two highest-emotion moments. If you only personalize two places, it's those.
- **High screen time = high intent.** Users who type or select 6hrs+ have the strongest reaction to the days calculation. The dry reaction copy for 8hrs+ acknowledges it without shaming — that keeps them in the flow.

---

## Data Collected & Where It Goes

| Field                              | Used in                                                                                                              |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Name                               | Impact screen, done screen, mascot context                                                                           |
| Daily waste (text + parsed number) | Impact screen math; number + exact phrasing passed to mascot — lets it say "you said you waste 4 hours a day"        |
| What they do (text + chips)        | Impact screen copy variation; mascot knows their job/life context                                                    |
| Why cutting back (text + chips)    | Mascot system prompt; personalized shield copy (future)                                                              |
| Selected apps / categories         | Blocking; also passed to mascot — it knows you're trying to get into Instagram specifically, not just "social media" |
| Trial reminder preference          | StoreKit / local notification before trial end                                                                       |
| Schedule                           | `DeviceActivitySchedule`                                                                                             |

---

_Last updated: June 2026._
