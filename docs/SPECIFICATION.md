# DesKilo — Coworking Community App — Product Specification

**Status:** v1.1 — validated by owner (2026-07-07) · **Author:** Florian DITTGEN
**Repo:** `github.com/fdittgen-png/deskilo` · **License:** MIT
**Product name:** **DesKilo** (sibling of *Sparkilo*, the tankstellen fuel-price app)

This specification is deliberately free of implementation detail. The framework, visual identity, and working methodology are inherited from the **tankstellen/Sparkilo** project (see §12–§15).

---

## 1. Vision & leitmotiv

A free, privacy-first, open-source app for **small self-organized coworking communities** that today juggle spreadsheets, group chats, and trust. Every feature must serve at least one of three goals (the feature filter, tankstellen-style):

1. **Know where you can sit** — live floor plan, check-in/out, reservations.
2. **Know what you owe / are owed** — subscription, extra usage, community expenses, one transparent ledger per member.
3. **Run the space without a landlord platform** — self-organized roles, no vendor lock-in, self-hostable data, works on F-Droid.

A proposal that serves none of these is pushed back on before any code is written.

**Market position (from research):** Seatsurfing (GPL, web) is the strongest open-source desk-booking tool but has *no billing/membership model*; Nadine covers coworking billing but is an aging Django web suite; on F-Droid the niche is **empty** — no desk-booking or coworking client exists there. DesKilo's differentiator is the combination: visual booking **plus** the community money layer, mobile-first, libre.

---

## 2. Personas & roles

| Role | Description |
|---|---|
| **Worker** (member) | Belongs to the community, has a membership plan, checks in/out, reserves, submits expenses, sees and manages **their own** events and ledger. |
| **Administrator** | A worker with extra rights: manages events (reservations, payments, expenses) **for anybody**, configures booking rules, approves expenses. Cannot alter the physical workspace. |
| **Owner** | God mode. Everything an admin can do, **plus**: create/edit the workspace (levels, offices, desks, seats, chairs), define membership plans and prices, manage roles, workspace-level settings. A workspace has ≥ 1 owner; owners can grant/revoke owner status (the last owner cannot be removed, only transferred). |
| **Guest** (v2) | A non-member with a day pass, invited by a member or admin. |

A person can hold Worker + Admin + Owner simultaneously (roles are additive). One user account can belong to **several workspaces** (communities); the app scopes everything to the active workspace.

---

## 3. Domain model (conceptual)

