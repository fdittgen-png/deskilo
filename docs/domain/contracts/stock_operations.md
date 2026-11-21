<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Stock operations — reading the goods ledger exactly, a bounded page at a time

## Baseline

- Refs: #4161 (the exact quantity and the bounded Stock reads), #3823 (the goods epic), #3824 (the S1 ledger this reads).
- Canonical sources: `supabase/migrations/0747_stock_ledger.sql` (the ledger, its balances, `stock_reader` and the first reads), `supabase/migrations/0833_stock_reads_paged.sql` (the paged reads), `packages/deskilo_money_kernel/lib/src/exact_quantity.dart` (the quantity), `lib/features/stock/domain/stock_page.dart` (what a reader makes of a page).

This page states the READ side. Writing the ledger (receipts, sales, returns, counts) belongs to the leaves that add those workflows, which extend this page rather than start another.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| stock movement | a quantity of one item (and lot) moved between two places at an instant; append-only history | `stock_movements.id`; unique per request, line and part |
| balance | what the movements add up to for one item, lot and place | `stock_balances` row: item, lot (or none), place |
| exact quantity | a signed value of at most six decimals, `numeric(18,6)`, `|v| <= 999999999999.999999`; it carries no unit, price or right | the value itself; canonical text has one spelling |
| entered quantity | what the person typed, with its unit, kept beside the converted one | on the movement |
| persisted quantity | the entered quantity converted once to the inventory unit and rounded once to six decimals | on the movement; a client never converts again |
| page | at most 200 rows of one read, with whether anything follows | none: it is a view, not a record |
| cursor | the position after the last row of a page: the keys of that row and a version | none: sent back unchanged, valid for the filters it was made with |

## Relationships and cardinalities

| question | answer |
|---|---|
| For one stock row, how many businesses? | exactly one; every row carries its workspace |
| For one request, how many rows? | between 0 and the bound asked (1 to 200), never more |
| For one page that is not the last, how many continuations? | exactly one cursor |
| For one movement, how many causes? | none or more of: a receipt line, a purchase line, an event, an invoice |
| For one balance, what does it equal? | the sum of the persisted quantities of its movements, not a re-conversion of what was entered |
| For an item with no lot, what is its unit cost? | unknown (null), never zero |
| Who sees what goods cost? | a caller holding viewFinances or managePurchases; everyone else reads the movement without it |

## States and transitions

Declared states: `start`, `open`, `complete`.

A walk is a reader following pages. The server keeps no walk; the states are the reader's.

| from | event | guard | to | effects |
|---|---|---|---|---|
| `start` | first page read | rows found, more follow | `open` | rows and the cursor of the last row |
| `start` | first page read | everything fits in one page | `complete` | rows, no cursor |
| `open` | page read from the cursor | more follow | `open` | the next rows and a new cursor |
| `open` | page read from the cursor | nothing follows | `complete` | the last rows, no cursor |
| `start` | page read | size outside 1 to 200, or no right, or feature off | `start` | refused; nothing is read |
| `open` | page read | a cursor that is not version 1 or is malformed | `open` | refused (DKG09); the walk may restart from `start` |

## Invariants

| rule | enforced by |
|---|---|
| A read needs viewStock or manageStock in the business and stockManagement on; a person who is no member, another business and an unauthenticated caller are refused (DKN01), the feature off is refused (DKG01) | `stock_reader`, `stock_page_reader` |
| A delegated assistant session reads nothing of the ledger | `stock_page_reader` (DKN01) and the `mcp_delegated_deny` policies |
| A page is bounded: a size outside 1 to 200 is refused (DKG09), never clamped | `stock_page_reader` |
| A list is never silently truncated: a page is `complete`, or it carries the cursor to continue | the two paged reads; the reader throws on a page that neither ends nor continues |
| The order is total over immutable keys, so equal keys never repeat or skip a row: on-hand by item, place, lot; movements newest first by instant and id | the two paged reads |
| Pages are not one snapshot: a row that exists throughout a walk appears exactly once; a row added behind the cursor is not seen by that walk; a quantity read twice is its value at each read | the keyset comparison; this page |
| A quantity travels as text of the stored value and is read exactly; no JSON number, no `double`, no re-conversion | the paged reads; `ExactQuantity` |
| Purchase cost is finance data: `unit_cost`, `purchase_line_id` and `receipt_line_id` (and a lot's cost, source currency and rate in the trace) are returned only to a caller holding viewFinances or managePurchases, and are null otherwise; a reader who may only see the stock is shown "cost not shown", never a zero | `stock_sees_cost`, the movements page and `stock_movement_trace_v1` (0833) |
| The same cost columns cannot be selected straight from `stock_movements` and `stock_lots` by the signed-in role (column-level select grants leave them out), and the value of the stock (`stock_value_at_v1`), which is the cost of the goods, is refused to a reader who may only see the stock (DKN01) | the column grants and `stock_value_at_v1` (0833) |
| A movement has an address: the movements read with a movement id returns that one movement, or none for an id of nothing or of another business | `stock_movements_page_v1` (`p_movement_id`) |
| An unknown valuation is unknown: a missing cost is null, never zero, and a missing lot reads no value | the paged reads (`unit_cost` as text or null) |
| A refused or failed read is never an empty list | `SupabaseStockQueries` throws; the Stock screen shows the refusal |

## Processing

A screen asks for a first page with its filters (item, place) and a size; the server checks the caller and the feature, validates the size and the cursor, reads the page plus one look-ahead row, and answers rows, `complete` and the cursor. The reader keeps its filters, shows the rows, and asks for the next page from the cursor when the person scrolls or taps More. A failed read leaves the rows already shown and the cursor unchanged, so the person can retry the same page; a refusal is shown in the person's language and nothing is shown as empty. Reading writes nothing; there is no financial effect and no external call.

## Evidence

- `supabase/tests/database/483_stock_reads_paged.sql`: three thirds persisted at 0.333333 sum to 0.999999 as text; 0.5 kg reads 0.5 when the legacy shelf count is 0; stock on two places is shown at each; a page of three is not complete and carries its cursor; walking two at a time returns every balance once; two lots of one item at one place come one per page; a balance changed between two page reads leaves the walk with every row once; the movements page is newest first and every movement appears once, among them three with one instant; an unknown valuation is null; size 0, 201 and none, another cursor version and a malformed cursor are refused; a member who may see the stock reads; a person who is no member, another business and an unauthenticated caller are refused; a delegated session reads nothing; another business's item id reads no row; the feature off is refused; a reader who only sees the stock gets no cost, receipt or purchase cause (null, not zero) on the page and in the trace, while the owner keeps them; the cost columns are not selectable from the tables (permission error for a reader of the stock and for the owner alike, who read them through the RPC); the value of the stock is refused to a reader of the stock; a movement is read by its id, with its names, and an id of nothing or of another business reads as none.
- `test/features/stock/supabase_stock_queries_test.dart`: the reader of the server's pages: quantities from text, the cursor handed back and sent again with the filters and the bound, a page without continuation or an unreadable row throws.
- `packages/deskilo_money_kernel/test/exact_quantity_test.dart`: the quantity's range, canonical text, refusals and arithmetic.
- Not yet evidenced here (they arrive with the Stock screen): the widget states at 390 and 1440 and a direct link past the guards.
