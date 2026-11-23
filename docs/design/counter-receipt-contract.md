# The counter receipt: the server contract (#4184, #4185)

Commands are RPCs of the `public` schema, called as the signed-in person (`authenticated`). Every write takes a **request id** (a UUID the client keeps for the retry of one intent): the same id with the same content answers the first result (`"replayed": true`), the same id with other content is refused. Amounts are **minor units**: strings inside `totals` and `commercial.amounts`, integers in `amount_cents` and in the tender fields.

## 1. `counter_receipt_draft_v1(p_workspace_id, p_request_id, p_receipt_id, p_expected_revision, p_body)`

`p_receipt_id` null makes a draft; set (with `p_expected_revision`) it replaces the lines of an open draft (a moved revision is refused, DKT10).

`p_body`:

| field | type | meaning |
|---|---|---|
| `currency` | text, optional | ISO code, default the business's |
| `price_basis` | `gross` (default) or `net` | how every `unit_price` is read |
| `financial_subject_id` | uuid, optional | a `members.id` of this business; absent = a sale with no customer (never creates an account, a member or a subscription) |
| `source_kind`, `source_ref` | text, optional | the sale's natural identity (`source_ref` up to 200 chars); a finalized sale per (`source_kind`, `source_ref`) exists once |
| `lines[]` | 1 to 200 objects | below |

A line:

| field | type | meaning |
|---|---|---|
| `item_id` | uuid, optional for a service line, required for a goods line | an active item of the business |
| `variant_id` | uuid, optional | for an item with variants |
| `description` | text ≤ 300 | default the item's name; required without an item |
| `quantity` | decimal **string** `^[0-9]{1,12}(\.[0-9]{1,6})?$`, > 0 | exact, never a float |
| `unit_price` | decimal string in **major** units, read on `price_basis` | default the item's price (gross basis only) |
| `base_quantity` | decimal string, default `"1"` | the price is per this quantity |
| `unit` | `{code, label ≤ 20, un_ece_code}` | default the item's inventory unit |
| `supply` | `general`, `property` or `goods` | default `goods` for a stockable item, else `general` |
| `vat_rate_id` | uuid, optional | default the item's rate, else the business's default rate |
| `line_id` | uuid, optional | the server makes one when absent |
| `from_location_id`, `lot_id` | uuid, optional (goods) | where the goods leave from (default the place `MAIN`) and the lot to name |

**In this slice:** no line discount, no age confirmation, no weighed quantity (a weighed quantity is an ordinary decimal `quantity` with a unit), no deposit. They are not fields yet; a line with an unknown key keeps it in `input` and the server ignores it.

Answer (draft): `{receipt_id, revision, state: "draft", currency, price_basis, totals: {net_minor, tax_minor, gross_minor, currency}, lines: [<frozen line>], issue_receipt: "supported" | "unavailable" | "adapter_missing" | "no_row", replayed}`.

