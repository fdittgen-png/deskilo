# ADR 0032 — Filming mode substitutes people at the data seam

**Status:** accepted · **Date:** 2026-09-20 · **Issues:** #1514 (this), #1380 (retired the blur), #970 (the blur), #1538/#1539 (what Demo can and cannot stand in for), ADR 0028 (the seam)

## Context

A guide, a support video, a store listing or a conference talk needs a
picture of the product working. Sometimes the picture may be of an
invented workspace, and then **Demo is the answer and this decision does
not apply** — Demo is isolation by absence (ADR 0028), there is no
Supabase client inside its scope, and since #1539 its cast has names,
e-mails, telephone numbers and an address of its own.

Sometimes it may not. A screenshot for a support answer is about *this*
space's plan, *this* month's bookings, *this* invoice. The structure,
the figures and the layout have to be the real ones; only the people
must not be.

#1380 removed the mechanism that used to serve this, because it was
wired to Demo. The requirement survived it.

### Why the old answer must not come back

The blur (#970) painted over the rendered result. A layer above the
navigator walked the render tree every frame, matched rendered
paragraphs against a registry of personal strings that a dozen providers
had to remember to feed, and blurred the rectangles that matched.

Its correctness was the conjunction of a dozen memories. A provider that
forgot to register a string left a name in the clear — **silently, and
only in the recording nobody re-watches.** It failed OPEN, and the cost
was not hypothetical: the #1199 sweep pixelated 25 published images by
hand and still left a member's telephone number legible in the public
wiki and in every store build for ten days (#1538).

`no_render_tree_blur_test` already refuses the three symbols it was made
of. This decision is the answer to the question that test deliberately
left open.

## Decision

**Filming mode replaces the PEOPLE at the data seam, and changes nothing
else.** While `recordingPrivacy` is on, the six providers that carry a
person hand their result to `lib/core/privacy/recording_privacy.dart`
before anything can read it. Names, e-mails, telephone numbers,
companies, postal addresses, VAT and legal identifiers and photographs
belong to an invented person; the plan, the bookings, the seats, the
figures, the invoices and every layout stay exactly what they are.

Five consequences follow, and each is the reason this shape was chosen
over the alternatives below.

**1. Nothing real is ever rendered, so there is nothing to paint over.**
The failure mode of a substitution is a name that is invented when it
did not have to be. The failure mode of a mask is a name that stayed.

**2. A new SCREEN cannot leak.** A screen reads a provider, and the
provider has already been through the seam. The old mechanism had the
opposite property: every new surface was a new way to fail.

**3. A new PROVIDER could leak, so a lint pins the reads.**
`recording_seam_test` enumerates the seven repository reads that answer
with a person and fails on any file in `lib/` that performs one without
naming the seam. This is the honest limit of the guarantee, and it is
checked rather than promised — the difference from the blur, whose
equivalent obligation lived in nobody's test.

**4. The substitution is stable and total per person.** A pseudonym is a
pure function of the id the data is keyed by, so the same member is the
same invented person on the plan, in the directory, on the invoice and
in the kiosk receipt — a recording stays followable. The generator is a
hand-rolled FNV-1a and not `String.hashCode`, so the cast cannot change
across a restart, mid-shoot.

**5. What is invented reaches nobody.** E-mails are `@example.test`
(RFC 2606), telephone numbers are in ARCEP's fictional `06 39 98 xx xx`
range, and the streets and localities do not exist. A viewer who types
what they saw finds nothing. `recording_privacy_test` asserts it.

### It is obvious while it is on

A permanent strip above the navigator, in the app's own builder beside
the Demo bar, on every route there is. Not a snackbar, not a badge on
one screen, not a colour somebody has to notice. The requirement runs
both ways: nobody must record for ten minutes believing the mode was on,
and — the more dangerous direction — nobody must work for a day on
invented names believing they were real.

### Identity writes are refused while it is on

Substituting on the way out would otherwise substitute on the way back
in. The three identity forms are prefilled from the seam, so saving one
would write the invented person over somebody's real details and the
record would be gone. They call `refusedWhileRecording` first and say
so. This is the one place filming mode changes behaviour rather than
appearance, and it is the price of not corrupting data.

### The server keeps answering with the truth

Migration 0258 adds the flag to `feature_registry()` and **no server
gate reads it.** The substitution is a rendering decision on the client.
A server that started answering with invented people would make an
export, a GDPR portability answer or an e-invoice taken during a shoot
into a data bug wearing a privacy feature. For the same reason
`excel_export.dart` is the one exemption in the lint: it writes a file,
not a frame.

## How this differs from Demo, and why both exist

| | Demo (ADR 0028) | Filming mode (#1514) |
|---|---|---|
| The workspace | invented | **the real one** |
| The people | invented | invented |
| The bookings, figures, plan | invented | **the real ones** |
| Isolation | by absence — no Supabase client in scope | none — the live app, with the people replaced |
| Writes | land in the fixture, leave nothing | land in the real workspace; identity writes are refused |
| Use it for | showing the product to a stranger | documenting *this* space |

Demo is the better answer whenever it is an answer at all, and the
documentation skill still says to shoot in Demo first. This exists for
the pictures Demo cannot take.

## Alternatives, and why not

| option | why not |
|---|---|
| **Rebuild the blur** | It fails open, silently, in the artefact nobody re-checks. #1199 and #1538 are the evidence, not a worry. |
| **Nothing at all — shoot in Demo, as a documented habit** | Genuinely on the table (#1514 says so), and it is why Demo got a cast (#1539). It fails for the picture whose POINT is this workspace: a support answer about a member's invoice, a conference slide about a real month's occupancy. And a habit is exactly what the #1199 sweep was. |
| **A screen-capture-aware mode the platform reports** | `isCaptured` exists on iOS and on Android 14+, nowhere on desktop or the web, and never for a phone pointed at the screen — the case a conference talk actually is. It would be a nice extra trigger for a mechanism that exists; it is not one. |
| **Pseudonymise in the Supabase row decoders** | Structurally stronger — a domain object could not exist unpseudonymised. But the decoders are unreachable from the widget suite, so the fail-closed property could not be proven by driving a real screen, which is the test that matters here. |
| **A per-device switch instead of a workspace flag** | Whether this space's data may be filmed is the space's decision, not the decision of whoever holds the phone. It also has to be visible to a reviewer of the feature list, which a device preference is not. |
| **Substitute server-side** | See above: it turns every export taken during a shoot into a lie. |

## What this does not cover, said plainly

* **Free text.** A message, a note, a workspace name or a seat label can
  contain a person's name, and nothing can tell. Filming mode does not
  read prose. The guides say to check what is written on the screen
  before filming it.
* **Anything already published.** This protects the next recording. The
  images in the wiki and in the store builds are the #1538 sweep's
  problem, and git history keeps the originals either way.
* **A member's own device.** The flag is workspace-wide, so while it is
  on, every member sees invented names. That is deliberate — it is what
  makes "is it on?" answerable — and it is why it defaults off and why
  the strip is permanent.

## Consequences

* `lib/core/privacy/` holds the cast, the substitution, the provider and
  the strip; nothing else in `lib/` knows the mode exists except the six
  providers and the three forms that refuse.
* `recording_seam_test` is a ratchet on the reads, not a presence list:
  a new personal read fails it by name.
* `recording_fail_closed_test` drives the real directory and walks every
  rendered `Text`, so the assertion is over the whole frame rather than
  over a widget somebody remembered. Its last case runs the same walk
  with the flag off and finds every value — a rule that cannot fire is a
  gate nothing can trip.
