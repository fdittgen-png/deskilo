# Owner business analytics: evidence, space performance and cash planning

<!-- dated: 2026-10-03 — source audit and owner decisions, Refs #1982 -->

The owner should be able to answer **where capacity is being used, how
customers pay, and when available cash might fall short**, from the same
workspace and timeline. An attractive chart is useful only when its scope,
denominator, evidence and limitations can be inspected.

Owner decisions: include actual bank balances and reconciliation; start
with bank-statement import. No bank feed, payment initiation or automatic
collection is implied. This design extends the existing issue checkpoints;
it does not replace them or describe unimplemented screens as shipped.

## What the source audit establishes

Baseline: `99c12c9236ebb0aa27000238b4d355f689e11b98`. This is a code audit
with regression tests, not a reconciliation of a customer's live accounts.

| Surface / source | Finding | Treatment |
| --- | --- | --- |
| `kpi_contract.dart::seatCapacityFromJson` | Missing or malformed quantities became zero; unknown quality flags disappeared. | Reject malformed inputs; unknown qualification makes the answer unavailable. |
| `SeatCapacityKpi.utilisation` | Quality did not prevent the Availability card displaying a number, unlike the BI consumer. | Both consumers suppress unrecorded, unavailable, forbidden and inapplicable figures. |
| `bi_result.dart::changeOf` | Partial or stale periods could produce a performance change. | Keep the qualified figures visible but withhold the change and explain why. |
| Capacity screens | Full current/future periods looked like measured occupancy; refresh time was hidden. | Visible period meaning, workspace-local computation time, refresh, unreserved/blocked hours and reservation-versus-attendance explanation. |
| `WorkspaceStatus.fromJson` | Absent finance sections became zero; absent currency became EUR; fractional minor units were truncated. | Fail visibly instead of fabricating amounts or currency. |
| `WorkspaceStatus.netCents` | Invoices minus credits/reimbursements is neither profit nor cash. Matched and received payment amounts overlap. | Explain the exact subtotal; do not repurpose it as liquidity or add the payment totals. |
| `0336_capacity_history.sql` | Seat hierarchy and opening rules are versioned, but closures and seatless rooms still use current records; reservation status is current. | Historical recomputation is not a past knowledge snapshot. Further historical coverage remains #1920/#1929 work. |
| `bi_providers.dart::_capacity` | Current levels are read separately; historical-only levels fall into a remainder, and separate RPC calls do not share one snapshot. | The next hierarchy producer must return the complete historical hierarchy and totals in one bounded response. Do not call the remainder a named past floor. |
| `0167_workspace_status.sql` | Invoice service periods, ledger periods and matching timestamps are different time bases; member rows cover active members. | A member ranking or cash timeline cannot be inferred from this mixed-period report. Use qualified finance projections. |
| Bank reconciliation | Internal ledger/provider consistency checks exist; statement-account balances and a statement-import consumer were not found. | Implement #1877 A before claiming reconciled bank balances in #1980. |

The first corrections above are deliberately changes to existing consumers
under their existing flags. They do not claim the full roadmap is delivered.

## The owner experience

Use the existing Web-BI host, app header, workspace identity and global
profile position. Keep the workspace visible on every detail, export and
scenario. Do not build a second analytics navigation system.

| Area | Owner's question | Primary view | Next action |
| --- | --- | --- | --- |
| Overview | What needs my attention? | Capacity, overdue receivables, reconciled cash, upcoming cash low point, plus coverage issues | Open the exact contributing resources, invoices or statement lines |
| Space and capacity | Which seat, table, office or floor is used well? | Expandable hierarchy beside a time profile; optional read-only plan | Drill into a resource and its reservations, blocks and opening hours |
| Customers and payments | Who pays, when, and what remains open? | Invoice cohorts and payment-time distributions with a customer breakdown where permitted | Open invoice/payment evidence and existing collection workflows |
| Cash and reconciliation | What is in each account, and why does it differ from the books? | Account balance bridge and statement-match queue | Inspect or confirm a match; investigate residuals |
| Scenarios | What happens under different usage, cost and payment assumptions? | Historical and future cash on one timeline, with an assumptions panel | Compare, save privately or return to the source |

