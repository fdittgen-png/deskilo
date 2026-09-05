# ADR 0014 — Identity lives on the profile; a managed member holds it only until claimed

**Status:** accepted · **Date:** 2026-09-05

## Context

Every invoice printed the recipient as a bare display name — "Guilhem"
and nothing under it — because a person in DesKilo was a display name,
one free-text address, a WhatsApp number and a VAT id. A French
invoice must name the buyer with an address; a letter needs the
standard postal block (company · street · POSTAL CITY · country when
abroad); the pilot association's reference sheet carries company,
phone, e-mail and the member's registration number. At the same time
the association onboards people **before** they have the app: the admin
must create the member, book and invoice for them, and later hand the
profile over — and `members.user_id` was NOT NULL.

## Decision

**One structured identity, `PersonalInfo`, edited by ONE form.** It
lives on `profiles` (#886, migration 0152: first name, family name,
company, street, postal code, city, country, phone, e-mail, VAT id,
legal id). The two renderings every document prints — the full name
"Prénom NOM" and the postal block — exist twice, in SQL
(`profile_full_name`, `profile_postal_block`, what `create_invoice`
freezes) and in Dart (`PersonalInfo.fullName` / `postalBlock`, what the
form previews and the designer shows), and a test pins them equal. The
free-text `address` stays as the fallback for profiles that never
filled the form.

**A managed member (#887) carries the same identity in
`members.managed_identity` only while `user_id` is null.** The admin
edits it with the same form. The handover is a personal invitation
bound to the member: when the person — with an account they may have
created a minute ago — redeems the code, `join_workspace` sets
`user_id`, copies the identity into the empty fields of their profile
(the user owns their data from then on), clears the managed copy, and
raises the ordinary `member_join` validation. Reservations, invoices,
subscriptions and documents were always keyed by the member id, so
nothing moves.

## Consequences

- Documents print `client_name` over the block `client_address`, with
  `client_company`, `client_phone`, `client_email` beside; the
  `<recipient>` element uses them without a designer's intervention.
- `fetchMemberNames` prefers the structured name; lists and documents
  agree on how a person is called.
- Everything a managed member accrues before the handover belongs to
  the member row and therefore to the person who claims it — an
  invitation must never be handed to the wrong person; it is revocable
  until redeemed.
- A profile is never written by an admin: the copy happens in the
  person's own session, at claim time, and only into empty fields.
