# Demo operational workflows audit — #3291

Run 2026-11-04 on master `f75677088` plus this change, in the in-memory Demo (`lib/core/demo`), through the scope a
visitor uses: `DemoFixture` plus `demoOverrides` (the routed per-space repositories), entering each space with
`activeWorkspaceIdProvider`. Every row is pinned by `test/core/demo/demo_workflow_audit_test.dart` unless it names
another test. Expectations are the product contract — `respond_to_event` (0101; the reservation rule of 0113), the
live `calendar_items` read, per-space isolation — not the fake's own bookkeeping. Persona: the owner (Ada) unless
stated; persona permissions and attribution are #3293's matrix (`DEMO_PERSONA_MATRIX.md`, PR #3297), not repeated here.
Spaces: Pézenas `ws-1` (FR, EUR), Leipzig `ws-2` (DE, EUR, a new workspace's defaults), London `ws-3` (GB, GBP),
New York `ws-4` (US, USD), the development twin `ws-1-dev`.

## Matrix

| Subprocess | Space | Persona | Initial state | Action | Expected | Observed (before → after) | Evidence |
|---|---|---|---|---|---|---|---|
| Reservations: book | all four | owner | a free seat a week ahead | book a morning | stored by that space only; on the day's plan; in the calendar at once | plan ✓; **calendar did not show it** (seeded once at build) → shown | `reservations: …` ×4 |
| Calendar after a booking, as the screen reads it | Pézenas | owner | `calendarItemsProvider` watched | book, then the app's own mutation path (`invalidateBookingData`: the providers the realtime map names for `reservations`, `events`, `ledger_entries`) | the refetched range holds the booking | **the refetch answered the seed** → holds it | `the open calendar shows a booking …` |
| Reservations: move | all four | owner | the booking above | move to the afternoon | plan and calendar at the new time | **calendar kept the old time** → follows the move | same |
| Reservations: cancel | all four | owner | the moved booking | cancel | status cancelled on plan and calendar | **calendar still read it reserved** → cancelled | same |
| Payment journey | Pézenas | owner | Bruno's account | record a payment, then confirm it | a pending `payment` request (record_payment, 0070), no credit before the decision; one payment credit dated the day paid after it (0101) | **the returned event id named no event; nothing was credited** → filed, then credited | `a recorded payment files …` |
| Decisions: reservation deletion | Pézenas | owner | Bruno's pending request on `demo-past` | approve | request confirmed; the booking cancelled | **booking stayed active** → cancelled | `an approved reservation deletion …` |
| Decisions: join | Pézenas | owner | Dov (`member-4`) pending | approve / refuse | member active / exited | **member stayed pending** → active / exited | `an approved join …` |
| Decisions: room request | Pézenas | owner | Bruno's room held for a validator | refuse | request rejected; the room freed | **room stayed booked** → cancelled | `a refused room request …` |
| Decisions: expense, service | Pézenas, London, New York | owner | pending expense and service requests | approve both | expense credited, service charged (unit price × quantity, #2860), in the space's own account | **nothing reached the account** → one credit, one charge | `… an approved expense …` ×3 |
| Decisions: quota, price negotiation | all with one pending | owner | pending | approve | request confirmed | confirmed; the Demo holds no quota-extension or negotiated-price store, so nothing further changes | exclusion (below) |
| Calendar amounts | London, New York | owner | seeded | read a year either side | every amount in the space's currency | **payments and scheduled expenses said EUR** → GBP / USD | `each city's calendar …` |
| Workspace switching | all four | owner | seeded | enter each, then back in reverse | each reads its own requests; nothing changes by switching | as expected | `switching spaces …` |
| Reset after mutations | London, Pézenas | owner | a London booking, an approved join | reset the session | every space back to the canonical dataset | as expected | `reset after mutations …`; `demo_session_test` |
| Catalogue per space | all spaces | — | the effective features (`effectiveFeatures` of each space's flags and country) | every subprocess of `workspaceProcesses` | an effective capability, or a stated reason | Leipzig: 5 steps off, reasoned; others all on | `every subprocess …` |
| Every step has a scenario | Pézenas | per scenario | seeded | — | each capability has a Demo scenario or is left off with a reason | as expected | `demo_scenarios_test` |
| Development twin | `ws-1-dev` | owner | listed in the visitor's spaces, entered from Me | enter it | a development workspace of its own | **every routed provider in error ("unknown demo space")** | follow-up **#3302** |
| Twin: deployments | Pézenas | owner | three deployments, one rolled back | read the board and journal | both readable from production | as expected | `demo_scenarios_test` (deployments, environmentPairs) |

## Exclusions and reasons

- **Leipzig** `billingPayments/collection`, `billingPayments/expenses`, `billingPayments/tax`,
  `documentsInformation/reportDesign`, `reservationsUsage/attendance`: Leipzig carries exactly a new workspace's
  defaults (`defaultFeatureFlagsForNewWorkspace`, pinned by `demo_second_space_test`), so the Demo shows a fresh,
  basic space beside the full one.
- **Quota extensions and negotiated prices**: the decision is recorded and the request confirmed; the Demo has no
  quota-extension or negotiated-price store and no screen reads one, so the server's insert has nothing to land in.
- **No Demo realtime**: the Demo's change feed never emits (`FakeRealtimeSync`), so a screen refreshes after the
  session's own mutation path invalidates it (as above), not because another device changed a row; the Demo has one
  session, so no second device exists to change one.
- **Backend-only enforcement** (RLS, triggers' refusals) is not re-proved in memory (ADR 0028, the issue's non-goal).
- **Kiosk, check-in/out, book-for-others, cancel-for-others** gates and attribution: #3293 (PR #3297) fixed and pinned
  them; not duplicated.
- Coordination: #3287 (core UX validation with unassisted tasks) and #3235 (configuration examples) are not
  duplicated: this audit runs at the repository/scope level, they on screens.

## Fixed in this change

- `lib/core/demo/data/decision_effects.dart` (new) and the `onDecided` hook of `FakeEventRepository`, wired in every
  space: a decided request now changes what `respond_to_event` changes.
- `DemoMemberAccountCommands.recordPayment` files the pending `payment` request record_payment files, and its
  confirmation credits the member (`decision_effects.dart`).
- `FakeCalendarRepository.beforeRead` and `seedDemoCalendar`: the calendar rebuilds from the space's live stores on
  each read (as `calendar_items` reads the tables), and states amounts in the space's currency; a checked-in booking
  is no longer listed twice.
