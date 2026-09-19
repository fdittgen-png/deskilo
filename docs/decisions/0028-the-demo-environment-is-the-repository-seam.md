# ADR 0028 — Demo is the repository seam, with no backend behind it

**Status:** accepted · **Date:** 2026-09-19 · **Issues:** #1372 (epic), #1373, #1377; the architecture decision #1447 D6-A asks for before any Demo implementation

## Context

Demo mode today (#970) is a **blur layer over live data**: `DemoBlurLayer`
sits above the navigator, the providers register the personal strings
they carry, and every rectangle that renders one of them is blurred in
place. It makes a recording safe to publish. It does not make the app
safe to hand to a stranger: the data underneath is real, every write
goes to the real workspace, and every external effect — an invitation,
a payment, an e-invoice — is one tap away from happening for real.

#1372 replaces it with a Demo **Environment**: the normal screens, the
normal domain, against an explicitly isolated synthetic workspace. The
question this decision answers is *where* that isolation lives, because
everything else in the epic depends on the answer.

### The seams that already exist, measured on master

* **Eleven repository interfaces** in `features/*/domain/` — `AuthRepository`,
  `WorkspaceRepository`, `MoneyRepository`, `ReservationRepository`,
  `FloorPlanRepository`, `EventRepository`, `CalendarRepository`,
  `CreditRepository`, `AccessoryRepository`, `ProfileRepository`,
  `WorkspaceImportRepository` — each with one Supabase implementation in
  `features/*/data/` and one provider in `features/*/providers/`.
* **Twenty-one files reach `Supabase.instance`**, thirteen of them those
  repository providers; the rest are the backend settings, realtime,
  push, the router's session read and two settings screens.
* **The app already runs end to end with none of them.** The widget
  suite mounts `ProviderScope(overrides: standardTestOverrides(...))` and
  drives real screens, real routing, real application commands against
  in-memory implementations of those same interfaces, in roughly a
  thousand tests. The seam is not theoretical; it is the most exercised
  path in the repository.

## Decision

**1. The Demo environment is a `ProviderScope` whose repository providers
are overridden — the seam the tests already use — mounted above the
router when Demo is entered.** Not a second backend, not a tenant inside
the live database, not a branch inside each repository.

**2. The in-memory repositories are the ones that already exist.**
`test/helpers/` holds **6 481 lines** of implementations of those same
eleven interfaces — `FakeWorkspaceRepository`, `FakeMoneyRepository`,
`FakeReservationRepository`, `FakeFloorPlanRepository`,
`FakeEventRepository`, `FakeProfileRepository` and the rest — kept
honest by the thousand tests that drive real screens through them. Demo
**moves them to `lib/core/demo/data/`** and the suite imports them from
there; it does not write a second set.

Writing new ones would mean 6 000 lines of duplicate behaviour with no
second reader, drifting from the fakes the moment a repository method is
added — the exact failure #1373 means by "reuse existing abstractions
wherever possible". Moving them has three consequences, each accepted
deliberately:

* **They ship in the app binary.** They are the Demo backend; that is the
  point, not an accident.
* **Their test-shaped knobs come along** (`flagConflictNext`, seeded
  failures). Demo does not use them; a test still can, and a knob nobody
  sets changes nothing.
* **They stop being free to contort for one test.** A fake that is also
  the Demo backend has to behave like the product. That is a gain, and
  it is the reason this direction is the one worth taking: the suite's
  fakes have always claimed to behave like the server, and now something
  a person looks at depends on it.

The *interfaces* stay single in every case — a second
`DemoWorkspaceRepository` interface would be the duplication that rots.

**3. No Supabase client exists inside the Demo scope.** Realtime, push,
storage and Edge providers are overridden with inert implementations in
the same scope. An external effect in Demo is therefore **impossible,
not refused**: there is nothing to call, so there is no code path — no
forgotten branch, no `if (demo) return;` somebody deletes in a year —
by which an invitation, a payment, an e-invoice or a push can leave.
This is what #1377 asks for, obtained by construction.

**4. Missing or invalid Demo context fails closed.** The Demo scope is
built from the fixture before the router is handed to it; if the fixture
cannot be built, Demo refuses to open and says so. It never falls back
to the active live workspace — the fallback is not disabled, it does not
exist, because the live providers are not in scope.

**5. Live is never disposed; Demo is a child scope.** Leaving Demo
disposes the child, so no Demo value can survive into live providers,
and a live value cannot leak into Demo (the overrides shadow them).
Reset (#1375) rebuilds the child scope behind a generation counter, so a
mutation in flight cannot land in the new one.

**6. The blur stays until entry and isolation both hold** (#1380), and
is never transiently disabled while live personal data is on screen.

## What this costs, said plainly

**Demo demonstrates the app, not the server.** Quota enforcement, the
invoice numbering series, RLS, the booking race — those live in Postgres
and are proven by pgTAP. A Demo journey that depends on one of them
shows the *behaviour* the server would produce, written into the Demo
repository as a rule with a comment naming the SQL it mirrors. Any
journey whose point IS the server's enforcement does not belong in Demo.

**A mirrored rule can drift.** The mitigation is scope, not cleverness:
the fixture and its rules stay small enough to read, and the epic's
tests assert the journey a visitor sees rather than re-proving the
server's arithmetic.

## Alternatives, and why not

| option | why not |
|---|---|
| A real Demo workspace in the live database, isolated by RLS | Puts synthetic data one policy mistake away from real tenants, needs seeding and cleanup in production, and every external effect would have to be *refused* by a server-side check — a check that must be written, remembered and tested for each new effect. Isolation by absence beats isolation by permission. |
| A second Supabase project for Demo | Real isolation, but a second deployment to provision, migrate, pay for and keep at the same schema version; and an effect that leaves it (an e-mail, a payment) is still a real effect. |
| A `demo` flag inside each Supabase repository | Thirteen implementations each gain a branch, and the guarantee becomes "every branch is correct, forever". The first forgotten one is a real invitation to a real address. |
| Keeping the blur | It protects a recording, not a visitor, and #1372 exists because that is not what Demo is for. |

## Consequences

* `lib/core/demo/` gains `data/` (the fakes, moved from `test/helpers/`)
  and the scope builder; `demo_blur.dart` stays until #1380 retires it.
  The move is one mechanical commit — the imports change, the behaviour
  does not — and the suite proves it: if a single assertion moves, the
  move was not mechanical.
* The fixture (#1374) is the single source for Demo, screenshots and,
  where useful, tests — one deterministic dataset with an injected clock,
  so a "today" booking never expires out of the demo.
* Personas (#1376) are a Demo-scope identity, not a pretend role: the
  Demo auth repository answers a different member, and the normal
  permission resolution does the rest.
* The environment indicator, **Reset** and **View as** are one compact
  control (#1379) reading the Demo scope, not the screens.
* Tests that prove the isolation are structural: a Demo scope that
  contains no Supabase-backed provider, a write in Demo that leaves the
  live fakes untouched, and entry with a broken fixture that refuses.
