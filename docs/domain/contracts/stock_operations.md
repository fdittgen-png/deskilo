<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Stock operations — reading the goods ledger exactly, a bounded page at a time

## Baseline

- Refs: #4161 (the exact quantity and the bounded Stock reads), #3823 (the goods epic), #3824 (the S1 ledger this reads).
- Refs also: #4169 (the configuration commands, `supabase/migrations/0836_stock_configuration.sql`; dimensions, variants and the supplier's article, `supabase/migrations/0837_stock_variants.sql`).
- Canonical sources: `supabase/migrations/0747_stock_ledger.sql` (the ledger, its balances, `stock_reader` and the first reads), `supabase/migrations/0833_stock_reads_paged.sql` (the paged reads), `packages/deskilo_money_kernel/lib/src/exact_quantity.dart` (the quantity), `lib/features/stock/domain/stock_page.dart` (what a reader makes of a page).

This page states the READ side and the CONFIGURATION side (the items' stock metadata, the package units and codes, the places). Writing the ledger (receipts, sales, returns, counts) belongs to the leaves that add those workflows, which extend this page rather than start another.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| stock movement | a quantity of one item (and lot) moved between two places at an instant; append-only history | `stock_movements.id`; unique per request, line and part |
| balance | what the movements add up to for one item, lot and place | `stock_balances` row: item, lot (or none), place |
| exact quantity | a signed value of at most six decimals, `numeric(18,6)`, `|v| <= 999999999999.999999`; it carries no unit, price or right | the value itself; canonical text has one spelling |
| entered quantity | what the person typed, with its unit, kept beside the converted one | on the movement |
| persisted quantity | the entered quantity converted once to the inventory unit and rounded once to six decimals | on the movement; a client never converts again |
| stock revision | the version of one item's stock metadata (`services.stock_revision`) or of one place (`stock_locations.revision`) a save must name | on the row; moves by one with each saved change |
| package unit | a unit of one item with its own factor to the item's inventory unit, as a fraction | `item_units` (item, unit); never a registry unit |
| dimension, value | a dimension of the business (Colour) and one of its allowed values (Red); a value is deactivated, never deleted | `item_dimensions`, `item_dimension_values` (workspace, id) |
| variant | one value per dimension for one item, unique per item by its canonical combination; it shares the item's inventory unit and supply nature | `item_variants` (item, canonical) |
| supplier article mapping | a supplier's article reference, with an item, a variant and one of the item's package units, saved explicitly | `supplier_item_mappings` (supplier, article reference) |
| frozen factor | the factor a movement was entered with, kept on the movement | `stock_movements.entered_factor_num/den` |
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

## Configuration

| question | answer |
|---|---|
| Who writes the configuration? | a member of the business with manageStock, the feature on; a person who only sees the stock, a manager of services and prices, another business and a delegated assistant session write nothing (DKN01); the feature off refuses (DKG01) |
| What does a save name? | the revision it read and a request id; a stale revision changes nothing (DKG10); the same request id with the same body answers what it answered, with another body it is refused (DKG07) |
| How is an invalid content refused? | DKG11, with the field (`units[0].factor_den`, `codes[1].code`, `parent_id`) and the reason (`factor_invalid`, `registry_unit`, `unit_duplicate`, `default_purchase_twice`, `dimension_mismatch`, `code_duplicate`, `gtin_length`, `gtin_check`, `location_cycle`, `location_parent_foreign`, `location_occupied`, `location_has_children`, `location_default`, `location_virtual`, `stock_on_hand`) as JSON in the detail, so the screen shows it under that field |
| What may change once movements exist? | a package unit's factor (the movements from then on use it); not the inventory unit or the tracking (DKG08) |
| Does a factor change reinterpret old quantities? | never: each movement freezes the factor it was entered with; a movement before 0836 reads null, not an invented factor |
| What happens to a place? | it is deactivated, never deleted (a delete with history is refused, DKG08); it cannot go under itself or its own descendant, under another business's place or a virtual one; it is not deactivated while it holds stock or has active children; the default place (MAIN) and the virtual places are not edited |
| Do variants take part in the ledger? | yes: a movement names its variant, a lot belongs to one variant, and the balance is one row per item, variant, lot and place (nulls not distinct): five red and three blue at one place are two balances, and four blue are not taken from three blue although six are there. An item without variants has variant_id null on every row and every amount and answer is as before (the released 410 test runs unchanged) |
| What happens to a variant's combination and to a dimension's values once used? | a variant that something names (a movement, a balance, a lot, a code) keeps its combination (variant_in_use); a value left out of a dimension is deactivated, so a variant that names it keeps its label; labels are not unique across dimensions, ids are |
| What if an item has variants and a move, a sale or a shelf count names none? | refused (DKG12): an item with active variants is never moved, sold or counted without one; its count is kept per variant, and a sale of it is refused until its line carries the variant. Variants are not added to an item that holds stock without one (stock_without_variant), a variant with stock is not deactivated (variant_has_stock), and a package unit a supplier mapping names is not removed (unit_in_use) |
| When is an item tracked by lot or expiry? | when the business asks for the `stockLots` feature (under the goods ledger, off by default) and the item has no movement yet: the first movement fixes the tracking (DKG08). Off: the editor offers no tracking and what was recorded stays as it is |
| Does a name bind a supplier's article to an item? | never: the mapping is an explicit save with the supplier, item, variant and unit of the same business, one mapping per supplier article, and it survives the supplier's display name |
| Does a stock right edit a service's name or price? | no: the item is the service, and its name and prices stay under manageServices |

## Receiving a delivery into stock

A delivery of a purchase order (`record_purchase_order_receipt_v1`, 0684) is recorded independently of stock and stays valid with the feature off. With `stockReceiving` on (under the goods ledger, off by default; turning it on waits for #4170 G4-A), its lines are put away once: `put_away_receipt_v1` and `record_receipt_and_put_away_v1` (the delivery and its put-away in one transaction, 0684's function called unchanged under a request id derived from the command's).

| question | answer |
|---|---|
| Who may, and when? | a member who holds managePurchases AND manageStock, with purchases, purchaseOrders, stockManagement and stockReceiving all on; a delegated assistant session and an unauthenticated caller are refused (DKN01); the feature off answers DKG01 |
| What is frozen when goods are put away? | `stock_receipt_allocations`, insert-only: the receipt line, the item, the variant, the entered unit and quantity (in the order line's unit), the exact factor, the inventory quantity (entered times that same stored factor, rounded once), the lot, the place, the movement, and a snapshot of the order reference, the supplier's name and the line text. A later edit of a unit, a mapping, a barcode, a price or a catalogue name cannot reinterpret it |
| Why are the supplier's name and the line text frozen? | deliberate: they are the business's purchase records, kept like invoices; they leave only with the business itself (its own deletion), never by a correction. A correction is appended |
| Can more be put away than arrived? | never: the receipt lines are locked, in one order, before the already-put-away quantity is counted, so two request ids cannot together exceed the received quantity (`over_allocated`) |
| Which lots? | each put-away group makes a NEW lot; a client never names an existing lot of a supplier delivery; two deliveries make two lots even with the same external label. A tracked item needs its lot code, an item tracked by expiry its date (a past date is kept as entered: it is a captured date, not a certification) |
| What is the cost of a lot? | never guessed: `cost_state` known (with its source, `entered` or the explicit `order_price`) or unknown. A lot with no cost assertion is unknown, a known zero stays zero. The movement of an unknown lot has no unit cost, the value on hand leaves such rows out of its total and counts them (`rows_without_cost`), and a trace shows the lot's total cost as null, never 0. The order price converts by the rate between the currencies' major units and each currency's own minor digits (yen has none); a rate for an order in the business's own currency, or one at or below zero, is refused |
| What if a request names a line twice? | a receipt line id and a line number that disagree are refused (`line_conflict`); the lines are resolved once and the locked id is the one used; a malformed id, quantity or rate is a refusal of its field, never a raw cast error |
| What cannot be edited or deleted? | a receipt, its lines, an order that received goods and an allocation: history is appended, never edited (DKG08), until the business itself is deleted |
| Who reads the allocations? | managePurchases or viewFinances, like the receipts they come from (they name the order and the supplier) |
| What is not yet possible? | changing an unknown cost to a known one later is a follow-up (nothing rewrites a lot's cost today) |

Evidence: `supabase/tests/database/490_stock_receiving.sql` (receipt with receiving off, two cartons of twelve, frozen factor, a retried request answers the same ids, 12 then 13 refused then 12, mixed stock/service/free-text lines, known/unknown/zero cost, the order price in dollars and yen, lot and expiry metadata, red and blue, rollback of the combined operation, permissions, immutability, an edited unit not reinterpreting an allocation, the delete of the business), `scripts/stock_receipt_race.sh` (two sessions putting away 18 of 24), `test/features/stock/supabase_stock_receiving_commands_test.dart`.

## One path: transfers, take-out, loss and the legacy bridge

Every finalized stock effect goes through ONE internal function (`stock_apply_lines`): `stock_move_v1` keeps its signature and calls it, and so do the typed commands. It locks every item of a request in id order first (two opposing requests cannot deadlock), checks the reason against the places, flags an expired lot and answers one entry per part (the line, the part, the lot, the movement). Sale mode (a commercial fulfilment) is NOT delivered here: it waits for #4162, #4163, #4165 and #4166, and the generic move refuses `sale`/`return_*` without their commercial source.

| question | answer |
|---|---|
| What is a site? | **until #4293 gives the site its own level, a site is the root ancestor of a place (a place with no parent)**; #4293 replaces this definition, and one-step transfers and the receiving place check then read the site level instead |
| Which reason fits which places? | receipt: from a supplier to a real place; transfer: between two real places (one step only inside one site); consumption and loss: from a real place to the loss place; adjustment: between a real place and the loss place; opening: with the opening place; sale: a real place to the customer place with an event or invoice source; return_in: customer to a real place with an invoice; return_out: a real place to the supplier with its receipt or purchase line. Anything else is refused (DKG11 `reason_places`) |
| How do goods move between sites? | in two steps: LOAD (`stock_transfer_load_v1`) moves them to the business's in-transit place (kind `in_transit`, one per business, counted, owned by this command: nothing else may move to or from it) and remembers each lot and quantity (`stock_transfer_lines`); RECEIVE (`stock_transfer_receive_v1`) moves them onto a place of the destination's own site, all or in part. What is not received stays in transit and visible; the sum over source, transit and destination is unchanged at each step. A transfer has one source place and one request identity per step. Two steps are for goods that change site: a load onto a place of the source's own site is refused (`same_site`). The in-transit place is the system's: one per business (a unique index), never created, edited or put away into by a person (a place already called TRANSIT does not stop the system taking `TRANSIT-1`). Receiving never asks for the expiry acknowledgement again: the lot left the source with its own |
| Who may, and what must be on? | a member with manageStock in a native (not delegated) session, stockManagement on. Consumption and loss also need `stockTakeOut` (off by default, under the ledger); transfers and receiving do not; the generic `stock_move_v1` asks for it too when the reason is consumption or loss, and refuses an assistant (delegated) session like the typed commands |
| Is a quantity ever clipped? | never: less than asked refuses the whole request (DKG03) and moves nothing. The one explicit policy is `stock.allow_negative` (off by default, in the Stock settings): an untracked item may go below zero at a place, a lot never does. The legacy confirmation bridge follows the same setting |
| What does the legacy confirmation (a validated sale charge) take? | exactly the charge's quantity, from MAIN and the places inside it (MAIN first, then its children by code, lots soonest-expiry first); less there refuses the confirmation with the named code (DKG03) saying what is there; an item with variants is refused as that (DKG12, the sale must name its variant); the refusal carries a JSON detail (`scope` main_store, `item_id`, what is `held`, what was `asked`) for the screen that says it and links to the Stock page of that item; it never takes a lot past its date (what is left being only expired is refused as that, DKG15); it locks the item first like every stock command. Never a guess across other sites. With the feature off after the ledger exists the bridge confirms and leaves the count and the history alone |
| What about a lot past its date? | taking it (consumption, transfer) needs an explicit acknowledgement on the line (`expired_ack`, else DKG11 `lot_expired`); writing it off as a loss needs none. A tracked item is taken from a lot the operator names; `stock_fefo_proposal_v1` proposes the lots, soonest expiry first, and flags the expired ones. No food-compliance claim is made |
| What is `services.stock` once the ledger exists? | a read-only mirror: the first activation of stockManagement imports the old shelf count exactly once (`workspaces.stock_initialized_at`); from then on a write of the count from outside the ledger is refused (DKG13), whether the feature is on or off. Switching the feature off keeps every quantity and movement and refuses stock-affecting legacy writes; switching it on again resumes the ledger and reconciles nothing from a rounded counter |
| What about a configuration file with counts? | once the ledger exists the import ignores the file's counts (the ledger is the truth; an item new from the file is stocked, with no count); before it, the file's counts are the shelf counts the first activation imports |
| How is a lost response recovered? | by the request id: the same id with the same body answers what it answered (no second effect), another body is refused, and `stock_command_outcome_v1` reads what a command of this family (transfer, load, receive, consumption, loss) answered for the CALLER'S OWN request, with the feature the command itself asks for, without running it again |

Evidence: `supabase/tests/database/495_stock_paths.sql` (the generic reason matrix and the system in-transit place; a replenishment inside a site, exact and fractional and converted by a carton's factor; between sites only through transit; all-line rollback and no clipping; the legacy bridge taking exactly from the place inside MAIN and refusing when short; the negative policy for an untracked item and never a lot; consumption and loss with replay, a different body refused, expired lots and the proposal; stockTakeOut off; a transfer loaded, received in part, retried and received in full with the sum unchanged at each step; one source place; the outcome of a request; the count refused and off/on again changing nothing; the member who only sees the stock, the delegated session, another business and the ledger off), `scripts/stock_transfer_race.sh` (opposing multi-item transfers never deadlock; the last stock is taken once).

## Reorder points, low-stock alerts and the replenishment list

Behind `stockReorder` (under `stockManagement`, off by default). Set with `manageStock`, read with `manageStock`, `managePurchases` or `viewStock`, a draft order made with `managePurchases`; an assistant session does none of it.

| question | answer |
|---|---|
| What is a point? | `stock_reorder_points`: at one site, for one item (or one variant; none = the item as a whole), a `reorder_point` (exact, inventory unit) and optionally a `reorder_quantity` (what to order) or a `target_quantity` (order up to it, above the point), never both. One point per item, variant and site. An item without a point is never low. Written only by `save_stock_reorder_point_v1` (idempotent by request id, stale revision refused, what the point is for never changes) |
| What is a site here? | the root place of a tree (`stock_site_of`): the points follow that function when #4293 gives the site its own level |
| What is low? | what the site's real places hold of the item is at or below the point; goods in transit and in virtual places are not counted; read from the ledger, never stored |
| What raises an alert? | one inbox event `stock_low` per point while it stays low (the owner is its actor and subject; one open notice per point is held by a unique index): opened when a movement or a save finds the point crossed, ended with the time when the stock rises above it; a repeated movement while low changes nothing; a new alert opens when it is low again. Read with `manageStock` or `managePurchases`; not the owner's own data (left out of the personal export) |
| Is the movement path slower? | the trigger leaves at once for an item with no active point, and for a movement between places that are not real places of a site |
| What does the replenishment list say? | the low rows with what to order (the reorder quantity, or what is missing up to the target), grouped by the supplier whose article is `preferred` for the item (one per item and variant; a variant's own wins over the item's), in the article's purchase unit rounded up to whole units; rows with no preferred article are listed as "no supplier chosen" |
| What is the draft order? | `create_replenishment_draft_v1`: a DRAFT purchase order for one supplier from lines that are that supplier's preferred article, priced at zero and never sent; the same request answers the same order |

Evidence: `supabase/tests/database/498_stock_reorder.sql` (the point and its refusals; one alert while low, ended above, a new one when low again; two sites with their own levels; a second business sees nothing; the list in whole purchase units; the draft and its replay) and `scripts/stock_transfer_race.sh` (two sessions crossing one point give one alert).

## Returns and corrections

Behind `stockReturns` (under `stockManagement`, off by default). Made with `manageStock`, read with `viewStock` or `manageStock`; reversing an adjustment needs `approveStockAdjustments`; an assistant session does none of it.

| question | answer |
|---|---|
| What is a return? | `stock_returns`: one logical physical event with a stable `return_id` (per business), a kind (`customer`, `supplier`, `correction`), the digest of its content and its result; immutable. Each line is a `stock_reversals` row with its own stable `return_line_id`, the source movement it reverses, the quantity (in the item's inventory unit) and the movement it wrote; immutable |
| What bounds it? | the sum of every reversal ever made on a source movement never exceeds that movement's quantity: the source row is locked while the previous reversals are summed (items first, then the source movements, each in id order), so two returns with different identities cannot return more than there was (DKG17). The source row and its frozen cost are never edited |
| What is a customer return? | from the customer place of a sale to a real place chosen, in the original item, variant and lot, at that lot's frozen unit cost (DKG18 for a source that is not a sale; DKG05 for a virtual or unknown place) |
| What is a supplier return? | from the real place where the goods are now, to the supplier place of the receipt, in that receipt's lot: the on-hand quantity falls once (DKG03 when it is not there) and the receipt is not subtracted a second time (DKG18 for a source that is not a receipt) |
| What is a correction? | a movement back (reason `correction`): from the place the source went to, to the place it came from. A correction of a correction names the earlier correction's movement as its source, so the chain is explicit. The opening and the in-transit legs of a transfer are not corrected here; reversing an adjustment needs `approveStockAdjustments` |
| How is a lost reply recovered? | by the identities: the same request id with the same body answers what it answered; the same `return_id` under a new request id answers the recorded result and writes nothing; the same `return_id` with other content, or a line id of another return, is refused (DKG16) |
| What about money? | none is made: no payment, refund, credit, payable settlement or posting. A return names the movement it follows (and so the sale or delivery); a payment reversal alone returns no goods |
| What is read? | `stock_reversible_v1`: for movements, the quantity, what was reversed, what remains and the reversals |

Evidence: `supabase/tests/database/504_stock_returns.sql` (a return of 3, repeated under a new request id; a changed quantity under the finalized identity; a line id of another return; a distinct return of the remaining 7; beyond the sale refused; a return that re-enters the original lot at its frozen cost; the wrong kind of source and a virtual place; a supplier return that lowers the on-hand once and is bounded by the receipt; a correction and a correction of a correction; the rights, an assistant, another business, the feature off; immutability) and `scripts/stock_transfer_race.sh` section F (two distinct returns of 6 of a sale of 10: the second waits and is refused, 6 returned once).

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

| rule | enforced by |
|---|---|
| A save of a revision that is no longer current changes nothing and says so | `save_stock_item_v1`, `save_stock_location_v1` (DKG10) |
| A used factor is frozen with the movement: a later factor change only affects what follows | `stock_record` freezes `entered_factor_num/den` from `stock_unit_factor` |
| Codes are unique per business; a GTIN has 8, 12, 13 or 14 digits and its check digit; the same code in another business does not collide | `save_stock_item_v1` (code_duplicate, gtin_length, gtin_check) |
| Red and blue are separate stock; a take is from that variant's stock; two sessions moving one variant: the second waits, then is refused; moves of one item, whatever the variant, serialise on the item | `stock_balances` key, `stock_movements_apply`, `stock_take` (variant), `scripts/stock_variant_race.sh` |
| A place is never deleted once a movement names it | `stock_locations_keep_history` (DKG08) |

## Processing

A screen asks for a first page with its filters (item, place) and a size; the server checks the caller and the feature, validates the size and the cursor, reads the page plus one look-ahead row, and answers rows, `complete` and the cursor. The reader keeps its filters, shows the rows, and asks for the next page from the cursor when the person scrolls or taps More. A failed read leaves the rows already shown and the cursor unchanged, so the person can retry the same page; a refusal is shown in the person's language and nothing is shown as empty. Reading writes nothing; there is no financial effect and no external call.

## Evidence

- `supabase/tests/database/483_stock_reads_paged.sql`: three thirds persisted at 0.333333 sum to 0.999999 as text; 0.5 kg reads 0.5 when the legacy shelf count is 0; stock on two places is shown at each; a page of three is not complete and carries its cursor; walking two at a time returns every balance once; two lots of one item at one place come one per page; a balance changed between two page reads leaves the walk with every row once; the movements page is newest first and every movement appears once, among them three with one instant; an unknown valuation is null; size 0, 201 and none, another cursor version and a malformed cursor are refused; a member who may see the stock reads; a person who is no member, another business and an unauthenticated caller are refused; a delegated session reads nothing; another business's item id reads no row; the feature off is refused; a reader who only sees the stock gets no cost, receipt or purchase cause (null, not zero) on the page and in the trace, while the owner keeps them; the cost columns are not selectable from the tables (permission error for a reader of the stock and for the owner alike, who read them through the RPC); the value of the stock is refused to a reader of the stock; a movement is read by its id, with its names, and an id of nothing or of another business reads as none.
- `test/features/stock/supabase_stock_queries_test.dart`: the reader of the server's pages: quantities from text, the cursor handed back and sent again with the filters and the bound, a page without continuation or an unreadable row throws.
- `supabase/tests/database/487_stock_configuration.sql`: 1 carton is 12 pieces and 1 glass is 1/5 litre; a zero or negative factor, a registry unit as a package and a unit of another dimension are refused under their field; a used factor change leaves the old movement at 24 pieces with 12/1 and the next at 10/1; the inventory unit and tracking of an item with movements stay (DKG08); an own code and a valid GTIN save, a duplicate, a short GTIN and a wrong check digit are refused, and the same code in another business does not collide; two saves of one revision: only the first wins; a repeated request answers replayed and another body is refused; a place is created, cannot form a cycle or go under another business's place, a virtual place and the default place are not edited, an occupied place is not deactivated and a place with history is not deleted; a stock-only member, a manager of services, another business, a delegated session and the feature off write nothing, a stock manager writes and the service's name and price stay.
- `supabase/tests/database/488_stock_variants.sql`: dimensions and values are created, names and labels are unique; red/M and blue/M are variants with a price and the item revision moves; a duplicate combination, a value of another dimension and of another business are refused; five red and three blue at one place are two balances, taking two red leaves three and three, four blue are refused although six shirts are there; a variant of another item is refused; two values labelled Red are two ids and a variant reads as `Colour: Red · Size: M`; a value left out is deactivated and the variant keeps its label; a combination with stock stays (variant_in_use); a barcode may name a variant of its item and not another item's; a lot of red is not moved as blue; a supplier article is mapped to an item and variant, once, with a unit the item lists, a supplier and a variant of the same business, and the mapping survives the supplier's name; a stale revision, a member who only sees the stock, a delegated session and a repeated request are as for the configuration. The released `410_stock_ledger.sql` and `483_stock_reads_paged.sql` run on this migration unchanged in meaning (variant_id null).
- `scripts/stock_variant_race.sh` (the Quality database job): two sessions moving the last red shirts at one place: the second waits on a lock and is refused; a blue move of the same item waits for the first too (every move of one item serialises on the item's row, through the shelf-count mirror: decided) and then completes; the winner replayed under its request id writes nothing.
- `test/features/stock/supabase_stock_config_commands_test.dart`: a save carries its revision, request id and complete lists; stale, invalid content with field and reason, and in-use become typed failures; another failure is not swallowed.
- `packages/deskilo_money_kernel/test/exact_quantity_test.dart`: the quantity's range, canonical text, refusals and arithmetic.
- Not yet evidenced here (they arrive with the Stock screen): the widget states at 390 and 1440 and a direct link past the guards.
