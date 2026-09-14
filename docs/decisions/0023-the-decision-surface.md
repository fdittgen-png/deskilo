# ADR 0023 — The administrator's home is a list of decisions, not a dashboard

**Status:** proposed · **Date:** 2026-09-14

## Context

#1247 is the counterweight to the rest of the #1225 programme: the
backend gets more sophisticated and the interface has to get *less*. It
proposes a decision-oriented surface for the administrator, and it says —
correctly — that this wants a design pass before code.

It also names the measurement, and that part is now done.
`test/ux/tap_budget_test.dart` counts the two paths the issue asks for,
as a build output with a ratchet:

| path | taps today |
|---|---|
| app open → **booked** | **2** — tap the seat, confirm the sheet |
| app open → **a decision made** | **1** — the pending thing is pinned, Accept |

Both exclude the tap that opens the destination, because the app boots
onto the Reserve hub and the bell badge already sends somebody who has
something waiting. Both assert the action actually completed: a tap
budget over a path that does not finish measures nothing.

**So the member's path is already short**, and the issue's own list
agrees — the Money faces, the invoice journey strip, the "your move"
line, the closed-day banner, the Features search, the editor losing two
of six tools all landed this cycle.

What is long is the *administrator's*, and the numbers above do not show
it, because they measure the path once you already know where to go. The
administrator's real cost is **finding out that something needs
deciding** across 59 screens and 100 feature flags, and no tap count
starting from the right screen can measure that.

## Decision

**Propose**, for the design pass rather than for implementation now:

1. **One surface, ranked, and nothing on it that does not need an
   action.** The discipline is the design, not the widget. A card that
   says "23 occupied · 4 free" is information; it belongs on the plan,
   where somebody went to look at occupancy. A line that says "3
   reservations need a decision" is an action, and it belongs here.

2. **It reads from what already exists.** `myPendingEvents` drives the
   bell badge, the overdue banner is on the Money face, occupancy is on
   the plan, and `reconcile_workspace()` (0213) answers "is the money
   wrong" in one call. Nothing new has to be computed; what is missing is
   the one place that *ranks* them.

3. **The ranking is by consequence, not recency.** Money that is wrong
   outranks a booking that needs approving, which outranks a member
   waiting to join. A feed sorted by time makes the administrator do the
   ranking, which is the work we are trying to remove.

4. **The measurement moves with it.** When the surface exists, the second
   number becomes *app open → a decision made* **without knowing where to
   look**, which is the number that is actually bad today. The budget in
   `tap_budget_test.dart` is raised to whatever that costs on the day it
   lands, and then ratcheted down. A budget that only ever measured the
   easy path would make the redesign look like a regression.

5. **Nothing is removed to make room for it.** The tabs stay. This is an
   entry point, not a replacement, and an administrator who wants the
   ledger goes to the ledger.

## Consequences

- The UX score exists and has a baseline (2 and 1). It is in the suite
  and it ratchets, so a feature that quietly adds a step to booking fails
  a test rather than being noticed a release later.
- This ADR is **proposed**, not accepted: the design pass is the next
  step and it will change some of the above. Recording it now means the
  redesign starts from a stated position rather than from a blank page,
  which is what #1249 asked for when it said the architecture decision
  should arrive *before* the code.
- The counter deliberately does not count scrolling. Scrolling is a cost,
  but a redesign that replaced three taps with one long scroll would
  otherwise score as an improvement.
