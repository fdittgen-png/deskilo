# ADR 0006 — Quota + overage billing on a member ledger; tracking, not processing

**Status:** accepted · **Date:** 2026-07-07

## Context

The brief describes tiers "100%, 50%, sometimes, or 50% and if more, paying more" plus tracking whether subscription and extra time are paid, plus community expenses. Commercial coworking platforms (Cobot, Nexudus, OfficeRnD) converge on membership plans with included usage quotas and metered overage, settled through credit notes on a member account.

## Decision

- Plans = base subscription + included quota (in **half-days**) + overage rate. Defaults: Full (unlimited), Half (quota + overage), Flex (pay per use). "50% and if more pay more" *is* the Half plan — not a fourth tier.
- Every member has a **ledger**: charges (subscription, overage) and credits (approved community expenses, recorded payments, adjustments), rolled into monthly statements with paid/partial/unpaid status.
- The app **records** payments (bank transfer, cash, …) — it does **not** process them. No PSP in v1; keeps F-Droid clean.
- Workspace **country** drives the default currency; all money/date/number rendering is locale-aware.

## Consequences

Billing is auditable and dispute-resistant (prorated lines labelled, no-show policy explicit, exit keeps the ledger open until settled; financial history is anonymized, never deleted). Payment-provider integration is deferred to v2 as an optional non-F-Droid feature.
