# ADR 0008 — Billing v2: percentage subscriptions with fee bands, priced services, quorum validation

**Status:** accepted · **Date:** 2026-07-09 · **Supersedes the plan model of ADR 0006** (ledger, tracking-not-processing, and currency rules of 0006 stand)

## Context

Owners need pricing that is fully configurable instead of the fixed three-plan shape: membership expressed as a percentage, fees defined over percentage ranges, sellable consumables (coffee, printing, meeting rooms) on the monthly bill, a validation workflow whose quorum and eligible validators the owner controls, and a structured, PDF-exportable monthly bill (epic #121).

## Decision

### Percentage subscriptions replace plans

- A member's subscription is an **integer percentage 1–100** (`members.subscription_pct`), the membership level. Plans and `members.plan_id` are retired; existing members migrate Full→100, Half→50, Flex→lowest offered level.
- The owner curates which levels are offered: the preset steps **25 / 50 / 75 / 100** plus a **free-value** entry, each individually shown or hidden (`workspaces.subscription_levels jsonb` — list of enabled presets + `allow_custom bool`). Members can hold a level that is later hidden; hiding only limits new picks.
- **Fee bands** (`fee_bands`: `workspace_id`, `from_pct`, `to_pct`, `fee_cents`, `overage_fee_cents`) price the subscription: the monthly fee is the band the member's percentage falls into. Bands are **(from, to] inclusive-upper**, integer percents, and must be **contiguous and non-overlapping covering 1–100** — enforced by a DB constraint trigger and by the band editor.
- The percentage also scales **entitlement**: 100% = every half-day the workspace month offers; a member's included half-days = `ceil(month_half_days × pct / 100)`. Usage beyond it bills at the band's `overage_fee_cents` per half-day. *(Defaulted decision — flagged for veto on epic #121; the alternative "percentage is a price level only, unlimited usage" was rejected as unfair to low-percentage pricing.)*

### Priced consumable services

- `services` catalog (`workspace_id`, `name`, `price_cents`, `active`), owner-write via RLS, deactivate-never-delete (issue #123).
- Consumption is recorded by the **member (self-report) or an admin/owner (for any member)** via RPC `record_service_charge(member, service, qty, period)`. It creates a **pending event** (`events.type = 'service_charge'`, payload: service id, name+price snapshot, qty); the ledger `charge`/`service` entry posts only on confirmation. `LedgerCategory` gains `service`.

### Quorum validation on the events spine

- The existing `events` table stays the single approval mechanism; single-confirmer semantics generalize to a quorum.
- `validation_policies` (per workspace, one row per `events.type`, falling back to a workspace default row): `required_count int`, `admins_may_validate bool` (false = owner only), `eligible_admin_ids uuid[]` (empty = all admins), `owner_required bool`.
- `event_decisions` (`event_id`, `member_id`, `decision accept|reject`, `decided_at`) is the **per-validator audit trail**; `respond_to_event` inserts a decision row, rejects immediately close the event as `rejected`, and the event turns `confirmed` when `required_count` accepts exist **and** (if `owner_required`) an owner has accepted. No self-approval and the existing subject-must-accept rule (admin-booked reservations, admin-recorded payments) are preserved as a mandatory first decision, counted toward the quorum.
- `sweep_pending_events` keeps the 7-day timeout; auto-confirm fills only the *remaining* quorum and is recorded as a `system` decision row so the audit trail never has gaps.

### Statement and PDF

- Statements stay **computed, not stored** (`member_statement` reworked: band fee + service lines + overage − credits). The ledger is append-only per period, so past months are stable without persistence; **open positions** = the member's still-pending events for the period, listed separately from posted lines.
- The bill renders in a sectioned screen (subscription · services · open positions · payments/credits · balance) and exports via a new `pdf` dependency + the existing `share_plus` pattern (F-Droid-clean, pure Dart).

## Consequences

One pricing model instead of two; the plans editor becomes the band + level editor. All enforcement stays server-side (RLS + security-definer RPCs); client role checks remain cosmetic. Quorum applies uniformly to payments, expenses, and service charges, so #108's decider rule generalizes to "eligible validators minus actor/subject". Reshaped epic tasks 2 and 4–9 on #121 can now be filed against this schema.
