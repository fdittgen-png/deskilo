<div align="center">

# DesKilo — Product Specification

**A coworking space belongs to the people who use it: a floor plan to book, a fair account for every member, the rules a community chooses for itself.**

[README](../README.md) &nbsp;·&nbsp; [Wiki](https://github.com/fdittgen-png/deskilo/wiki) &nbsp;·&nbsp; [User guide](https://fdittgen-png.github.io/deskilo/guide/en.html) &nbsp;·&nbsp; [Capabilities and evidence](product/CAPABILITIES.md) &nbsp;·&nbsp; [Decisions](decisions/)

</div>

**Status:** v2.0 — revised 2026-10-11 from v1.1 (validated by the owner 2026-07-07) · **Author:** Florian DITTGEN
**Repo:** `github.com/fdittgen-png/deskilo` · **License:** AGPL-3.0-or-later, with a commercial exception ([ADR 0031](decisions/0031-agpl-with-a-commercial-exception.md))
**Product name:** **DesKilo** (sibling of *Sparkilo*, the tankstellen fuel-price app)

This specification states **what the product is for and what it promises**, not how it is built. The framework, visual identity and working methodology are inherited from the tankstellen/Sparkilo project (§12–§15).

**How to read the status of a statement.** This document says what DesKilo does; it does not duplicate the table of what is shipped and proved. That table is [`product/CAPABILITIES.md`](product/CAPABILITIES.md), generated from `docs/product/capabilities.json`: per capability, whether the code is *shipped* or *roadmap* and which evidence covers it. Where this document and a later decision disagree, the [ADR](decisions/) is authoritative. Items that are not yet delivered are marked *(planned)* or listed in §16.

---

## 1. Vision & leitmotiv

A free, privacy-first, open-source app for **self-organised communities that share spaces** — first of all small coworking spaces that today juggle spreadsheets, group chats and trust — and for the people who move between such spaces. Every feature must serve at least one of four goals (the feature filter, tankstellen-style):

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, shared expenses, one transparent ledger per member, and the invoices that follow from it.
3. **Run the space without a landlord platform** — self-organised roles and approvals, no vendor lock-in, a backend a community hosts itself or shares on the reference deployment operated by Florian DITTGEN.
4. **Belong to a network, not a silo** — one personal account across spaces, a shared directory to find them, private conversations, and visibility each person chooses.

A proposal that serves none of these is pushed back on before any code is written.

**Market position (from research):** Seatsurfing (GPL, web) is the strongest open-source desk-booking tool but has *no billing/membership model*; Nadine covers coworking billing but is an aging Django web suite. DesKilo's differentiator is the combination: visual booking **plus** the community money layer **plus** the person-centred network, mobile-first, libre.

### 1.1 The product at a glance

| Module | What it gives people | Section |
|---|---|---|
| Spaces and the floor plan | A drawn, bookable plan per space, several floors, live occupancy | §3, §4, §10 |
| Booking and calendar | Walk-up and future reservations, series, rules, calendar views | §5, §6 |
| Memberships and the ledger | Plans, allowances, fee bands, packages, one ledger and statement per member | §7 |
| Invoicing, VAT and accounting | Invoices and corrections, VAT, e-invoicing, accounting exports, payments | §7.5–§7.8 |
| Roles, approvals and the decision surface | Additive and custom roles, quorums, an audit trail | §2, §8 |
| Shared expenses | Submit, approve, repartition, schedule | §9 |
| Me, directory, messenger, federation | One personal account across spaces and servers, private messages, a visibility matrix | §18 |
| Reports and documents | Printable statements, invoices and reports, a layout designer, a document library | §19 |
| Kiosk, badges and codes | Wall-tablet check-in, QR and NFC badges, seat codes | §4.5, §20 |
| Environments and deployment | A real side and a test side per space, deployment between them, configuration transfer | §21 |
| Assistants (MCP) | Assistants that act as a person, under the same approvals | §22 |
| Task recorder and guided tours | Record a task, review it, turn it into a guide anyone can follow | §23 |

---

## 2. Personas & roles

| Role | Description |
|---|---|
| **Worker** (member) | Belongs to the community, has a membership plan, checks in/out, reserves, submits expenses, sees and manages **their own** events and ledger. |
| **Administrator** | A worker with extra rights: manages events (reservations, payments, expenses) **for anybody**, configures booking rules, approves expenses. Cannot alter the physical workspace. |
| **Owner** | Everything an administrator can do, **plus**: create/edit the workspace (levels, offices, desks, seats), define membership plans and prices, manage roles, workspace-level settings. A workspace has ≥ 1 owner; owners can grant/revoke owner status (the last owner cannot be removed, only transferred). Co-owners are supported. |
| **Custom role** | A role the space defines for itself. It is an **additive grant** on top of the built-in roles, never a replacement ([ADR 0029](decisions/0029-a-custom-role-is-an-additive-grant.md)); a role matrix shows who may do what. |
| **Guest** | A non-member who uses a space as a visitor (a day package, a visit); the member's own page lists their visits as a guest. |
| **Managed profile** | A person an owner or administrator manages on someone's behalf (for example a member without a device). |

A person can hold several roles simultaneously (roles are additive). One user account can belong to **several workspaces** (communities); everything is scoped to the active workspace, and the personal layer (§18) spans all of them. The built-in checks are enforced by the database, not only by the app ([ADR 0020](decisions/0020-postgres-enforces-the-rules.md)).

---

## 3. Domain model (conceptual)

- **Workspace** — one coworking community: name, address, **country** (drives the default currency and format conventions — the owner may override the currency), time zone, opening hours, holidays and closure days, booking rules, membership plans, its look (wording, colours, a pattern, a symbol). A workspace may be a *site* of a multi-site organisation.
- **Level** — a floor of the workspace.
- **Office** — a room on a level; may be flagged *bookable as a whole* (booking it books all its seats — meeting-room style). A whole level may be bookable too.
- **Desk** — a piece of furniture inside an office, drawn on the grid. An office or desk may carry a price.
- **Seat** — **the bookable unit.** A 6-squares-wide × 4-squares-deep slot on a desk edge, with an orientation (which side the person sits on). A desk hosts 1..n seats. Every check-in and reservation targets exactly one seat — or one whole office or level when it is bookable as a unit.
- **Chair** — an attribute set of a seat (chair type + amenities: ergonomic chair, standing desk, external monitor, docking station, window seat…). Amenities are filterable when searching for a seat.
- **Member** — a user's participation in a workspace: role(s), membership plan, join date, status (active, paused, exited), an optional origin (the server or space they come from).
- **Membership plan** — see §7.
- **Reservation** — seat (or office/level) + member + start + end; states: *reserved → checked-in → completed*, or *cancelled*, or *released (no-show)*. May belong to a **series**.
- **Series** — a recurrence rule (pattern + series start + series end). Maximum series length is configurable per workspace.
- **Check-in / Check-out** — timestamps on a reservation. A spontaneous walk-up check-in atomically creates a reservation starting *now*.
- **Event** — the unifying auditable record. Types: **reservation events**, **payment events**, **expense events**, **adjustment events** (manual ledger corrections). Every event has an *actor* and a *subject*; when actor ≠ subject a **confirmation flow** applies (§8).
- **Ledger** — per member, per workspace: every charge (subscription, overage, package, service), every credit (approved expense, recorded payment, adjustment), a running balance, and monthly **statements**. The ledger is a running account and append-only ([ADR 0022](decisions/0022-the-ledger-is-a-running-account.md)).
- **Invoice** — a legal document issued from the ledger (§7.5).
- **Person** — the account behind the memberships, with a profile, conversations and privacy choices that belong to the person, not to a space (§18).

> **Resolved contradiction #1:** the original brief says check-in is "on the desk", elsewhere "to a chair or office". Resolution: the bookable unit is the **seat** (the 6×4 slot); the chair is a property of the seat; a whole office is bookable only when flagged as such. The grid model is [ADR 0005](decisions/0005-grid-floor-plan-model.md).

---

## 4. Floor plan: viewing, check-in, check-out

### 4.1 Live floor plan

- Renders the active level as a grid map: offices (room outlines), desks, seats; the plan and the day view fill the screen.
- Seat states are color-coded and never by colour alone: **free**, **reserved (upcoming)**, **occupied (checked in)**, **mine**, **blocked** (maintenance/blackout).
- Occupied/reserved seats show the occupant's name or photo — visibility is a **per-member privacy setting** (everyone / members only / nobody — default: members only), and a space can adjust desk transparency.
- Level switcher; pinch-zoom and pan; amenity filter dims non-matching seats; a list view and a day timeline show the same places.

### 4.2 Check-in (walk-up)

1. Worker taps a **free** seat.
2. A sheet opens with suggested times: start = **now**, end = workspace default (until closing time, or now + N hours). The worker may adjust.
3. Confirm → reservation + check-in are created **atomically** (no separate steps that can race).
4. If the seat has a later reservation by someone else, the walk-up end time is capped at that reservation's start and the worker is told.

> **Resolved pitfall (research):** walk-up vs. future reservation conflicts and double-booking races are the #1 failure mode of these systems. All availability decisions are transactional and conflict-checked by the database at confirmation time, never against a possibly-stale view.

### 4.3 Check-in (on a reservation)

- A reservation opens a **check-in window** (configurable, default: 15 min before start).
- Reminder notification at window start.
- **No-show auto-release** (configurable, default 30 min after start, can be disabled): the reservation is released, the seat returns to the pool and the member is notified. Billing treatment of no-shows is configurable.
- Check-in and check-out can also be automatic where the space enables it.

### 4.4 Check-out

- Manual check-out from the plan or the event detail.
- **Auto check-out** at reservation end or workspace closing time, whichever comes first.
- Usage-based billing bills **by reservation** (it blocks the seat); an owner may switch the workspace to bill by actual checked-in presence instead.

### 4.5 Codes and badges

Each seat and each space can have a printable **QR code**; scanning it opens that seat's check-in sheet directly. A member can sign in and check in with a **badge** (QR or NFC, optionally with a PIN). The wall-tablet **kiosk** is described in §20.

---

## 5. Reservations

### 5.1 Punctual reservation

Seat (or bookable office or level) + date + start/end time, made from the floor plan, from the calendar, or from a list of available places (with amenity filters). An administrator can **book for someone else**; that follows the confirmation protocol (§8).

### 5.2 Series reservation

- Recurrence patterns: daily, every weekday, weekly on selected weekdays, every N weeks, monthly.
- Series has start and end; **max series duration is configurable per workspace** (default 6 months), as is the **advance-booking horizon** (default 3 months ahead).
- **Conflict handling:** at creation, all instances are checked. Non-conflicting instances are booked; conflicting instances are listed as **exceptions** for the worker to resolve. A series is never silently partial.
- Editing scope is always explicit: **this occurrence** vs. **this and following** vs. **the entire series**.
- Closure days, public holidays and blackout dates skip instances (shown as skipped, not conflicts). Generated closure days never rewrite an invoiced month ([ADR 0025](decisions/0025-generated-closure-days-never-rewrite-an-invoiced-month.md)).

### 5.3 Booking rules engine (per workspace, set by owner)

| Rule | Default |
|---|---|
| Advance-booking horizon | 3 months |
| Max series duration | 6 months |
| Min / max reservation duration | 30 min / 1 day |
| Max concurrent future reservations per member | 10 |
| Simultaneous reservations | per plan |
| Per-plan usage allowances | see §7 |
| Cancellation deadline (after which a cancellation still counts as usage) | 2 h before start |
| Check-in window / no-show release | 15 min before / 30 min after |
| Booking granularity (half-day by default) and working hours | owner-defined |
| Opening days, closure days, public holidays (importable) | owner-defined |
| Bookings outside opening hours; bookings in the past; administrators' check-out | owner-chosen mode |
| Approval-required resources (e.g. the meeting office) | off |

The questionnaire at `web/setup.html` lets a community prepare these rules in a browser before opening the app, and the app can import its answers.

### 5.4 Waitlist (planned)

**Not implemented yet.** The intent: when a desired seat/time is taken, the worker can join a waitlist; on cancellation or no-show release, waitlisted members are notified in order (first to confirm wins).

---

## 6. Calendar & time scroller

- **Calendar space**: agenda, week and month views of the member's own reservations (admins can widen the scope); decisions waiting for the person appear on the Calendar; filters narrow it. Tapping a slot starts a reservation.
- **Reserve hub**: the floor plan with a Day, Week and Month view; scrolling the time re-renders seat occupancy **at the selected moment**. "Now" returns to the live view.
- A **visual view** (floor plan) and a **list view** exist, one tap apart.
- **Calendar export**: a booking can be saved to the person's own calendar as a file. A subscribable **ICS/CalDAV feed** is *(planned)* — see `calendar.interchange` in [`product/CAPABILITIES.md`](product/CAPABILITIES.md).

---

## 7. Membership, billing and payments

### 7.1 Plans (owner-defined)

Billing is built on the **allowance + overage** model that commercial coworking platforms use — a base subscription that includes a usage allowance, with metered use beyond it. The usage unit is the **half-day** by default; an owner may choose another granularity. All amounts are in the **workspace currency**, which defaults from the workspace country.

Plans are **fully configurable** rather than a fixed set of three ([ADR 0008](decisions/0008-billing-v2-percentage-bands.md), superseding the plan model of [ADR 0006](decisions/0006-quota-overage-billing.md)):

- membership expressed as a **percentage** of full use, with **fee bands** over percentage ranges;
- **subscription levels** and per-member settings, including **price negotiation** for an individual member;
- **day packages** and **carnets** (prepaid allowances);
- sellable **services** and **accessories** (coffee, printing, a meeting room) added to the monthly bill;
- **overage** rules for use beyond the allowance, and the number of simultaneous reservations a plan allows.

The default scenarios remain the intent: a *full* plan with unlimited use, a *half* plan with an allowance and overage, a *flex* plan billed per use. They are examples an owner can reproduce, not special cases ([resolved contradiction #2](decisions/0008-billing-v2-percentage-bands.md): "50% and if more, pay more" is a plan with overage, not a fourth plan).

### 7.2 Plan changes, proration, pauses

- Plan changes take effect **at the next billing cycle** by default; the owner may apply them immediately with **prorated** charges, explicitly labelled on the statement.
- Memberships can be **paused** and **exited**. On exit the ledger stays open until the balance is settled; a positive balance is settled by refund or donation to the community.

### 7.3 The ledger & statements

Each member sees, in their money space:

- **Charges**: subscription, overage lines (with the reservations that caused them), packages, services, no-show fees (if enabled).
- **Credits**: approved expenses (§9), payments, adjustments.
- **Running balance** and a **monthly statement** with status **paid / partially paid / unpaid**; statement history, printable and exportable for bookkeeping; payment reminders and finance alerts.
- A booking shows **what it cost**.

The same figures are visible to the member and to whoever runs the space.

### 7.4 Payments

The app **records and tracks** payments and can **collect** them online. A payment event = amount + date + method + note, recorded by the member ("I paid") or by an admin ("received from X") — either way the *other* side confirms (§8). Per-workspace payment instructions (IBAN, reference) are shown on unpaid statements.

**Online payments** go through PayPal, Stripe, Mollie or Wero, behind the `onlinePayments` feature flag, **off by default**. The founding constraint stands ([ADR 0021](decisions/0021-payments-never-touch-the-client.md)): no payment SDK is linked into the app; every provider call happens in a server function and the app only opens the provider's hosted page. A provider-verified capture needs no human witness; a manual claim still needs the §8 confirmation. Evidence per provider is in [`product/CAPABILITIES.md`](product/CAPABILITIES.md) (`payments.*`); the design is in `docs/design/payments-integration.md`.

### 7.5 Invoicing

From the ledger, a space issues **invoices and corrections** (credit notes, voids), on a schedule or on request, with number sequences, the issuer's legal identity, payment terms, late-payment mentions and special mentions. A member can ask for an invoice; invoices follow the same approval rules as other decisions. A space may **invoice on behalf of** a person without it touching their private finances: a person's own finances live in Me, a space's invoicing in the workspace ([ADR 0035](decisions/0035-my-finances-in-me-invoicing-in-the-workspace.md)). An invoice is a legal record: it is retained, not erased, with an account erasure.

### 7.6 VAT

VAT is configurable per workspace and per member: regimes, rates and groups, rate changes by law with their history, reverse charge for EU businesses ([ADR 0016](decisions/0016-reverse-charge.md)), cash-basis exigibility ([ADR 0017](decisions/0017-cash-basis-exigibility.md)), place of supply, EU VAT-number checks (VIES) kept as evidence, an EU sales list, and a prepared **VAT return**. A filed VAT period is **locked** ([ADR 0039](decisions/0039-a-filed-vat-period-is-locked.md)). The compliance review is [ADR 0015](decisions/0015-vat-compliance-review.md). DesKilo prepares the figures; filing and certification stay with the owner and their accountant — no certification claim is made.

### 7.7 E-invoicing

Structured electronic invoices can be generated, delivered to a customer service and transmitted to an e-invoicing platform the owner configures ([ADR 0010](decisions/0010-e-invoice-transmission.md)). Real provider acceptance must be validated for each intended setup.

### 7.8 Accounting exports

Statements and invoices export for bookkeeping in the formats accountants use, including DATEV and the French FEC (see the guide chapter *Tax, invoicing and accounting*). Each format claims only what it covers; the books of record stay with the accountant.

---

## 8. Events, approvals & the confirmation protocol

### 8.1 The Events space

A filterable, time-sorted feed of events (reservations, payments, expenses, adjustments, invoices).

- **Worker** sees only events where they are subject or actor.
- **Admin/Owner** sees all events, with filters (person, type, status, date range).
- Every change produces a new auditable event (nothing is silently rewritten).
- **Pending confirmations** are pinned on top with clear accept/reject actions. A **decision surface** ([ADR 0023](decisions/0023-the-decision-surface.md)) gathers what needs the person across calendar, events and Me.

### 8.2 Confirmation protocol (actor ≠ subject)

When an admin or owner creates, modifies, or deletes an event **for somebody else**, it enters state **pending** and the subject must confirm:

- The subject is notified and **accepts** or **rejects** (with an optional note).
- While pending, a reservation **tentatively blocks the seat**; a pending *deletion* does **not** yet free the seat.
- **Timeout:** reminder after 48 h; after a configurable period (default 7 days) the event **auto-confirms** — except deletions of another person's reservation and ledger *debits*, which **auto-expire**. The owner can force-apply any pending event; forcing is itself an audited event.
- Acting on **yourself** never requires confirmation.

### 8.3 Validation rules

Beyond the two-person protocol, a workspace configures **validations domain by domain** (joining, expenses, deletions, invoices, settings, subscription and status changes…): the number of required validations (a quorum), who may validate, whether validation is sequential, and whether an owner's or administrator's own request auto-validates. The database enforces the rule it records and keeps the decision trail. A single write path serves process intent ([ADR 0027](decisions/0027-one-write-path-for-process-intent.md)). Deletions can be requested and decided in the same way.

---

## 9. Shared expenses

1. A worker buys something for the community and submits an **expense**: amount, date, category, description, **receipt photo**.
2. An **admin approves or rejects** it (self-approval is not allowed).
3. On approval, the amount is **credited to the purchaser's ledger**, offsetting their next charges; alternatively an admin records a reimbursement.
4. An expense can be **repartitioned** between members by a repartition key (a wizard guides it), and an owner can **schedule** recurring expenses and track supplies.
5. The expense total per period is visible to owner/admins (and to all members if the owner enables "transparent books").

**Not planned for the present scope:** Splitwise-style debt simplification between arbitrary member subsets.

---

## 10. Workspace editor (owner only)

A dedicated editor for drawing the physical workspace on a **grid of small squares**:

- **Canvas** per level: pan/zoom grid; add/rename/reorder/remove **levels**; a single-room space can name its levels simply.
- **Draw offices**: room outlines on the grid; name them; flag *bookable as a whole*; set a colour and, if wanted, a price.
- **Draw desks**: rectangles of squares inside offices; any size; rotate in 90° steps.
- **Place seats**: a seat stamps a **6 × 4** footprint onto a desk edge with an orientation. The editor validates fit and overlap. Seats are auto-numbered, renamable.
- **Assign chairs/amenities** per seat.
- **Block/unblock** any seat, desk or office (maintenance) with an optional date range.
- Editing is safe against live data: removing a seat/desk/office with **future reservations** requires the owner to resolve them first; affected members are notified per §8.
- The grid square is an abstract unit; the 6×4 seat footprint is the fixed normative size. Floor-plan images and placeholders can be added to the plan.

Beyond the plan, the owner configures the space: which processes and **features** are on (every functionality sits behind a feature flag that degrades honestly when off, with dependencies explained), the country, currency and time zone, the letterhead, wording, colours and pattern, a public workspace page, and roles. A configuration can be exported and imported ([ADR 0026](decisions/0026-a-workspace-template-is-the-deployment-engine-in-merge-mode.md)).

---

## 11. Cross-cutting product requirements

- **Languages:** the app is fully multilanguage — **every user-facing string is translatable** (ARB-based, lint-enforced). **English is the canonical locale**; **French, German, Spanish and Italian** are maintained, and the user guides, the setup questionnaire and the in-app help exist in all five ([ADR 0007](decisions/0007-i18n-five-locales.md)). User-generated content is not translated. Workspaces can also set their own vocabulary.
- **Country-driven formats:** the workspace **country** determines the default **currency**; dates, numbers and currency are always rendered through locale-aware formatting. A member may choose their own clock, number and time-zone display.
- **Notifications:** booking confirmations, reminders, no-show releases, pending confirmations, expense decisions, statements and payment reminders; grouped and per-person. Delivery: in-app and push (FCM on store builds, [ADR 0011](decisions/0011-notifications-first-fcm.md); a build without Google services exists for F-Droid, [ADR 0012](decisions/0012-fdroid-via-foss-push-package.md)).
- **Time zones & DST:** all times stored as UTC + the workspace's IANA time zone; recurring series recur in **workspace-local time**.
- **Offline behaviour:** read access to the plan, own events and ledger works from a local cache; *writes* (check-in, reservation) need connectivity, since they are multi-user and transactional.
- **Privacy / GDPR:** minimal data; per-person visibility control (§18); personal-data **export** and account **erasure** — financial history is **retained, not anonymised** (the ledger and invoices are the workspace's accounting records; the erasing member's profile is what is cleared; see the retention matrix in [`PRIVACY.md`](../PRIVACY.md)); a **data-access log**; no tracking and no third-party analytics. The threat model is [`security/THREAT_MODEL.md`](security/THREAT_MODEL.md).
- **Analytics (owner/admin):** occupancy and capacity per level/office/day, peak hours, no-show rate, allowance consumption and finance KPIs.
- **Accessibility:** state never conveyed by colour alone, minimum tap targets, screen-reader labels, keyboard use on desktop and web, an animation switch.
- **Help:** contextual help symbols on forms, an in-app help centre and guides by audience (member, owner, technical administrator), kept in step with the app.
- **Onboarding:** a new user **explores the demo workspace** (self-contained, no server), **creates a workspace** (becomes owner, with an instance wizard) or **joins one** via workspace ID, link or QR code (an administrator approves). A *Get started* card and tips guide the first steps.
- **The demo workspace** is a repository seam, not a special case ([ADR 0028](decisions/0028-the-demo-environment-is-the-repository-seam.md)); a reset is a new fixture ([ADR 0030](decisions/0030-a-demo-reset-is-a-new-fixture.md)).

---

## 12. Platforms & distribution

| Platform | Channel |
|---|---|
| **Web** | Browser app (GitHub Pages deploy, opt-in); NFC and camera scanning guarded off |
| **Android** | Google Play closed test; per-ABI builds; a separate F-Droid build without Google services |
| **iPhone / iPad** | TestFlight public beta |
| **Windows** | WiX MSI, attached to the GitHub release |
| **macOS** | Developer-ID-signed, notarised DMG, attached to the GitHub release (notarisation is required since macOS 15) |

- **Licence:** AGPL-3.0-or-later, SPDX headers in every file, with an app-store exception and a commercial licence ([ADR 0031](decisions/0031-agpl-with-a-commercial-exception.md)).
- **No** Google Play Services in the free build, **no** third-party tracking, **no** GPL dependencies.
- The release process and gates are in `docs/guides/RELEASING.md`; the status of each store is in the README.

## 13. Technical framework (principles only)

- **Flutter** (pinned stable) / Dart; **Riverpod 3 with codegen**; **freezed** models; **go_router**; **flex_color_scheme** theming; encrypted local storage.
- **Backend: Supabase** — auth, RLS-protected Postgres as the shared source of truth, server functions for transactional booking checks and provider calls. **Postgres enforces the rules** the app shows ([ADR 0020](decisions/0020-postgres-enforces-the-rules.md)). Self-hostable, so the libre promise holds; a community can also use the reference deployment ([ADR 0002](decisions/0002-supabase-backend.md)).
- The app's destinations: **Reserve** (floor plan and day/week/month views), **Calendar**, **Events**, **Money**, **Me**, plus the owner's editor and Settings. The navigation style is a personal choice. An application layer is organised one context at a time ([ADR 0024](decisions/0024-an-application-layer-one-context-at-a-time.md)).
- The system columns every table carries are [ADR 0018](decisions/0018-system-columns.md).

## 14. Visual identity (inherited from tankstellen/Sparkilo)

- **Material 3** via flex_color_scheme; **light**, **dark** and a signature warm theme.
- **Brand colour: orange** (muted burnt orange), finalised in [`design/DESIGN_SYSTEM.md`](design/DESIGN_SYSTEM.md). Each space can set its own colours, pattern and symbol on top.
- **AppRadius tokens**, no inline border radii (lint-enforced).
- **Seat-state palette**: muted, colourblind-safe hues for free / reserved / occupied / mine / blocked, tokenised in one file.

## 15. Methodology & repo organisation

- GitHub Flow: branch off `master`, conventional commits, one concern per branch, **every change is a PR under 400 lines**, squash-merge, `Refs`/`Closes #NN`, no direct commits to master.
- **Issue-first**: no code without a GitHub issue; work larger than one PR is split into finite checkpoints.
- **Hard rules:** no hard-coded user-facing strings; clean codegen before push; locale key parity; the setup questionnaire never lags the app; every functionality behind a `WorkspaceFeature` flag.
- **Tests:** a 70/20/10 pyramid as the target, fakes over mocks, failing-test-first for bugs, database claims proved in pgTAP; the **quality report** is the merge gate.
- **ADRs** in [`decisions/`](decisions/); issue templates and a PR template; [`CONTRIBUTING.md`](../CONTRIBUTING.md) and [`AGENT_RULES.md`](AGENT_RULES.md). The repository has no separate code-of-conduct file.

---

## 16. Roadmap

The delivered/planned split lives in [`product/CAPABILITIES.md`](product/CAPABILITIES.md) and in the open [epics](https://github.com/fdittgen-png/deskilo/issues?q=is%3Aissue+is%3Aopen+label%3Aepic); this section keeps only the intent.

- **Delivered in substance** (see CAPABILITIES for evidence): the editor and floor plan, booking with series and rules, the ledger and statements, approvals, shared expenses, online payments, invoicing, VAT, e-invoicing and accounting exports, reports, the person-centred layer, kiosk and badges, environments, assistants, the task recorder, five languages, the platforms of §12.
- **Planned or in validation:** a subscribable calendar feed, storage-level recovery, live validation of payment providers and e-invoice transmission against real counterparties, public store releases, further space kinds beyond coworking (see [ADR 0038](decisions/0038-the-me-space-holds-everything-personal.md), *proposed*), and Splitwise-style debt simplification.
- **Honest maturity:** DesKilo is in beta and best suited to communities willing to run a pilot; accounting acceptance, provider reliability and operations need validation for each operator's own use.

---

## 17. Decisions log

| Decision | Value | Status |
|---|---|---|
| App name | **DesKilo** | decided 2026-07-07 |
| Backend | **Supabase**, self-hostable ([ADR 0002](decisions/0002-supabase-backend.md)) | decided |
| Brand colour | **Orange** | decided |
| Billing unit | **Half-day** by default, owner-configurable granularity | decided |
| Currency and units | From the workspace country, owner-overridable | decided |
| Languages | **English (canonical) + FR, DE, ES, IT** | decided |
| Licence | AGPL-3.0-or-later with a commercial exception | decided ([ADR 0031](decisions/0031-agpl-with-a-commercial-exception.md)) |
| Application ID | **`de.deskilo.app`** | decided 2026-07-07 |
| Reference deployment | Hosted Supabase operated by the author; self-hosting supported | decided |
| Payments | Recorded or collected online; provider calls only on the server | decided ([ADR 0021](decisions/0021-payments-never-touch-the-client.md)) |
| Messenger | Lives in Me, not in a workspace | decided ([ADR 0034](decisions/0034-the-messenger-lives-in-me.md)) |
| Task recorder | Makes no video; recording privacy substitutes people | decided ([ADR 0036](decisions/0036-the-task-recorder-makes-no-video.md), [0032](decisions/0032-recording-privacy-substitutes-people-at-the-data-seam.md)) |

---

## 18. The person-centred layer: Me, directory, messenger, federation

A person is more than a member of one space. The **Me** space holds everything that personally concerns them ([ADR 0038](decisions/0038-the-me-space-holds-everything-personal.md), design in [`design/ME_SPACE.md`](design/ME_SPACE.md)): a home across their spaces (which they can favourite, rate and reorder), an agenda, their invoices and payments across spaces ([ADR 0035](decisions/0035-my-finances-in-me-invoicing-in-the-workspace.md)), decisions waiting for them, badges and privacy.

- **Members directory** inside a space, with a member page (status line, contact channels, optional photo, visits as a guest).
- **Public profile and shared directory:** a space may **publish a page** in the shared directory and on a map, on purpose and withdrawably; people can find spaces and send an **inquiry**. A person may publish a public profile. Nothing is public by default.
- **Messenger** ([ADR 0034](decisions/0034-the-messenger-lives-in-me.md)): conversations and groups, references to bookings and invoices inside messages, forwarding, **message requests** from people you do not yet know, a **block list**. The workspace keeps only its alerts. A conversation's content is visible to its participants only, never to a space operator.
- **Privacy matrix:** every profile field (identity, about, contact channels, presence, reachability) is private by default and shown only to the audience the person picks, per field ([`design/MESSENGER_VISIBILITY.md`](design/MESSENGER_VISIBILITY.md)). Capture-protection options exist for sensitive screens.
- **Federation:** a person who belongs to spaces on several servers can **connect them** and see them in one Me; a member may come from another server (their origin is recorded). A space chooses its server in Settings → Advanced.

## 19. Reports and documents

Everything printable — statements, invoices, usage and VAT reports, member reports, letters — is produced from **report kinds** with placeholders, banded defaults or **positioned layouts** ([ADR 0013](decisions/0013-positioned-report-layouts.md)). Owners get a **report designer**, ready-made templates, one design per language, the letter standard, and exchange of designs between spaces. A technical administrator also has a command-line tool to check, render and describe reports. A workspace **document library** holds files members can open.

## 20. Kiosk, badges and codes

A **kiosk mode** turns a wall tablet into a check-in point: members identify with a QR or NFC **badge** (optionally with a PIN, optionally with their photo shown), and the sign-in refuses in the same way whatever the reason. Seats and spaces carry QR and NFC tags. Each of these is behind its own feature flag.

## 21. Environments and deployment

A space can have **two sides**: the real one (production) and a test one (development) ([ADR 0019](decisions/0019-invitation-environments.md)). A member may belong to either, the owner enters either side, and who may **deploy** between them and enter production is a permission. Deployment reuses the configuration transfer in merge mode ([ADR 0026](decisions/0026-a-workspace-template-is-the-deployment-engine-in-merge-mode.md)). A space also has a **status** and a **year archive**. Self-hosting an instance is guided by an instance wizard and checked by an instance doctor.

## 22. Assistants (MCP)

An **assistant** — a program speaking the Model Context Protocol — can act **as a person**, with the same roles, the same approvals and the same refusals as that person in the app. A person connects an assistant explicitly and consents to what it may do; reads and writes are separate capabilities, and a write that needs another person's approval waits for it. The goal is functional parity with the app, not a back door. The state of each capability is `mcp.*` in [`product/CAPABILITIES.md`](product/CAPABILITIES.md).

## 23. Task recorder and guided tours

A person can **record a task** they perform in the app: the steps, not the screen — **no video** ([ADR 0036](decisions/0036-the-task-recorder-makes-no-video.md)). A recording can be reviewed, edited and exported; **recording privacy** substitutes real people with placeholders at the data seam ([ADR 0032](decisions/0032-recording-privacy-substitutes-people-at-the-data-seam.md)); values are captured only by the person's choice ([ADR 0037](decisions/0037-a-recording-may-capture-values-by-choice.md)). A recording can become a **guide** that others follow step by step inside the app, with a circle menu to edit or repair it. The tutorial video encoder is a platform one ([ADR 0033](decisions/0033-tutorial-video-uses-the-platform-encoder.md)).
