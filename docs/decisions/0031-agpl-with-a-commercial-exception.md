# ADR 0031 — AGPL-3.0 with a commercial exception, and the name as a mark

**Status:** accepted · **Date:** 2026-09-20 · **Supersedes:** [ADR 0009](0009-relicense-0bsd.md)

## Context

The owner wants commercial businesses to pay for what associations,
collectives and individuals get for free — and wants DesKilo to stay in
F-Droid's main repository.

Those two wishes look incompatible and are not. A licence that forbids
commercial use fails OSD #6 ("No Discrimination Against Fields of
Endeavor") and FSF freedom 0, so it is not free software: `fdroid lint`
validates the recipe's `License:` field against the free list, and
MR !47409 — green, reproducible, awaiting publication — would close. The
PolyForm Noncommercial / Commons Clause / BUSL family are all
source-available, none are FOSS, and none are admitted.

Three facts shaped the answer.

**DesKilo's users ARE commercial businesses.** The market is coworking
spaces, and most are for-profit. A non-commercial clause would not
exclude distant corporations; it would exclude the actual adopters, and
it would make an association that charges membership fees ask a lawyer
whether it qualifies. "Non-commercial" is the hardest word in licensing
to define, and it would have to be defined against our own users.

**Nothing published can be recalled.** Everything released to date —
every store build, every F-Droid build, the whole history — is 0BSD, and
0BSD grants use, modification and distribution with no conditions at
all. Anyone may fork the last 0BSD commit and carry on commercially for
ever. New terms bind only code written after them, and the value of the
change grows with the distance from that commit. Stating this plainly
here is part of the decision; discovering it later would not be.

**ADR 0009 chose 0BSD deliberately**, wanting "the minimum possible
obligations", and superseded ADR 0004's MIT for exactly that reason.
This reverses that intent knowingly, because the goal has changed from
"impose nothing" to "a company either shares its changes or pays".

## Decision

1. **AGPL-3.0-or-later** is the public licence. A commercial space may
   still run DesKilo — but if it modifies the app or the server
   functions and offers them to its members over a network, §13 obliges
   it to publish those changes. That is the whole lever: publish, or buy
   an exception.
2. **A commercial licence** (`COMMERCIAL-LICENCE.md`) sells exactly that
   exception. Associations, collectives and individuals never need it.
3. **An App Store exception**, granted in the same breath. GPL-family
   terms conflict with Apple's device-count restrictions — this is what
   removed VLC from the App Store in 2011 — and DesKilo ships TestFlight
   builds. As sole copyright holder the owner can grant the additional
   permission Apple's distribution needs. Without this clause the iOS
   leg dies, so it is not an afterthought but a condition of the change.
4. **The name is a mark.** "DesKilo" and its logo are asserted as
   trademarks, so a fork must rename. This is the part that stops a
   competitor trading on the name, and it is the cheapest protection of
   the four: it costs no licence complexity, it keeps the F-Droid
   submission alive, and it is often what people actually mean when they
   say "limit commercial use". The registration is the owner's to file;
   the repository carries the policy and the notice.

## Consequences

- F-Droid is unaffected: AGPL is on the allowed list. **The recipe is
  NOT touched here.** `fdroid/de.deskilo.app.yml` is frozen by the
  owner's 2026-09-04 instruction and pinned by `fdroid_frozen_test`; its
  `License:` field changes only when F-Droid asks, after publication.
  Until then the repository and the recipe disagree on purpose.
- Play and TestFlight are unaffected, given clause 3.
- Every dependency must be AGPL-compatible for the outbound licence to
  hold. Apache-2.0, BSD and MIT all are, and the libre variant already
  drops Firebase — but this is now a release gate, not a one-off check.
- Contributions must be AGPL, or the dual licence cannot be offered: a
  contributor's copyright cannot be sold by somebody else. `CONTRIBUTING.md`
  says so, and a DCO sign-off records it.
- The sweep touches the `LICENSE`, 1648 SPDX headers, the lint constant
  in `spdx_headers_test.dart`, the two generators in
  `tool/build_setup_l10n.dart`, `README.md`, `PRIVACY.md`,
  `docs/SPECIFICATION.md`, `docs/wiki/Technical-Reference.md` and the
  "Help & about" section of the five guides.
- More permission can always be granted later; less cannot. That
  asymmetry is why this direction is the reversible one.