- **Workspace** — one coworking community: name, address, **country** (drives the default currency and measurement/format conventions — owner may override the currency), time zone, opening hours, holidays/blackout dates, booking rules, membership plans.
- **Level** — a floor of the workspace.
- **Office** — a room on a level; may be flagged *bookable as a whole* (booking it books all its seats — meeting-room style).
- **Desk** — a piece of furniture inside an office, drawn on the grid.
- **Seat** — **the bookable unit.** A 6-squares-wide × 4-squares-deep slot on a desk edge, with an orientation (which side the person sits on). A desk hosts 1..n seats. Every check-in and reservation targets exactly one seat — or one whole office when it is bookable as a unit.
- **Chair** — an attribute set of a seat (chair type + amenities: ergonomic chair, standing desk, external monitor, docking station, window seat…). Amenities are filterable when searching for a seat.
- **Member** — a user's participation in a workspace: role(s), membership plan, join date, status (active, paused, exited).
- **Membership plan** — see §7.
- **Reservation** — seat (or office) + member + start + end; states: *reserved → checked-in → completed*, or *cancelled*, or *released (no-show)*. May belong to a **series**.
- **Series** — a recurrence rule (pattern + series start date/time + series end date/time). Maximum series length is configurable per workspace.
- **Check-in / Check-out** — timestamps on a reservation. A spontaneous walk-up check-in atomically creates a reservation starting *now*.
- **Event** — the unifying auditable record shown in the Events space. Types: **reservation events** (created / modified / cancelled), **payment events** (a payment recorded against a member's balance), **expense events** (submitted / approved / rejected), **adjustment events** (manual ledger corrections by admin/owner). Every event has an *actor* and a *subject*; when actor ≠ subject a **confirmation flow** applies (§8).
- **Ledger** — per member, per workspace: every charge (subscription, overage, day pass), every credit (approved expense, recorded payment, adjustment), a running balance, and monthly **statements** with a paid / partially paid / unpaid status.

> **Resolved contradiction #1:** the original brief says check-in is "on the desk", elsewhere "to a chair or office". Resolution: the bookable unit is the **seat** (the 6×4 slot); the chair is a property of the seat; a whole office is bookable only when flagged as such.

---

## 4. Floor plan: viewing, check-in, check-out

### 4.1 Live floor plan

- Renders the active level as a grid map: offices (room outlines), desks, seats.
- Seat states are color-coded: **free**, **reserved (upcoming)**, **occupied (checked in)**, **mine**, **blocked** (maintenance/blackout).
- Occupied/reserved seats show the occupant's name/avatar — visibility is a **per-member privacy setting** ("show my name on the plan": everyone / members only / nobody — default: members only).
- Level switcher; pinch-zoom and pan; amenity filter dims non-matching seats.

### 4.2 Check-in (walk-up)

1. Worker taps a **free** seat.
2. Sheet opens with suggested times: start = **now**, end = workspace default (configurable: until closing time, or now + N hours). Worker may adjust.
3. Confirm → reservation + check-in are created **atomically** (no separate steps that can race).
4. If the seat has a later reservation by someone else, the walk-up end time is capped at that reservation's start and the worker is told.

> **Resolved pitfall (research):** walk-up vs. future reservation conflicts and double-booking races are the #1 failure mode of these systems. All availability decisions are transactional and conflict-checked at confirmation time, never against a possibly-stale view.

### 4.3 Check-in (on a reservation)

- A reservation opens a **check-in window** (configurable, default: 15 min before start).
- Reminder notification at window start: "Check in or your seat is released."
- **No-show auto-release** (configurable, default 30 min after start, can be disabled): the reservation is released, the seat returns to the pool, the member is notified, and — if a waitlist exists — the first waitlisted member is notified. Billing treatment of no-shows is configurable (charged / not charged / charged after N no-shows per month).

### 4.4 Check-out

- Manual check-out from the plan or the event detail.
- **Auto check-out** at reservation end or workspace closing time, whichever comes first.
- Usage-based billing bills **by reservation** (it blocks the seat); an owner may switch the workspace to bill by actual checked-in presence instead.

### 4.5 QR check-in (v1.1)

Each seat gets a printable QR code (generated by the app). Scanning it opens that seat's check-in sheet directly — supporting walk-ups without hunting through the floor plan. (Scanner: libre `flutter_zxing` path as in Sparkilo's F-Droid flavor.)

---

## 5. Reservations

### 5.1 Punctual reservation

Seat (or bookable office) + date + start/end time, made from the floor plan (tap a seat while a future time is selected on the time scroller), from the calendar, or from a list of available seats (with amenity filters).

### 5.2 Series reservation

- Recurrence patterns: daily, every weekday, weekly on selected weekdays, every N weeks, monthly.
- Series has start date/time and end date/time; **max series duration is configurable per workspace** (default 6 months), as is the **advance-booking horizon** for any reservation (default 3 months ahead).
- **Conflict handling (resolved gap):** at creation, all instances are checked. Non-conflicting instances are booked; conflicting instances are listed as **exceptions** for the worker to resolve (pick another seat, skip, or waitlist). A series is never silently partial.
- Editing scope is always explicit: **"this occurrence"** vs. **"this and following"** vs. **"entire series"**.
- Holidays/blackout dates automatically skip instances (shown as skipped, not conflicts).

### 5.3 Booking rules engine (per workspace, set by owner)

| Rule | Default |
|---|---|
| Advance-booking horizon | 3 months |
| Max series duration | 6 months |
| Min / max reservation duration | 30 min / 1 day |
| Max concurrent future reservations per member | 10 |
| Per-plan usage quotas | see §7 |
| Cancellation deadline (after which a cancellation still counts as usage) | 2 h before start |
| Check-in window / no-show release | 15 min before / 30 min after |
| Opening hours & weekly schedule; holidays/blackout dates | owner-defined |
| Approval-required resources (e.g. the meeting office) | off |

### 5.4 Waitlist (v1.1)

When a desired seat/time is taken, the worker can join a waitlist; on cancellation or no-show release, waitlisted members are notified in order (first to confirm wins).

---

## 6. Calendar & time scroller

- **Calendar space**: month / week / day views of the member's own reservations (admins can switch to "everyone"). Tapping a slot starts a reservation.
- **Time scroller**: a horizontal timeline control attached to the floor plan. Dragging it re-renders seat occupancy **at the selected moment** — scroll through today, tomorrow, next week and watch the plan change. Snap points at opening hour boundaries. "Now" button returns to live view.
- Both a **visual view** (floor plan + scroller) and a **list view** (chronological reservations for the selected day/seat) exist, one tap apart.
- **ICS/CalDAV export** (v1.1): personal reservation feed subscribable from any calendar app (as Seatsurfing offers).

---

