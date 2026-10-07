# The Me space — the person's home across every space

Status: proposed 2026-10-07 (ADR 0038). Supersedes the scope of ADR 0035 ("my
finances in Me") by generalising it: **everything that personally concerns a
person lives in Me; a workspace is where its operators organise the space and
its resources, and where a member uses those resources in the moment.**

This document is the foundation the next releases build on. It is written so
that a coworking space, a yoga studio and a massage practice are three
*kinds* of workspace feeding ONE Me space — without Me knowing what a seat,
a class or a treatment is.

---

## 1. Why

A person who travels belongs to many spaces: one with a subscription at home,
several used once or twice on the road, later a yoga studio or a massage
practice. Today what concerns them is split across those spaces:

| What concerns me | Where it lives today | Problem |
|---|---|---|
| My invoices, reminders, payments | Me › Finances (list) **and** each workspace's Money tab (detail, PDF, pay) | Two places; paying needs a hop into the space |
| Paying online | Only the workspace Money tab, and it pays **a month**, not an invoice | Cannot pay what Me shows; no saved methods |
| How to pay (IBAN, PayPal.me…) | Only the workspace Money tab | — |
| My credit, refunds owed, statement, usage, carnets | Only the workspace Money tab | Not visible across spaces |
| My bookings / check-ins / series | Only each workspace (Reserve, Calendar "mine") | No agenda across spaces |
| Decisions I must take, requests I made | Only the current workspace's alerts | A request waits unseen in another space |
| Alerts, app badge, check-in reminders | Active workspace only | Other spaces are silent |
| My badges, badge PIN, kiosk | Workspace Settings › My membership | Account-level PIN hidden in a space |
| Privacy (export, erase, access log) | Reached from Me but scoped to the last-used space | Silent wrong scope |
| Applications to join | `/applications`, not linked from Me tabs | Hard to find |
| Favourite / rated spaces | Server tables (0376) **and** a device-local store (Me Home) | Two truths |

The survey behind this table (2026-10-07) is summarised in §9.

## 2. Principles

1. **One question per place.** Me answers *"what about me, across all my
   spaces?"* A workspace answers *"how is this space run, and what can I use
   in it right now?"*. A screen never answers both.
2. **Me is kind-agnostic.** Me renders *personal items* (§4). A workspace
   kind (coworking, yoga, massage…) contributes items; Me never imports a
   kind's domain (seats, classes, treatments).
3. **The server decides, the client draws.** Every personal list is one
   account-level read keyed by `auth.uid()`, never a client loop over
   workspaces. Visibility, permissions and feature gates are applied on the
   server: an item exists for me only if its workspace's feature allows it.
4. **In the moment, in the space.** Booking a seat, checking in, joining a
   class stay in the workspace (that is *using* a resource). Everything
   *after* the moment — what it cost, what I owe, when it is — is in Me.
5. **Every row opens its home, filtered.** A workspace links to Me already
   narrowed to itself (`?workspace=` — done for Finances, #2252); a Me row
   that needs the space (e.g. "book again") opens the space at that object.
6. **Private by default, consistent everywhere.** The visibility matrix
   (MESSENGER_VISIBILITY.md) governs what others see; Me only ever shows the
   person their own data.
7. **Federated by the same contract.** A connected installation answers the
   same reads; Me merges them (as the inbox does), naming the server.
8. **Me is production.** A development space holds test data: it never enters
   a total, a badge or a "to do", and when shown (to those who have access)
   it sits apart, in the development colour, with DEV beside the space's
   name. Opening it opens the document in that development space, never in
   its production twin (#2256).

## 3. Information architecture

```
Me (account, no workspace needed)
├─ Home       today: what needs me (pay, decide, respond), next bookings,
│             what I owe at a glance; my spaces (groups, search, sort)
├─ Agenda     my bookings, sessions, visits — every space, one timeline
├─ Messages   discussions (ADR 0034), message requests
├─ Wallet     what I owe / paid / pay with, per space and in total
│             └─ <space>  statement, credit, carnets, usage, documents,
│                         how to pay, payment terms, my requests
└─ Me         profile & visibility, access (badges, PIN), privacy per space,
              notifications, preferences, connected servers, help
Discover     (the shared directory; reached from the menu and Home)
```

* **Home** becomes a *dashboard of what needs me*: one "To do" stack built
  from personal items in an `action` state (invoice to pay, decision to take,
  request answered, booking to confirm), then "Next" (upcoming agenda items),
  then **My spaces** (groups, search, sort — #2253).
* **Wallet** is today's Me › Finances grown into the full money home (§5).
* **Agenda** is new: all my bookings across spaces, kind-agnostic.
* **Me** keeps account settings; it gains *Access* (badges per space + the
  account badge PIN), *Privacy* with an explicit space picker, *Notifications*
  (push, per-space mute) and *About*.

What leaves the workspace for members (it stays for operators):

| Workspace surface (member view) | Moves to |
|---|---|
| Money tab: statement, invoices, payments, documents, requests | Wallet › <space> (the tab becomes a link for members; Invoicing stays for operators) |
| Settings › My membership: badge, PIN, status line, payment terms, documents, kiosk revert | Me › Access, Me › profile, Wallet › <space> |
| Calendar "mine" | Agenda (the workspace calendar keeps the space's own view) |
| Alerts about me | Home › To do (+ workspace keeps space-wide alerts) |
| Privacy per space | Me › Privacy with a space picker |
| Advanced: push status, About | Me |

## 4. The personal item — the extensibility contract

Everything Me shows is a **personal item**, the one shape every workspace
kind produces:

```
PersonalItem {
  source        installation (server) it came from
  workspace     { id, name, kind }            kind: coworking | yoga | massage | …
  type          booking | visit | invoice | payment | reminder | credit |
                decision | request | document | badge | alert | …
  id            stable within (source, type)
  state         open | action | done | cancelled  (+ type-specific sub-state)
  at / until    the moment it concerns (booking start, due date…)
  title         server-composed, already in the person's language
  subtitle      server-composed (resource label, practitioner, amount…)
  amount?       { minor, currency }   never summed across currencies
  actions[]     { id, label, kind: open | command, target }   server-authorised
  payload       type-specific details, versioned, optional to understand
}
```

* **Server**: one registry table `personal_item_sources(type, function,
  feature, min_schema)` lists which SQL function contributes which type, and
  under which workspace feature. `my_items(types[], from, to, cursor)` is the
  union of the registered contributors for `auth.uid()` — the generalisation
  of the existing `my_inbox` union (0316) and `my_finance_overview` (0380).
  A new workspace kind adds a contributor function and a registry row; Me
  does not change.
* **Client**: a `PersonalItemRenderer` registry maps `type` → icon, card and
  detail. **Unknown types render generically** from `title`, `subtitle`,
  `amount`, `at` and `actions` — so an older app still shows a newer server's
  yoga class correctly enough to open or pay it (the `must_understand` idea of
  the public-network contract).
* **Vocabulary is server-side**: `title` / `subtitle` come composed in the
  reader's language, using the workspace's lexicon (0223) — a yoga studio's
  "class" and a coworking "seat" never reach Me as hard-coded words.

### Workspace kinds

* `workspaces.kind` (text, default `coworking`) — a **profile**, not a fork:
  it selects a template (ADR 0026), a default feature profile, a lexicon and
  which item contributors apply. Unknown kinds behave as generic.
* The domain generalises in the workspace, not in Me:
  * a bookable **resource** (seat/desk/office/room today; studio, mat, treatment
    room, practitioner later) and a **session** (a class with a capacity and a
    time) → both produce `booking` items;
  * entitlements in **units** per kind (half-day today; session, minute later)
    → `credit` items say "7 sessions left" whatever the unit;
  * invoices and payments are already kind-neutral.
* Discover gains a kind facet once a second kind exists.

## 5. Wallet — money that concerns me

### 5.1 What it shows

* **Overview**: to pay (per currency), overdue, next due; then a list grouped
  by space (filter: all spaces / one space — done in #2252).
* **Invoice detail in Me** (not a hop to the space): journey, due date,
  reminders received with their evidence (`invoice_reminder_evidence`),
  PDF / share / e-invoice, and **Pay**.
* **Payments**: history, pending and failed online attempts, "I paid by
  transfer" (`record_payment` → the space confirms).
* **<space> page**: account position (credit on account, refunds owed —
  `member_account`), this month's statement (`member_statement`), carnets and
  credits, usage, payment terms, documents (agreement, reports), how to pay
  (the space's instructions), and the money requests (expense, quota
  extension, buy a package).

### 5.2 Paying — the change that makes Wallet real

Today online payment pays **a month** (`payment_intents.period`) and does not
match an invoice; matching is a later operator action. Wallet pays **what it
shows**:

1. `payment_intents.invoice_id` (nullable) — an intent for one invoice, or for
   several invoices of the same space and currency (`payment_intent_invoices`).
   `period` stays for "pay my running balance" of a month not yet invoiced.
2. `open_payment_intent` v-next validates the invoices belong to me, are owed,
   share the space's currency, and computes the amount server-side.
3. `settle_online_payment` v-next creates the `invoice_matches` rows
   (confirmed when the space's validation policy allows automatic settlement
   of online captures, otherwise pending) — the invoice turns *paid* in Wallet
   without an operator step.
4. Webhooks unchanged in shape; idempotency stays `deskilo-intent-<id>`.

### 5.3 How I pay — methods

* **Per space, because the merchant is the space**: each space has its own
  provider credentials (`payment_credentials`), so any saved method is a
  reference held **by the provider**, scoped to (person, space, provider):
  `account_payment_profiles(user_id, workspace_id, provider, customer_ref,
  label, last4, expires)` — never card data (PCI stays with the provider).
* **Preferred method**: today's `payment_provider` preference (account default
  + per-space override) moves into Wallet › How I pay, and only offers the
  providers the space actually accepts.
* **Manual**: the space's instructions (IBAN, PayPal.me, Wero, Lydia…) with
  copy buttons, and "I paid" to declare a transfer.

## 6. Agenda, To do, Access, Privacy — the other moves

* **Agenda**: `my_bookings(from, to, cursor)` across spaces (contributors:
  reservations, guest visits; later sessions/appointments); export one
  calendar file for all spaces; check-in reminders for **every** space, not
  the active one.
* **To do**: decisions I must take (`event_decisions` where I am a
  validator), requests I made and their outcome (events where I am the
  actor), invoices to pay, message requests — across spaces; the app badge
  counts this, not one space's bell.
* **Access**: my badges per space (`member_badges`), the account badge PIN,
  kiosk revert.
* **Privacy**: export / erase / access log / notice with an explicit space
  picker; an "everything" export joins all spaces.
* **Favourites and ratings of spaces**: one truth — the server tables
  `workspace_favorites` / `workspace_ratings` (0376). The device-local
  heart/stars of Me Home (#2240) migrate to them; groups, order and folding
  stay device preferences (later synced via `my_personal_preferences`).
* **Applications** (join requests, already account-wide) appear in Home ›
  To do and in My spaces.
* **Me gating**: Me's own rows are gated by account features, never by the
  last-used workspace's flags (today's `enabledFeaturesSync`); per-space
  gating is decided by the server when it returns items.

## 7. Delivery plan (one PR per slice, server first)

| # | Slice | Server | Client | Risk |
|---|---|---|---|---|
| 0 | This design + ADR 0038 | — | — | — |
| 1 | Invoice detail and Pay in Wallet | invoice-level intents, auto-match on settle (two migrations, harnessed) | invoice sheet in Me, Pay, how to pay, "I paid" | **money** — validation policy decides auto-confirm |
| 2 | Wallet › <space> page | `my_space_money(workspace)` aggregate (account, statement, credits, terms) | page + requests | low |
| 3 | Member Money tab → Wallet | — | members see a link; operators keep Invoicing | UX change — announce |
| 4 | Agenda | `my_bookings` + reminders for all spaces | Agenda tab, one .ics | low |
| 5 | To do + app badge | `my_pending` (decisions, requests, to pay) | Home To do, badge | medium (counts) |
| 6 | Access, Privacy picker, settings moves | per-space privacy reads by id | Me › Access, Privacy picker | low |
| 7 | Favourites unification | migrate local → 0376 tables | Me Home reads server | low |
| 8 | Personal item contract | `personal_item_sources`, `my_items` | renderer registry + generic fallback | foundation |
| 9 | Workspace kinds | `workspaces.kind`, kind profiles | Discover facet | foundation |
| 10 | Saved methods, multi-invoice checkout | `account_payment_profiles`, provider customer refs | How I pay | provider work, per provider |

Slices 1–7 deliver the UX the owner asked for on top of today's coworking
model; slices 8–9 make it extensible before a second kind exists; slice 10
follows real provider integrations.

## 8. Open decisions for the owner

1. **Auto-confirm online payments?** Should a captured online payment mark
   the invoice *paid* at once, or wait for an operator's confirmation
   (per the space's validation policy)? Recommendation: automatic, because
   the provider confirmed the capture.
2. **Member Money tab**: replace it by a link to Wallet for plain members
   (recommended), or keep a slim "this month" view?
3. **Saved payment methods**: worth the provider work now, or after a second
   kind? Recommendation: after slices 1–7.
4. **First non-coworking kind**: yoga (sessions with capacity, passes) is the
   closest to the existing model and the best pilot for slices 8–9.

## 9. Survey summary (2026-10-07)

* Online payment is per **month** (`payment_intents.period`), no invoice id;
  settlement posts a ledger credit and no invoice match. No saved methods
  anywhere; the only personal setting is the preferred provider.
* Me › Finances reads `my_finance_overview` (0380) and `my_financial_activity`
  (0304); it lacks pay, invoice detail, account position, statement,
  documents, requests; it opens `/money` on tap.
* Cross-workspace reads that exist: `my_inbox`, `my_finance_overview`,
  `my_financial_activity`, `my_guest_participations`,
  `my_workspace_applications`, `my_rights_requests`. Missing: bookings,
  decisions/requests, alerts, badges, privacy-by-id.
* No workspace kind exists; the lexicon (0223) renames 34 single words; the
  booking and billing model is seat- and half-day-shaped; invoices, ledger,
  payments, events, messenger, visits are kind-neutral.
* `workspace_favorites` / `workspace_ratings` (0376) already hold account-level
  favourites and ratings; Me Home's heart and stars are a second, local copy.
