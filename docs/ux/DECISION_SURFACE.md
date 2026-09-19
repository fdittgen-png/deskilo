# The decision surface — design pass

**#1247** · design before code, as the issue asks · 2026-09-19

## What it is

One place that answers *does anything need me?* — and, when the answer
is no, says so and gets out of the way.

Not a dashboard. The difference is a rule, not a style:

> **A line appears here only when a person must decide or act.** A number
> nobody can act on is information, and information belongs to the screen
> that owns it.

`23 occupied · 4 free · 2 no-shows` is a lovely sentence and nothing on
it is a decision. It stays on the plan.

## The inventory: what could appear, and whether it may

Every candidate signal that exists on master today, with the provider
that already computes it. The last column applies the rule.

| signal | where it lives today | actionable? |
|---|---|---|
| events awaiting **my** decision (payments, deletions, role changes, membership) | `myPendingEventsProvider`, the bell badge, the alerts face | **yes** — the decision is the whole point |
| members with `status = pending` (join requests) | Members screen, `MemberStatus.pending` | **yes** — somebody must admit or refuse them |
| invoices a reminder is due on | `remindPlan` (dunning rules, levels) | **yes** — send it or decide not to |
| the month's members with billable data and no invoice yet | the invoicing wizard's *To invoice* | **yes** — issue or skip, once a month |
| a payment recorded by one side, unconfirmed by the other | `record_payment` → the event it creates (0017) | **yes** — confirm or dispute |
| an instance whose schema is behind the app | `deskilo_schema_version` vs `requiredSchemaVersion` | **yes**, for an owner — upgrade it |
| doctor findings on a self-hosted instance | the Server screen | **yes**, for an owner |
| a capability switched on but held back by a prerequisite | `processStatuses` → *Needs attention* | **yes** — switch the prerequisite on, or accept |
| occupancy, free seats, no-shows | the plan, the day timeline | no — nothing to decide |
| the workspace's balance, this month's usage | the Money faces | no — it is a fact, not a request |
| unread messages | the messages hub, its own badge | no — reading is not deciding; the hub already says |
| template updates available | the library | no — an offer, not a request; it waits |

Eight rows in, four out. That ratio is the design: a surface that ranks
everything ranks nothing.

## Ranking

By **what the delay costs**, never by recency:

1. **Money that leaves** — a payment awaiting confirmation, a reminder
   due today under the rules. Delay costs the space cash or the member
   an unfair reminder.
2. **A person waiting** — a join request, a deletion request, a role
   change. Somebody is blocked on an answer.
3. **A month that closes** — members to invoice, after the month ends.
   Costs nothing today and everything on the last day.
4. **The instance** — a schema behind the app, a doctor finding. Rare,
   and an owner's decision.
5. **Configuration that is not doing what it says** — a capability held
   back by a missing prerequisite.

Within a rank, oldest first: a request that has waited three days
outranks one that arrived this morning.

## What a line says

Three parts, in this order, and nothing else:

* **who or what** — the member's name, the invoice's number, the room;
* **the decision** — *accept or decline*, *send the second reminder*,
  *issue for 7 members*; a verb, never a noun-phrase status;
* **since when** — *waiting 3 days*. The cost of delay is the only
  ranking the reader can check.

The line IS the button: one tap reaches the decision, with the thing on
screen. No detail page in between.

## What it never does

* **Never a count without its names.** "3 things need your attention" is
  the summary *above* the list, never the list.
* **Never a badge on an empty surface.** When nothing needs a person,
  the surface says so in one sentence and offers nothing to tap.
* **Never an item somebody else already took.** The list reads
  permissions: an admin without `manageMembers` is not shown join
  requests. What a person cannot act on is not their decision.
* **Never a second source of truth.** Every line is a view over a
  provider that already exists; the surface computes ranking, not facts.
* **Never a notification.** This is a place a person looks, not a thing
  that interrupts them. Pushes stay where they are (#1035).

## Where it lives

The shell's first destination for whoever has decisions, reached in **one
tap** from app open — the budget `test/ux/tap_budget_test.dart` already
measures for a pending decision (1 with the bell, 2 without). The
surface must not make that worse: *app open → decision made* stays at
**≤ 2 taps**, and a new row in `docs/ux/JOURNEYS.md` measures *app open →
the list of what needs me*, budget **1**.

## The ritual this needs

* a `WorkspaceFeature` — the house rule, and the honest one here: a space
  with two members and no invoicing does not want a decision surface. It
  is Platform, default off, and the registry pin moves with it;
* `featureManifest.requires`: nothing — each row's own capability already
  gates its data, and a surface that needs every feature to be useful is
  the wrong surface;
* `workspaceProcesses` — under *Operations & administration*;
* ARB ×5, `web/setup.html`, the guides ×5 and a help anchor;
* tests: the ranking (a fixture with one of each row, asserted in order),
  the permission trim, the empty state, and the two tap budgets.

## Open question for the product

Does this **replace** the alerts face behind the bell, or sit beside it?
Replacing it is the honest answer — two places that rank the same
requests will disagree the week somebody adds a row to one of them —
but it changes a surface members already use, so it is a decision to
take deliberately rather than by implication.