A frozen line (the `commercial` v1 shape of the standalone invoice's lines): `{kind: "service"|"goods", label, quantity: 1, amount_cents (gross, integer), vat_percent, vat_category, supply, commercial: {version: 1, line_id, quantity, unit: {code, un_ece_code, label}, unit_price: {amount, currency, basis, base_quantity}, supply, tax_facts: {tax_point, category, vat_percent}, amounts: {currency, net_minor, tax_minor, gross_minor, rule: "half_up_per_line"}}}`. Rounding is half-up once per line, exact in 0, 2 and 3 decimal currencies; the receipt totals are the sums of the lines.

## 2. Tenders and finalize

`counter_receipt_finalize_v1(p_workspace_id, p_request_id, p_receipt_id, p_expected_revision, p_tenders)`; `p_tenders[]` entries:

- `{ "kind": "cash" | "other", "amount_minor": <integer > 0> }`: recorded accepted at once. The amounts of all tenders must add up to the total **exactly**; the server records what was taken, so the client works out cash given and change (no change field in this slice).
- `{ "tender_id": "<uuid>" }`: a card tender already **accepted** on this receipt (below). An accepted card tender not named still counts toward the total.

Card: `counter_tender_request_v1(ws, request id, receipt id, 'card', amount_minor)` on an open draft answers `{tender_id, part, state: "requested", provider_key, amount_minor, replayed}`; then `counter_tender_resolve_v1(ws, request id, tender_id, outcome, provider_ref)` with `outcome` `accepted`, `refused` or `unknown` answers `{tender_id, state, reconciliation, replayed}` (`reconciliation: "needed"` when it was accepted after the draft moved). While a tender of the sale is `unknown`, no new request is made (DKT11); an unknown one is settled by someone who may see the finances. `counter_tender_reconcile_v1(ws, request id, tender_id)` marks a `needed` reconciliation done (needs the right to see the finances). A refused tender is not paid. The finalize refuses while one is requested or unknown (DKT06 `tender_open`).

Answer (finalize): `{receipt_id, number, currency, totals, tenders: <count accepted>, replayed}`. The number is drawn once, from the `receipt` journal, only after every check passed. Goods lines move their goods in the same transaction (reason `sale`, linked to the receipt); a line that cannot leave refuses the whole sale, number included (the stock refusals DKG03 and friends).

Corrections and money back, each its own command: `counter_receipt_correct_v1(ws, request id, original receipt id, {reason, lines: [{corrects_line_id, quantity}]})` makes a NEW finalized receipt (`kind: "correction"`) citing the original, answer `{receipt_id, number, corrects, currency, totals, replayed}`; `counter_refund_v1(ws, request id, correction id, [{kind: "cash"|"other", amount_minor}])` answers `{correction_id, refunded_minor, left_minor, replayed}`; `counter_goods_return_v1(ws, request id, correction id, [{corrects_line_id (a line of the correction), quantity, to_location_id?}])` takes goods back, answer `{correction_id, movements, replayed}`. A correction refunds nothing and moves no goods; a refund and a return are never made by it.

## 3. Refusals (SQLSTATE and detail)

| code | when | detail |
|---|---|---|
| DKT01 | the country operation is not supported under the declared case | JSON `{operation, country, fiscal_obligation, reason: "no_row" \| "unavailable" \| "adapter_missing"}`; nothing was numbered or taken |
| DKT02 | something the receipt needs is missing | plain text: comma list of names, `line_<n>_description`, `line_<n>_unit_price`, `line_<n>_quantity`, `line_<n>_unit`, `line_<n>_supply`, `line_<n>_vat_rate`, `line_<n>_item`, `line_<n>_line_id`, `line_<n>_amount`, or `header`, `financial_subject`, `lines`, `total_amount`, `total_not_positive` |
| DKT03 | an edit of a finalized receipt, its lines, a tender's amount or a refund | none (a server guard) |
| DKT04 | not an open draft; only a finalized sale is corrected; already issued for the source | for the source case JSON `{receipt_id, number}` of the receipt that exists |
| DKT05 | the business names a customer on every sale (`counter.customerless_sales` = refused) and none was named | none |
| DKT06 | tenders | plain text: `tenders_missing`, `tender_kind`, `tender_amount`, `tender_sum`, `tender_open`, `tender_state`, `refund_part` |
| DKT07 | goods cannot be sold or taken back | plain text: `goods_off`, `from_place`, `to_place` |
| DKT08 | a correction, refund or return beyond what is left | JSON `{line?, reason: "line_unknown" \| "quantity" \| "beyond_original" \| "amount_beyond" \| "empty" \| "refund_beyond" \| "return_beyond", left?}` |
| DKT09 | the versioned reader met a version it does not know | none |
| DKT10 | the draft's revision moved | none |
| DKT11 | a card authorization is unknown, already settled, or does not wait for a reconciliation | none |
| DKN01 | not allowed | none |
| DKG01 | counter receipts are off in this business | none |

## 4. Rights and settings

- Every command above needs an **active member** of the business with the right **`issueInvoices`** and the feature **`counterReceipts`** on; an assistant session is refused. Extra rights: **`manageStock`** for `counter_goods_return_v1`, **`recordOutgoingPayments`** for `counter_refund_v1`, **`viewFinances`** for reconciling and for settling an unknown authorization. `counter_readiness_v1` needs `issueInvoices` or `viewFinances`.
- Tables are readable (select) by `issueInvoices` or `viewFinances` with the feature on; nothing is writable directly.
- Settings (workspace): `counter.fiscal_obligation` (`none` | `register_required`, default `register_required`: the owner's declaration, recorded on each receipt), `counter.document_channel` (`share` | `print` | `both`, a screen choice the server does not read), `counter.customerless_sales` (`allowed` | `refused`, read by the finalize).

## 5. `counter_readiness_v1(p_workspace_id)`

`{country, fiscal_obligation, ready, operations: [{operation, outcome, registry_outcome, reason, note, specification, specification_version, effective_from, adapter, confirmed}]}` with `operation` one of `issue_receipt`, `correct_receipt`, `reconcile_tender`, `sign_fiscal`, `export_fiscal`; `outcome` is `supported` only when the registry row says supported **and** its adapter is implemented, else `unavailable` with `reason` `unavailable` or `adapter_missing`; `confirmed` is false for every row today (no tax professional has confirmed one). `ready` is true when `issue_receipt` and `reconcile_tender` are supported.

## 6. The frozen document (`counter_receipts.frozen`, read through `counter_receipt_decode`)

`{version: 1, number, currency, price_basis, issued_at, tax_point, lines[], totals, tax_breakdown: [{percent, category, gross_minor, net_minor, tax_minor}], source: {kind, ref}, financial_subject_id, operation: {country, operation, regime, specification, specification_version, effective_from, adapter, confirmed}, corrects: null | {receipt_id, number, reason}}`. `counter_receipt_decode` reads version 1 and refuses another version (DKT09).
