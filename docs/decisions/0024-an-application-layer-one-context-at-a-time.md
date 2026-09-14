# ADR 0024 — An application layer, one context at a time

**Status:** accepted · **Date:** 2026-09-14

## Context

#1234 counted it precisely:

```
find lib -type d -name application -o -name commands -o -name queries -o -name usecases
→ 0 directories
```

The layers that exist are `domain` (9), `data` (9), `presentation` (12)
and `providers` (11). **66 widget files reach a repository directly**
through Riverpod, across eleven features.

The cost is concrete rather than theoretical.
`reserve_seat_actions.dart` was 740 lines, and one method in it held the
bottom sheet, the booking gate, the trace points, three repository calls
and three success messages. The decision *"this booking is for somebody
else, so it is a confirmation request rather than a reservation"* — a
rule with a real consequence for a real person — lived inside a widget,
so the only way to test it was to pump the Reserve hub, open a sheet,
pick a member and tap a button.

The A+ target also asks that **Booking cannot mutate Finance directly**.
Today there is nowhere for that pipeline to live: a screen holds the
orchestration.

## Decision

**One layer, named `application/`, per feature.** Not `commands/`,
`queries/` or `usecases/`: this project has no CQRS split and inventing
one would be vocabulary without a difference.

**The rule, in one line each:**

| layer | says |
|---|---|
| `presentation/` | what the member **asked for**, and what to say once it happened |
| `application/` | **which write** that is |
| `domain/` | the rules, pure Dart, no Flutter |
| `data/` | how the write reaches Postgres |

**An application command takes no `BuildContext` and no
`AppLocalizations`.** It returns a value; rendering it is presentation's
job. That is precisely what lets it be tested with a fake repository and
no widget tree — `book_seat_test.dart` runs seven cases in milliseconds
that previously needed a screen each.

**An application command does not catch.** A refusal from the server is
information the member needs verbatim (#1030). Swallowing it to return a
tidier type throws away the server's own words, which is the thing
`bookingErrorText` exists to render.

**It moves one context at a time, and the ratchet is a count.**
`test/lint/layering_test.dart` now carries `_repositoryInWidgets`: how
many widget files in each feature still reach a repository. 66 today.
Every number may only go down; a feature that reaches zero is deleted
from the map, after which any widget in it touching a repository fails.

A count and not a list of names, for the same reason `_pairBudget`
counts imports rather than listing pairs: **presence tells you nothing
about progress.** `reservations` went 5 → 4 when `book_seat.dart` took
the booking decision out, and a presence list would have shown that as
no change at all — which is how a refactor this size stalls.

## The first context, and why it is Booking

Its rules are already pure Dart in `features/plan/domain/`, so there was
a domain to talk to rather than one to invent. `application/book_seat.dart`
holds the three-branch decision and nothing else:

- **for somebody else** → `createFor`, and never a check-in, because the
  subject is not standing at the desk and may yet decline (#106);
- **with a pattern** → `createSeries`, and the partial result comes back
  for the caller to show;
- **otherwise** → `create`, reporting what the *server* was asked to do
  about checking in, because saying `false` while it checked them in is
  the confirmation lying (#687).

Whose booking it is decides **first**, and whether it repeats second — a
repeat somebody has not agreed to is still something they have not
agreed to. That ordering was implicit in a chain of `else if` and is now
a test.

## Consequences

- 66 → 65 files, and the number is in the suite. The remaining work is
  visible and ordered: `money` (25) and `workspace` (20) are the two
  that matter and the two most likely to be done badly.
- The Booking → Finance pipeline the A+ target asks for now has
  somewhere to live. It is not built: today the server does it, inside
  `create_reservation` → `assert_member_quota`, and moving that to the
  client would be moving an invariant off the only machine that can
  enforce it (ADR 0020). What the layer gives is a place for the
  *client-side* orchestration, not a second copy of the rules.
- `reserve_seat_actions.dart` still calls repositories for check-in,
  cancel and seat blocking. Those are the next commands, and the count
  says so.
- A feature with no `application/` directory is not a violation. The
  layer arrives where there is orchestration to move, and a widget that
  reads one provider and draws it has none.