The persistent controls are period, grain, comparison, resource scope and
view. Advanced options open on demand. Unsupported combinations explain
why instead of silently ignoring the filter. Chart and table share one
result. Every card exposes unit, period, source time, coverage and a source
link; detail navigation preserves filters and browser Back/Forward.

Use a visible **Today** boundary and distinguish:

- **Recorded history:** solid line; bank-verified and merely recorded
  movements remain distinct evidence classes.
- **Scheduled commitments:** labelled receipts/payables, with due dates;
  these are obligations, not guaranteed cash.
- **Scenario:** dashed line with the selected assumptions. A scenario
  range is not a statistical confidence interval.

Two different dates must not share an ambiguous slider: the **business
period** being analysed and the **information cutoff** used to reconstruct
what was known. Historical as-of mode is offered only where retained
events support it. Otherwise show “past period, current records”.

## Space efficiency that remains mathematically meaningful

Hierarchy: workspace → existing site → floor → office/room → table → seat.
Skip levels absent from the actual model. Preserve stable resource IDs and
effective hierarchy through moves, renames and deletion. Show historical
tables when old geometry is missing; a current plan is only an orientation.

Primary columns are offered capacity-hours, reserved capacity-hours,
reservation utilisation, unreserved offered hours, blocked hours and
evidenced attendance-hours. Unknown attendance is not zero. Rooms/tables
without seats use their own room/table-hours and never add into seat-hours.

Parent utilisation is **sum(reserved hours) / sum(offered hours)**, never
an average of percentages. A whole-table booking occupies each qualifying
descendant interval once; overlapping bookings use interval unions and
retain a conflict diagnostic. One attendee does not prove every seat was
occupied. Distinct booking/person counts cannot be summed across children.

Example oracle: 10 seats × 8 hours minus 4 blocked seat-hours = 76 offered
seat-hours. A four-seat table booked for 2 hours binds 8 seat-hours. Closed
hours do not become idle capacity. A 10/100 floor and a 10/20 floor total
20/120 = 16.67%, not 30%.

