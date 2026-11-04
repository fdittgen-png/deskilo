<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# What protects the Demo workspace

#1381 asks for a small, high-value suite rather than broad brittle
coverage, and names the rows it wants. This is the map from each row to
the file that owns it, so a row can be found, judged and — when it stops
being worth its cost — deleted on purpose.

`test/lint/demo_coverage_test.dart` fails when a file named here does
not exist, because a coverage map that outlives its tests is worse than
none: it is read as reassurance.

| what it protects | file |
|---|---|
| The Activity analysis invoiced and collected figures come from the demo's own invoices and matches, with the server's predicates: void and settlement invoices left out, credit notes apart, collected by the month of the match (#2339) | `test/core/demo/demo_finance_kpi_test.dart` |
| The personal data admin's screen in the Demo: a request recorded, extended, completed or refused, a refusal by the server shown in its own words with the sheet left open and then accepted (recovery), a privacy incident that says how many were told, and the screen offered only to someone who may decide requests (#3278). Simulated Demo behaviour; the server's rules are pgTAP 349, 350 and 351. | `test/features/profile/privacy_admin_screen_test.dart` |
| The birthday on the personal information form: who can read it, a day chosen on the bounded calendar, saved with the rest, removed, and the rest saved when only the birthday fails (#3278) | `test/features/profile/birthday_form_test.dart` |
| Demo entry, the explanation before consent, leaving — and that a whole visit leaves the device's own preferences byte-for-byte as it found them (#1564) | `test/core/demo/demo_entry_test.dart` |
| Isolation: the overrides are complete — every repository, every outward edge, the schema probe, the push pair and every per-device preference (#1564) | `test/core/demo/demo_scope_test.dart` |
| Isolation reaches the providers screens actually read | `test/core/demo/demo_scope_reach_test.dart` |
| The demo year and its finance story: rooms and parking booked until 31 December, room and parking invoices at France's four VAT rates in every payment state (paid, part-paid, written off, unpaid, refunded), the rent and utilities schedules, two sites (the garage with the parking), suppliers, received supplier invoices, bills at several rates, receipts and claims with a payment (#2574) | `test/core/demo/demo_year_test.dart` |
| A Demo supplier-bill decision is refused after approval access is removed, leaves the bill and payables unchanged, and succeeds when access returns (#3070). This is simulated Demo behavior; server authorization is verified separately. | `test/core/demo/demo_purchase_decision_guard_test.dart` |
| The Demo owner opens To pay from Purchases & suppliers, reads a partially paid supplier bill, and reaches Suppliers through the compatibility link (#3070). | `test/core/demo/demo_purchase_to_pay_journey_test.dart` |
| The owner opens Suppliers from the purchase hub, sees the cleaning supplier's simulated outstanding balance, and opens its scoped payable list containing a part-paid and a settled bill; other suppliers' bills stay out (#3070). The read uses the Demo's in-memory obligations and is not a live financial integration. | `test/core/demo/demo_supplier_balance_journey_test.dart`, `test/core/demo/demo_supplier_balance_test.dart` |
| A Demo approver recovers from a detail refusal, reviews the recorded CHF-to-EUR rate without editing it, then decides the pending bill (#3070). | `test/core/demo/demo_purchase_approval_fx_journey_test.dart` |
| A Demo member with approveExpenses and no wide finance/purchase permission opens the approval route, reads another maker's pending supplier bill, approves it, and sees the queue count refresh. The fake is in-memory and member receipts use separate expense validation. | `test/core/demo/demo_purchase_approval_journey_test.dart` |
| The demo twin of meeting rooms and parking: a boardroom booked by the hour beside a seat booked for the day, a garage with an electric slot and its charger (#2631) | `test/core/demo/demo_resources_test.dart` |
| The canonical dataset is coherent, and its cast is stable | `test/core/demo/demo_dataset_test.dart` |
| Every feature of the registry, in every step of the process catalogue, has a scenario a persona can perform or watch — the seeded state it starts from (a bill to approve, a lease difference to accept, a room request waiting), the precondition of an action, or a switch that is on — unless it is left off for a stated reason | `test/core/demo/demo_scenarios_test.dart` |
| The setup guide in the demo, read from each space's own fixture: Pézenas holds every step that applies to it, Leipzig takes bookings and names its prices next; a level changed in one space stays there, and Later and Mark as done are each space's own (#2872) | `test/core/demo/demo_setup_status_test.dart` |
| The setup guide inside the demo says what the demo is — nothing leaves the device, it resets, which space and persona — and switches between the space set up and the one half way (#2872) | `test/core/demo/demo_setup_card_test.dart` |
| A link into the demo chooses the space, the viewpoint and the screen — and nothing else: an unknown persona or space is ignored, a screen outside the allow-list never opens, and the link applies once (#2872) | `test/core/demo/demo_link_test.dart` |
| A link, followed: the demo opens in the space the link named, as its persona, on its screen, through the real router and its guards (#2872) | `test/core/demo/demo_link_apply_test.dart` |
| Leipzig's co-owner reaches Reserve through the real demo link, resolves to owner guidance in French, and resumes the pricing step; a member keeps their card, while unknown membership shows neither card until the owner answer arrives (#3077) | `test/core/demo/demo_leipzig_setup_test.dart` |
| The workspace data report rendered from the Pézenas space: every section present, the registers across the sheet, every page numbered, and each total equal to the workbook's column for the same rows (#2862) | `test/features/workspace/workspace_data_report_test.dart` |
| The visitor's own reservations of both spaces, read as one installation answers a workspace host's page: the acting member's rows only, in start order, keyset pages forward and backward without a duplicate or a gap (#2553); the persona's personal home names the one fixture host, and its pages carry each space's own time zone (#2553 C2) | `test/core/demo/demo_my_reservations_test.dart` |
| The invoice register a plain member reads is their own invoices, as the server's `invoices_select` answers; a finance reader or invoice issuer reads all (#3060 F5) | `test/core/demo/demo_member_register_test.dart` |
| Bank reconciliation report: the Demo matches a synthetic baseline receipt, imports a named unmatched movement and an overlapping source, refuses to infer the overlap status, then opens the existing statement report and builds archive members, verifying partial coverage and the named movement; balances are synthetic statement facts, not ledger or provider completeness (#2380) | `test/core/demo/demo_bank_reconciliation_container_test.dart` |
| Undoing a bank match of money in: the owner confirms the reference payments in Money > Cash > Bank statements, undoes the one that settles its invoice alone with a reason through the real dialog (a blank reason sends nothing), reads back an open invoice, the same payment credit and an unchanged ledger, one applied `invoice_payment_reversed` event and no payment event, then matches the movement again with the same payment; the payment that completed a part-paid invoice is undone alone and the invoice reads part-paid again by its earlier payment (0657); a match inside a closed period is refused in words with nothing changed (#2380) | `test/core/demo/demo_bank_unmatch_in_test.dart` |
| A member whose booking right is taken away in the Demo is refused the next booking with the server's words ("You may not make reservations in this space. Ask an owner to let members book.") and nothing is booked; given the right back, the same booking is made. The kiosk's reserve and walk-up refuse the same way for a badge without it, and check-out still works (#3269) | `test/features/reservations/booking_right_test.dart` |
| The UK VAT return is submitted to HMRC through Making Tax Digital in the London space: a visitor link (`space=london`, `to=/vat-declarations`) opens the prepared return of the last closed quarter, its nine boxes derived from the invoices through the same preparation every space uses; the owner connects HMRC (a synthetic sign-in, nothing is sent), sees a seeded simulated uncertain attempt, explicitly checks before submitting, and reads back the return filed through `hmrc_mtd` with a simulated receipt marked Demo; an administrator is refused, a box that differs, data changed since the preparation, a period that has not ended, a double activation and an unconfirmed answer file nothing; the unconfirmed return remains blocked after reopening until the owner checks HMRC and explicitly retries; the French and German spaces have no such door and never move (#2470) | `test/core/demo/demo_hmrc_journey_test.dart`, `test/core/demo/demo_hmrc_repository_test.dart` |
| The London and New York Demo links open separate fictional workspaces with site-specific plans, booking histories, memberships, invoices and equipment; the London book names Sage, New York keeps its own book and has a landlord, and each site's vending rental, stock and printing costs stay in its own purchase records. New York invoice usage lines charge for booked hours. In each city an owner opens a pending supplier bill, approves it and sees its correctly attributed payable. | `test/core/demo/demo_city_scenarios_test.dart`, `test/core/demo/demo_city_journey_test.dart` |
| London and New York historical bookings, usage records, invoice lines, tax and payment matches reconcile to their own people and spaces across every seeded month; an exclusive London rental has no overlapping seat bookings. | `test/core/demo/demo_city_consistency_test.dart` |
| New York reads in dollars and London in pounds in every figure the Demo shows for them — the workspace row, the invoices, the workspace status, the purchase figures and the cost figures (operating costs and acquisitions from the approved bills, net sales from the invoices, contribution between them); the older spaces keep their euro and have no cost figures. | `test/core/demo/demo_city_currency_test.dart` |
| The customer figures in each of the four spaces (Analytics › Finance, as the owner): payment punctuality by due-date cohort, dunning load, credits and write-offs, customer concentration — from the space's own invoices, matches, reminders and holds, in its own currency, never mixed; names only with the right to personal data, ranks otherwise (#3294). The formulas are pinned against pgTAP 352's month in `test/features/workspace/bi_customer_metrics_test.dart`. | `test/core/demo/demo_customer_kpi_test.dart` |
| The vendor figures in each of the four spaces (Analytics › Finance, as the owner, with the purchase figures on): spend by supplier and by category (net plus the tax that cannot be recovered, credit notes subtracted), paying suppliers on time by due-date cohort, and the days a bill takes to arrive — from the space's own purchases and supplier payables, in its own currency, never mixed; London and New York show late payments and arrival days (#3294 step 2). The formulas are pinned against pgTAP 353's month in `test/features/workspace/bi_vendor_metrics_test.dart`. | `test/core/demo/demo_vendor_kpi_test.dart` |
| Me › Finances reads every space the person is in — the main space and Leipzig in euros, London in pounds, New York in dollars — and never adds one currency to another: the amount to pay is one figure per currency, each document in its own space's currency. | `test/core/demo/demo_me_currencies_test.dart`, `test/core/demo/demo_second_space_test.dart` |
| A signed-in owner opens a configuration example (the setup guide's "Try it in the demo", a level's example, `/demo`, the older `/auth?demo=1`) inside the app: the explanation names the kept login, a real change is read back from the Demo repository, the live repository and session are untouched, and Return restores the same account, workspace, screen and unapplied "Set up by level" choices — with cancel, a repeated start, a late start after an account change, a sign-out or another account while the demo is open, the flag off and a failing start covered (#3235) | `test/ux/demo_while_signed_in_test.dart` |
| A browser reload inside the Demo — at `/demo` or at an inner screen such as `/features` — opens the Demo entry again instead of the signed-in workspace; leaving the Demo, cancelling the entry and a tab without storage are covered (#3235) | `test/ux/demo_reload_entry_test.dart`, `test/core/demo/demo_reload_marker_test.dart` |
| The second space (Leipzig): German, basic (a new space's features, no VAT, no accounting), coherent, answered from its own repositories; Ada (its co-owner) and Bruno are members of both, so Me lists two spaces and the bills of both | `test/core/demo/demo_second_space_test.dart` |
| A new discussion is not empty: the directory lists the active cast of both spaces, the persona left out and Ada and Bruno under both, the cast's group follows, and one letter suggests from it (#2472) | `test/core/demo/demo_reachable_test.dart` |
| The cast is a whole person on screen — a name, an e-mail, a number that could reach nobody — so a guide image can be shot here instead of in a real space (#1514) | `test/core/demo/demo_identity_test.dart` |
| Reset to baseline, and the fence against an in-flight write | `test/core/demo/demo_session_test.dart` |
| Personas resolve through the real permission model, and a persona is who ACTS: bookings, decisions and requests follow it, while membership edits survive it (#1565) | `test/core/demo/demo_persona_test.dart` |
| The bar: where it mounts, 360 dp, reduced motion, the persona ring | `test/core/demo/demo_bar_mount_test.dart` |
| The bar and the Reset control, driven | `test/core/demo/demo_workspace_test.dart` |
| The demo's pages agree with each other and settle — documents, finances, analytics, status, plan, clock, colour — and every process has something to show: the public directory, guest visits, saved analyses, a message request, the kiosk tablet (a fourth persona) and the development twin with its deployment journal (#2327) | `test/ux/demo_consistency_test.dart` |
| Each space's features, setup guide and values agree with the manifest, its country and its records: a step applies exactly when its feature is effective there; a VAT-registered space holds the rates its invoices charge; a space not subject to VAT has no VAT step; the twin carries its production's configuration; a feature switched off stays in its space across a persona switch and a reset restores it (#3290, inventory `docs/testing/evidence/demo-audit-3290-features.md`) | `test/core/demo/demo_feature_audit_test.dart` |
| The journeys, end to end on the real screens — mounted as `DeskiloRoot` with `demoEntry` entered, so they run on the production Demo composition and its own overrides | `test/ux/demo_journeys_test.dart` |
| The retired blur cannot come back | `test/lint/no_render_tree_blur_test.dart` |

## What the suite deliberately does not do

**It does not boot the app the way `main()` does.** There is no
`main()`, no `Supabase.initialize` and no splash timer: a journey mounts
`DeskiloRoot` with the demo entered, which is the composition a visitor
gets from the second tap onwards.

It used to say something else here, and the something else was the
defect. The journey harness supplied the device preferences in memory
itself, through `standardTestOverrides` — so the suite, and only the
suite, was isolated from the device. In the product those same stores
resolved to SharedPreferences inside the Demo scope, and entering the
demonstration deleted the member's real default profile (#1564). The
preferences are in memory because `demoOverrides` puts them there now,
which is a property of the product and can therefore be tested.

**It does not assert widget structure.** Every journey reads its result
back from the repository the screen wrote to. A journey that passes
without the state changing demonstrates nothing, and a journey pinned to
a widget tree fails on a redesign that broke nothing.

## Screenshots

The guides' images come from the screenshot pipeline (`tool/media.dart`,
#1017), which ingests what the owner posted. They are **not** currently
produced from the demo fixture.

That is worth changing — a screenshot taken in the demo is reproducible,
carries no personal data by construction, and updates when the dataset
does — but it needs the pipeline to render rather than ingest, which is
its own piece of work and not something to claim here. Until then, the
honest statement is that the demo dataset is available for new
screenshots and the existing ones predate it.
