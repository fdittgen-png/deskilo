# ADR 0046 — A rented room's fee is charged when the booking lands, and frozen

**Status:** accepted · **Date:** 2026-10-20 · **Refs:** #2575, #2568, ADR 0044

## Context
0496 told a member what one use of a rented room costs them (`room_offer_v1`)
but nothing billed it. The member statement prices a reservation at statement
time, from the current price of the resource, which would let a later change
of a fee reprice a booking the member had already accepted. The existing
billing authority for a one-off sale is the member ledger: a `charge` entry
becomes an invoice line (`invoice_lines_for`) and lowers the statement
balance, and `buy_package` is the precedent.

## Decision
1. **One AFTER trigger on `reservations`**, beside the rental guard (0496), so
   `create_reservation`, `create_series`, the MCP path and any direct insert
   charge the same way. A booking that counts (`reserved`, `checked_in`,
   `completed`) in a room with an active rental writes a ledger `charge`
   (category `service`) in the same transaction.
2. **The fee is the one the member is offered**: per unit the most specific fee
   (member, role, plan, general). When a rental defines several units the
   cheapest total for the booking wins. Units follow the statement's rule:
   half days by the workspace granularity (slots overlapped, or hours per local
   day capped at two), hours rounded up, local days touched.
3. **The quote is frozen** in `reservation_charges` (rental revision, unit,
   units, unit fee, VAT, period, ledger ids). A booking keeps its price while
   its billable shape (time, place, member) is unchanged, whatever happens to
   the fees, the booking's status or the rental afterwards. A changed shape is
   re-quoted at the then-current fee.
4. **The ledger is append-only**, so a booking that is cancelled, released or
   deleted, or re-quoted, is reversed by a credit `adjustment` of the same
   amount, VAT and period. Before invoicing both lines show on the invoice
   (the charge and its negative); the table keeps both ids.
5. **Net price, default VAT.** Fees are net; the workspace's default VAT on the
   day of the booking is added at invoicing when it is VAT-registered, as for a
   package. No negotiated discount applies to a room fee.

## Consequences
- Bookings made before 0513 are not charged.
- A reversal after the period's invoice was issued appears on the next
  statement of that period, as every other ledger entry does.
- The member sheet already shows the fee; the statement and the invoice now
  carry it, with no client change.
- Not decided here: a minimum charge, a cancellation fee, a foreign-country
  recharge (ADR 0044 decision 6 still refuses it).