Compare like exposure: matching elapsed periods, historical opening hours,
capacity changes and workspace-local calendar/DST. Show both absolute
volume and percentage-point change. Do not rank an unknown resource as a
zero-utilisation opportunity. Idle hours × list price is not proven lost
revenue. Profitability needs actual attributed revenue and explicit cost
allocation; unattributed money stays in an explained remainder (#1942).

## Customer payment behaviour, with observable facts

Use commercial customer/organisation and invoice cohorts, not a subjective
person score. Keep customer payment delay separate from internal matching
delay. An entry's `matchedAt` is not proof of bank receipt.

For each due-date cohort show invoice count and value: on-time paid, late
paid, partially paid, still open, disputed/held, written off and due date
unknown. Pending payments, credit notes and write-offs are not cash.
Include open cases in ageing rather than dropping them from the population.

Show median/P90 time to full payment only over the stated completed-case
population. Show amount-weighted delay for qualified payment fragments:
400 received 10 days late plus 600 received 30 days late gives 22 weighted
days, while final settlement took 30 days. Receipt on day 10 and matching
on day 20 means a 10-day internal delay, not 20-day customer delay.

Reminder attempts, provider acceptance, delivery evidence and subsequent
payment are separate facts. Payment after a reminder is correlation, not
proof that the reminder caused it. Finance rights and personal-data rights
are checked separately; an operational analyst receives no hidden customer
debt payload. These are #1980/#1913/#1922 consumer contracts.

## Statement import and reconciliation first

Implement one documented CSV dialect first (#1877 A), then add adapters
without changing the reconciliation model. A preview maps account,
currency, statement period, opening/closing balances and lines. Each line
has a source transaction ID, booking date, optional value date, signed
exact amount and reference. Parse amounts with the existing currency/minor
unit contract; never infer decimal separators or currency from magnitude.

Keep original file hash and immutable source identities. Two identical
amount/date transactions with different bank IDs are two transactions.
Reimporting a file creates none. An overlapping statement without reliable
transaction IDs needs duplicate review, not silent deduplication.

The flow is **select account → import → preview/validate → confirm import
→ review match suggestions → confirm matches → inspect residuals/history**.
Opening balance + signed statement movements must equal closing balance.
Missing balances, gaps, overlap and postdated lines remain visible. A
valid balance bridge proves arithmetic, not that the source file is authentic.

A suggestion does not reconcile anything. Matching links statement lines
to existing receipts/outgoings with exact allocated amounts and residuals;
it never records the same payment again. Partial, one-to-many and
many-to-one matches are supported within bounded limits. Server-side
transactions prevent two reviewers allocating the same remainder. Unmatch
is an audited reversal and does not edit statement bytes or erase history.

Keep bank, cash and provider-clearing accounts separate. Customer receipt
120, provider fee 3 and payout 117 leave provider clearing at zero; payout
117 is an internal transfer, not another sale. A transfer cancels only when
both sides are inside the selected account scope. Currency totals remain
separate unless an explicit dated conversion is selected.

## Cash simulation with an inspectable baseline

Start at a dated balance for selected reconciled accounts. Show other
recorded but unreconciled movements separately; the user must explicitly
include them in a scenario. Deposits, restricted funds, holds, provider
clearing and available bank balance are not automatically interchangeable.

The future bridge is opening available balance + assumed incoming cash −
assumed outgoing cash. Include invoices/partial balances once, dated
expense commitments, payroll/rent/tax entries when actually available,
refunds, fees and recurring contracts without treating recurrence as cash.
Missing expenses or an account gap prevents a claim of complete runway.

Assumptions have provenance and units: collection delay, collection share,
new sales beyond contracted receivables, occupancy, price and variable/fixed
costs. Baseline, cautious and optimistic are editable scenarios, not
predictions with invented probabilities. Never add forecast demand to
booked demand unless the model explicitly predicts incremental demand.

Use daily/weekly/monthly points with a bounded horizon. Show minimum cash,
first crossing below a user-entered reserve, and the events contributing
to that point. Net positive end-of-month cash must not hide a mid-month
shortfall. A missing starting balance means “net movements”, not a balance.
Changing a scenario never edits reservations, tariffs, invoices or payments.

Save source cutoff, metric version and assumptions together. Forecast
accuracy is assessed only with time-ordered backtesting; no future facts
may leak into a past forecast. This is #1952 over #1980, not a new ledger.

## Other useful owner signals

After the primary views have qualified sources, add expiring subscriptions
and contracted recurring value (#1935), cancellation/no-show rates with
explicit eligible populations (#1931), concentration of receivables by
customer, and upcoming committed expenses. Keep these as drillable facts,
not inferred customer intent or automatic business actions. A coverage
panel should name missing bank periods, unmatched movements, unknown due
dates and unattributed resources: improving the evidence can be more useful
than adding another headline metric.

## Implementation order and proof

Integration follow-up (2026-10-03): the existing #1923 saved-view implementation
and #1924 invoiced/matched-payment modules are being integrated together with
the evidence corrections above. Both use the existing BI host and controls.
Matched-payment month remains distinct from bank receipt date; these modules
do not implement bank statements, reconciliation or cash forecasting.
Integrate their shared query/result contracts rather than fork them.

1. **Trust corrections:** strict decoding, qualification, period meaning,
   freshness and honest financial subtotal; regression and widget tests.
2. **Resource hierarchy (#1929):** one snapshot-qualified server result,
   hierarchy/time drill-down, independent interval arithmetic and real
   authenticated positive/negative SQL cases.
3. **Statement evidence (#1877 A):** preview/import/match/unmatch with
   idempotency, concurrent allocation and account/currency isolation proof.
4. **Payments and cash (#1980):** receipt-time cohorts, ageing, reconciled
   balance bridge and sources; charts reconcile to the exact ledger and
   statement fixtures, including events before/after the selected cutoff.
5. **Scenarios (#1952):** frozen baseline, assumptions and cash timeline;
   independently calculated examples and tests proving no business writes.

All steps include five languages, keyboard and table alternatives, narrow
and wide layouts, large text, role revocation and workspace-switch fencing.
Server aggregation and bounded detail pages replace browser raw-data scans.
Missing, stale, partial, suppressed and zero remain distinct. Actual
browser, database and live-source proof must be reported separately;
widget tests do not establish bank reconciliation or production correctness.
