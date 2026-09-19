# ADR 0030 — A Demo reset is a new fixture, and a restart is a new demo

**Status:** accepted · **Date:** 2026-09-19 · **Issue:** #1375 (of #1372)

## Context

#1375 asks for two things that pull in opposite directions. Demo must
behave like a real workspace — a booking made on one screen shows up on
the next, and the money it costs shows up in the accounts — and a visitor
must be able to put the space back exactly as they found it, at any
moment, without the reset being able to corrupt anything.

It also asks a question outright: does a Demo session survive closing the
app?

ADR 0028 already settled where Demo lives. It is the repository seam,
with no backend behind it: a `ProviderScope` whose overrides point every
`domain/` repository at an in-memory implementation, and a `DemoFixture`
holding all eleven of them. Nothing below that line knows Demo exists.

## Decision

**A reset is a new `DemoFixture` in a new scope, never a cleanup of the
old one.** `DemoSessionController` holds the current fixture and a
generation counter; `reset()` builds a fresh fixture from the canonical
dataset and increments the generation. `DemoWorkspace` keys its
`ProviderScope` on that generation, so a reset disposes the whole subtree
and every provider under it, and no screen has to be told to refresh.

**The fence is the object graph, not a flag.** A mutation that was
already in flight when the reset happened still holds references to the
repositories of the *old* fixture. It completes into an object graph
nothing reads any more. There is no window in which a late write reaches
the fresh dataset, because a late write has nowhere to land — and no
`if (generation == mine)` check anybody can forget. Repeated and
concurrent resets are safe for the same reason: each one replaces the
current state with a fixture built from the canonical dataset, and the
one before it is simply dropped.

**The new fixture is seeded at the same instant as the first.** "Today"
keeps meaning the day the visitor arrived, so the bookings they were
looking at come back where they were rather than sliding to a different
weekday.

**Demo state does not survive a restart.** The session lasts as long as
the app is open.

## Why not persist it

Persisting would mean a serialisation format for all eleven repositories
and a migration story for it, which is exactly the broad new framework
ADR 0028 exists to avoid, for a gain that is not obviously a gain: a
returning visitor would be handed their own half-finished experiment
instead of the product. The thing that makes a demo worth reopening is
that it looks like the product, and the thing that makes exploration safe
is that Reset is always one tap away inside the session.

If a persisted session is ever wanted, the honest shape is to persist the
*actions* a visitor took and replay them onto a fresh fixture, not to
freeze the repositories. That is a different decision and needs its own
ADR.

## Consequences

* Reset needs no cleanup code, and cannot leave a repository half-cleared
  — the failure mode a per-repository `clear()` would have had.
* A screen holding a fixture reference across a reset shows stale data
  until it is rebuilt; keying the scope on the generation is what makes
  that impossible in practice, so a future Demo surface must mount inside
  `DemoWorkspace` rather than beside it.
* The Demo session controller lives ABOVE the Demo scope. A controller
  inside it would be disposed by the very reset it was asked to perform.
* Nothing here changes live mode. Two fixtures share no repository
  instance, which is what makes "Demo touched no live data" a structural
  fact rather than a promise.