## 7. Membership plans & billing model

### 7.1 Plans (owner-defined; these are the shipped defaults)

Billing is built on the **quota + overage** model that commercial coworking platforms (Cobot, Nexudus, OfficeRnD) use — a base subscription including a usage quota, with metered overage beyond it. The usage unit is the **half-day** (decided; a workspace owner may switch to full days). All amounts are in the **workspace currency**, which defaults from the workspace country.

| Plan | Base subscription | Included quota / month | Overage |
|---|---|---|---|
| **Full (100%)** | fixed monthly fee | unlimited | — |
| **Half (50%)** | fixed monthly fee | e.g. 22 half-days | per extra half-day, at the workspace overage rate |
| **Flex ("sometimes")** | small or zero monthly fee | 0 (or small allowance) | every half-day billed at the flex rate |
| **Guest / day pass** (v2) | none | none | flat day-pass price |

> **Resolved contradiction #2:** the brief lists "100%, 50%, sometimes, or 50% and then, if more, paying more". Resolution: *"50% and if more, pay more"* **is** the Half plan with overage — it is not a fourth plan. "Sometimes" is the Flex plan. Owners can add further plans with any quota/fee/overage combination.

### 7.2 Plan changes, proration, pauses

- Plan changes take effect **at the next billing cycle** by default; the owner may apply them immediately with **prorated** charges (prorated lines are explicitly labelled on the statement — research shows unlabelled proration is a top dispute trigger).
- Memberships can be **paused** (no fee, no access) and **exited**. On exit the ledger stays open until the balance is settled; a positive balance is settled by refund or donation to the community (owner records which).

### 7.3 The ledger & statements

Each member sees, in their money space:

- **Charges**: monthly subscription, overage lines (with the reservations that caused them), day passes, no-show fees (if enabled).
- **Credits**: approved expenses (§9), payments recorded, manual adjustments.
- **Running balance** and a **monthly statement** with status **paid / partially paid / unpaid** — this answers the brief's core requirement "manage whether the subscription and/or the additional time consumed is paid".
- Statement history, exportable (CSV/PDF) for bookkeeping.

### 7.4 Payments

The app **records and tracks** payments; it does **not process** them (no Stripe/PSP in v1 — keeps the F-Droid build clean and fits a trust-based community that pays by bank transfer/cash/Twint/etc.). A payment event = amount + date + method + note, recorded by the member ("I paid") or by an admin ("received from X") — either way the *other* side confirms (§8). Optional per-workspace payment instructions (IBAN, reference format) are shown on unpaid statements. Payment-provider integration is explicitly out of scope for v1 and revisited in v2.

---

## 8. Events space & the confirmation protocol

### 8.1 The Events space

A dedicated tab: a filterable, time-sorted feed of events (reservations, payments, expenses, adjustments).

- **Worker** sees only events where they are subject or actor.
- **Admin/Owner** sees all events, with filters (person, type, status, date range).
- Events are editable in place according to role; every change produces a new auditable event (nothing is silently rewritten).
- **Pending confirmations** are pinned on top with clear accept/reject actions.

### 8.2 Confirmation protocol (actor ≠ subject)

When an admin or owner creates, modifies, or deletes an event **for somebody else**, it enters state **pending** and the subject must confirm:

