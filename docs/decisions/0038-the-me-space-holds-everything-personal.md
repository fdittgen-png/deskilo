# ADR 0038 — The Me space holds everything personal; workspace kinds feed it through one item contract

**Status:** proposed · **Date:** 2026-10-07 · **Extends:** ADR 0034 (messenger in Me), ADR 0035 (my finances in Me)

## Context
A person belongs to many spaces, and soon to spaces of other kinds (yoga,
massage). What concerns them personally — invoices, payments, bookings,
decisions, badges, privacy — is split across each workspace's screens and
scoped to the last-used space. The design is docs/design/ME_SPACE.md.

## Decision
1. Everything that personally concerns a person lives in Me (Home, Agenda,
   Messages, Wallet, Me). A workspace is where its operators organise the
   space and its resources, and where a member uses a resource in the moment.
   Each workspace screen links to Me already filtered to that space.
2. Me renders **personal items** — one versioned shape (workspace, type,
   state, time, server-composed title, amount, server-authorised actions,
   optional payload). Contributors are SQL functions registered by type;
   `my_items` is their union for `auth.uid()`. The client renders unknown
   types generically. Me never imports a workspace kind's domain.
3. `workspaces.kind` is a profile (template, feature profile, lexicon,
   contributors), not a fork.
4. Me is production: development spaces never count anywhere in Me; their
   documents are shown apart, marked DEV in the development colour, and open
   in their own environment.
5. Wallet pays what it shows: online payment intents may target invoices, and
   settlement matches them. Saved methods are provider-held references scoped
   to (person, space, provider); no card data is stored.

## Consequences
- Delivery follows the slices of ME_SPACE.md §7, server first, one PR each.
- The member view of the workspace Money tab becomes a link to Wallet; the
  operator's Invoicing is unchanged.
- Device-local favourites/ratings of spaces migrate to the 0376 server tables.
- Me's own rows stop depending on the last-used workspace's feature flags.
