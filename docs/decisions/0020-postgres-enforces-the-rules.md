# ADR 0020 — The database enforces the rules, and the client only asks

**Status:** accepted · **Date:** 2026-09-13

## Context

Every rule that matters in this app — a seat cannot be double-booked, an
issued invoice cannot change, nobody validates their own event, a member
of one workspace cannot see another — is enforced in PostgreSQL: in
constraints, in triggers, and in `SECURITY DEFINER` functions the client
calls but cannot bypass.

This was never written down as a decision. It was the shape the code
took, and #1243's threat model made the absence obvious: the trust
boundary section had to state it in order to say anything else.

## Decision

**The device is never trusted. The only boundary that holds is the
database's.**

Concretely, and these are the rules the codebase already follows:

1. A client may `SELECT` through RLS. It may not `INSERT`, `UPDATE` or
   `DELETE` a reservation, a ledger entry or an invoice — those tables
   carry a select policy and nothing else.
2. Every mutation goes through a `SECURITY DEFINER` function that
   resolves `auth.uid()` to one active member row and checks a
   permission before it does anything.
3. A rule the client also implements — the booking window, the quota,
   the granularity — is a *courtesy*, so the member is told before they
   tap. The server refuses independently, and the client's copy is
   allowed to be wrong without being dangerous.
4. The server's refusal text is pinned by test, because the client maps
   it to a sentence a person can read.

## Consequences

**Good.** A modified client, a stale client, a replayed request and a
direct PostgREST call all hit the same wall. Offline and multi-device
correctness come free: the last word is always one place.

**Costly.** Business logic in plpgsql is harder to read, harder to
refactor and — until #1226 — impossible to unit-test. 208 migrations and
241 definer functions are the price of this decision, and the reason the
A+ programme's first item is putting a database in CI.

**Accepted.** The alternative is trusting a client we ship to phones we
do not control, on behalf of a community's money.
