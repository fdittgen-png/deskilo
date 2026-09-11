# ADR 0019 — An invitation chooses dev, or dev and prod. Never prod alone

**Status:** accepted · **Date:** 2026-09-11

## Context

The owner asked (#1119) that whoever creates a person choose "the
environments on which he needs to be activated — the workspaces, and the
dev or PROD on them".

There is no such choice today. Which environments somebody lands in is a
side effect of three mechanisms, none of which is presented as a
decision:

1. **The invite code decides both.** `invitations` and
   `workspaces.invite_code` belong to ONE workspace row, and dev and prod
   are two rows. Redeeming a dev code joins dev; no code means "both".
2. **`members_prod_access_guard` (0185)** refuses a prod member whose
   ROLE does not hold `accessProd`. Production membership is gated by the
   role matrix, not by whoever is inviting.
3. **`members_mirror_to_dev` (0185)** makes every prod member a dev
   member automatically, and follows later role and status changes.

The net invariant is **prod ⊆ dev**. Dev-only is reachable; prod-only is
not; both-at-once happens only as a consequence of joining prod.

Measured on the live project when the issue was written: COWORKONTI 11
dev / 11 prod / 9 in both; zemare 1 / 1 / 1. **Nobody is in exactly one.**

## Decision

**Two answers, not three: dev, or dev and prod.** The invitation carries
one boolean, `invitations.also_prod`, and the UI asks one question —
*"Also give access to production?"*

Rejected: **prod-only** (option A of the issue). It contradicts an
invariant introduced eight migrations earlier, and that invariant is not
arbitrary — the dev twin is where an admin rehearses, and somebody who
exists in prod but not in dev cannot be rehearsed against. No live row
has ever been in exactly one environment.

Rejected: **prod-only as prod + a shadow dev row** (option C). More
machinery to present a choice nobody has asked for in practice.

The question an admin is actually asking is not "which of two parallel
worlds" — it is **"does this person touch production"**. That has two
answers.

## The rule this must not break

An invitation may not grant what the role matrix withholds. Otherwise the
invitation becomes a way around the matrix — the same class as #1080,
where a deployment was a way around the permissions.

So `accessProd` is checked **twice**:

* at **creation**, so an admin is told immediately rather than finding
  out when the person redeems;
* at **redemption**, because the matrix can change in between.

The second check does **not** refuse the join. The person still becomes a
member of the dev side, and the join event records `also_prod_asked` and
`also_prod_given` so the difference is visible. Refusing the whole join
would punish the invitee for a decision somebody else changed after the
invitation was written.

## Consequences

* The choice is offered only on a **dev** workspace that **has a twin**.
  Joining a prod workspace already reaches production and the mirror adds
  the dev side by itself; asking a question with one possible answer is
  worse than not asking it.
* **Existing invitations keep working.** `also_prod` defaults to false,
  so the open dev invitations that predate this redeem to dev exactly as
  they did.
* **The managed-member path (#887) is covered by the invitation**, not by
  a second control on the profile form. A managed row has no account, so
  "which environments" only becomes a real question at handover — and the
  handover is a bound invitation, which carries the flag like any other.
* Behind `memberEnvironments`, default OFF, under `environmentPairs`.