- The subject gets a notification and sees the pending item in the Events space; **accept** or **reject** (rejection requires an optional note).
- While pending, a reservation **tentatively blocks the seat** (so the slot can't be double-booked), but a pending *deletion* does **not** yet free the seat.
- **Timeout (resolved gap — the brief left this undefined):** reminder after 48 h; after a configurable period (default 7 days) the event **auto-confirms** — except deletions of another person's reservation and ledger *debits*, which **auto-expire** instead (destructive/costly actions never auto-apply). The owner can force-apply any pending event; forcing is itself an audited event visible to the subject.
- Acting on **yourself** (admin books for themselves, worker cancels their own seat) never requires confirmation.

---

## 9. Community expenses

The brief's expense feature, modeled on the credit-note practice of coworking platforms and the group-ledger model of Splitwise/Cospend:

1. A worker buys something for the community (coffee, paper, a chair) and submits an **expense**: amount, date, category (owner-editable list), description, **receipt photo**.
2. An **admin approves or rejects** it (self-approval by admins is disallowed; another admin or owner must approve).
3. On approval, the amount is **credited to the purchaser's ledger** — automatically offsetting their next subscription/overage charges. Alternative settlement: admin records a cash reimbursement (a payment event) instead.
4. The community's expense total per period is visible to owner/admins (and, if the owner enables "transparent books", to all members).

**Out of scope v1, planned v2:** Splitwise-style N-way splits between arbitrary member subsets and debt simplification. In v1 every expense is *purchaser vs. the community* — this covers the stated use case with far less complexity.

---

## 10. Workspace editor (owner only)

A dedicated editor space for drawing the physical workspace on a **grid of small squares**:

- **Canvas** per level: pan/zoom grid; owner adds/renames/reorders/removes **levels**.
- **Draw offices**: mark rectangular (or square-composed) room outlines on the grid; name them; flag *bookable as a whole*; set a color.
- **Draw desks**: rectangles of squares placed inside offices; any size; rotate in 90° steps.
- **Place seats**: a seat stamps a **6-squares-wide × 4-squares-deep** footprint onto a desk edge with an orientation arrow (where the person sits). The editor validates: footprint fits on the desk side, no two seat footprints overlap. Seats are auto-numbered, renamable.
- **Assign chairs/amenities** per seat: chair type + amenity tags (monitor, standing desk, window…).
- **Block/unblock** any seat, desk, or office (maintenance) with an optional date range.
- Editing is safe against live data: removing a seat/desk/office with **future reservations** requires the owner to resolve them first (the editor lists affected reservations; affected members are notified per the §8 protocol).
- Edits are **versioned**: the plan at any past date can still be rendered so old reservations remain meaningful.
- The grid square is an abstract unit (no real-world scale required); the 6×4 seat footprint is the fixed normative size per the brief.

---

## 11. Cross-cutting product requirements

- **Languages (decided):** the app is fully multilanguage — **every user-facing string is translatable** (ARB-based, no hard-coded text, lint-enforced as in tankstellen). **English is the default and canonical locale**; **French, German, Spanish and Italian** ship at launch with maintained translations. The ARB fragment pipeline and key-parity CI gate support the tankstellen-style fan-out to further locales later. User-generated content (workspace names, expense notes) is not translated.
- **Country-driven formats (decided):** the workspace **country** determines the default **currency**; dates, numbers and currency are always rendered through locale-aware formatting (`intl`/`UnitFormatter` pattern) — never raw string formatting.
- **Notifications**: booking confirmations, check-in reminders, no-show releases, waitlist offers, pending confirmations, expense decisions, statement issued / payment overdue. Delivery: local notifications plus — for the F-Droid flavor — **UnifiedPush/ntfy** instead of Firebase (Google-services-free, per the tankstellen ADR "no Firebase/GMS").
- **Time zones & DST**: all times stored as UTC + the workspace's IANA time zone; recurring series recur in **workspace-local time** (a 09:00 series stays 09:00 across DST).
- **Offline behavior**: read access (floor plan, own events, ledger) works offline from local cache (local-first, as tankstellen); *writes* (check-in, reservation) require connectivity since they are multi-user-transactional — a clear offline banner explains this.
- **Privacy / GDPR**: minimal data (name, email, plan, bookings, ledger); per-member visibility control on the floor plan; data export (JSON) and account erasure — financial history is **anonymized, not deleted** (bookkeeping-retention vs. erasure conflict, per research); booking-history retention limit configurable; no tracking, no third-party analytics.
- **Occupancy analytics (owner/admin, v1.1)**: utilization per level/office/day, peak hours, no-show rate, quota consumption per plan — feeds both capacity decisions and billing sanity checks. CSV export.
- **Accessibility**: WCAG-conscious color coding (state never conveyed by color alone — icons/patterns too), minimum tap targets, screen-reader labels on all floor-plan elements (as tankstellen enforces via `androidTapTargetGuideline` tests).
- **Onboarding**: a new user either **creates a workspace** (becomes owner, guided grid-editor tutorial) or **joins one** via invite link / QR code (admin approves, assigns a plan).

---

## 12. Platforms & distribution (inherited from tankstellen)

- **Android** — Google Play *and* a dedicated **F-Droid product flavor** that is 100% Google-services-free (audited by script, as Sparkilo's `audit_no_gms.sh`); official fdroiddata recipe + self-hosted F-Droid repo; per-ABI split APKs; fastlane metadata per locale.
- **iOS** — App Store via TestFlight; same codebase.
- **License**: MIT, SPDX headers in every file.
- **No** Google Play Services, **no** Firebase, **no** third-party tracking, **no** GPL dependencies (MIT-compatibility rule).

## 13. Technical framework (level of principle only — inherited from tankstellen)

- **Flutter** (pinned stable) / Dart; **Riverpod 3 with codegen** for state; **freezed** models; **go_router** with a `StatefulShellRoute` bottom-nav shell; **flex_color_scheme** theming; **Hive** encrypted local storage; **Dio** with rate-limit interceptor behind the **service-chain** pattern (fresh → fetch → stale fallback).
- **Backend (decided): Supabase** — auth, RLS-protected Postgres as the shared source of truth, edge functions for transactional booking-conflict checks. Self-hostable to preserve the libre promise. This is ADR 0002 of this repo. (Tankstellen is local-first; DesKilo is inherently multi-user — reservations, ledgers and confirmations need a server-side source of truth.)
- App shell (proposed tabs): **Plan** (floor plan + time scroller, the raised center destination, like Search in tankstellen) · **Calendar** · **Events** · **Money** (ledger/statements/expenses) · owner's **Editor** and Settings reachable from the app bar.

## 14. Visual identity (inherited from tankstellen/Sparkilo)

- **Material 3** via flex_color_scheme; three themes: **light**, **dark**, and a signature blended third theme.
- **Brand color (decided): orange.** Same muted, desaturated design language as Sparkilo's forest green — proposal: primary burnt orange `#C2410C` with matching container/secondary/tertiary ramp, finalized in `docs/design/DESIGN_SYSTEM.md` during implementation. Sibling apps, distinct hues.
- **AppRadius tokens** identical: sm 4 / md 8 / lg 12 (cards) / xl 16 (sheets, chips) / xxl 24 (hero). No inline border radii (lint-enforced).
- **Seat-state accent palette** as the analog of tankstellen's fuel-color palette: muted, colorblind-safe hues for free / reserved / occupied / mine / blocked, tokenized in one file, documented in `docs/design/DESIGN_SYSTEM.md`.

## 15. Methodology & repo organization (inherited 1:1 from tankstellen)

- Repo: **`fdittgen-png/deskilo`**; GitHub Flow: branch off `master`, conventional commits, one concern per branch, **every change is a PR < 400 lines**, squash-merge, `Closes #NN`, no direct commits to master.
- **Issue-first, Epic-driven**: no code without a GitHub issue; work > 1 PR becomes an Epic with a maintainer-validated breakdown (epic templates + triage as in tankstellen).
- **Hard rules** carried over: no hard-coded user-facing strings (ARB only, lint-ratcheted), clean-codegen-before-push, locale key-parity CI gate.
- **TDD pyramid** 70/20/10, coverage gate, fakes over mocks, pre-fix failing-test protocol, twin-bug audit, producer+consumer ship together.
- **ADRs** in `docs/decisions/` from day one.
- **CI**: analyze + full test suite + l10n gate; `dev-apk` sideload workflow; F-Droid build/publish workflows; TestFlight workflow — mirroring tankstellen's `.github/workflows/` set, added incrementally.
- Issue templates: bug, feature, epic; PR template; CONTRIBUTING, CODE_OF_CONDUCT, AGENT_RULES.md.

---

## 16. Release roadmap

- **MVP (v0.x)** — workspace creation + grid editor (levels/offices/desks/seats/chairs); join via invite; floor plan with live states; walk-up check-in/out; punctual reservations; time scroller; Events space with the confirmation protocol; plans + ledger + manual payment tracking; expenses with approval; EN/FR/DE/ES/IT; Android APK.
- **v1.0** — series reservations with exception handling; booking-rules engine complete; no-show auto-release + check-in windows; statements + export; F-Droid + Play + App Store releases.
- **v1.1** — QR seat codes; waitlists; ICS/CalDAV feed; occupancy analytics; UnifiedPush.
- **v2** — guest/day passes; N-way expense splits + debt simplification; payment-provider integration (optional, non-F-Droid flavor); team/company accounts; multi-workspace federation.

---

## 17. Decisions log

| Decision | Value | Status |
|---|---|---|
| App name | **DesKilo** | ✅ decided 2026-07-07 |
| Backend | **Supabase** (RLS Postgres + edge functions, self-hostable) | ✅ decided |
| Brand color | **Orange** (muted burnt orange, proposal `#C2410C`) | ✅ decided |
| Billing unit | **Half-day** | ✅ decided |
| Currency & units | **From workspace country** (owner-overridable currency) | ✅ decided |
| Languages | **English (default/canonical) + FR, DE, ES, IT**; everything translatable | ✅ decided |
| GitHub | **`fdittgen-png/deskilo`** | ✅ created |
| Application ID | proposal `de.deskilo.app` | ⏳ confirm before first store/F-Droid metadata |
| Supabase project | hosted project vs. self-hosted instance | ⏳ needed before backend Epic starts |
| Half-plan default numbers (fee, 22 half-days, overage rate) | per-workspace anyway; defaults TBD | ⏳ before MVP billing Epic |
