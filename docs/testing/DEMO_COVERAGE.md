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
| Demo entry, the explanation before consent, leaving — and that a whole visit leaves the device's own preferences byte-for-byte as it found them (#1564) | `test/core/demo/demo_entry_test.dart` |
| Isolation: the overrides are complete — every repository, every outward edge, the schema probe, the push pair and every per-device preference (#1564) | `test/core/demo/demo_scope_test.dart` |
| Isolation reaches the providers screens actually read | `test/core/demo/demo_scope_reach_test.dart` |
| The demo year and its finance story: rooms and parking booked until 31 December, room and parking invoices at France's four VAT rates in every payment state (paid, part-paid, written off, unpaid, refunded), the rent and utilities schedules, two sites (the garage with the parking), suppliers, received supplier invoices, bills at several rates, receipts and claims with a payment (#2574) | `test/core/demo/demo_year_test.dart` |
| The demo twin of meeting rooms and parking: a boardroom booked by the hour beside a seat booked for the day, a garage with an electric slot and its charger (#2631) | `test/core/demo/demo_resources_test.dart` |
| The canonical dataset is coherent, and its cast is stable | `test/core/demo/demo_dataset_test.dart` |
| Every feature of the registry, in every step of the process catalogue, has a scenario a persona can perform or watch — the seeded state it starts from (a bill to approve, a lease difference to accept, a room request waiting), the precondition of an action, or a switch that is on — unless it is left off for a stated reason | `test/core/demo/demo_scenarios_test.dart` |
| The setup guide in the demo, read from each space's own fixture: Pézenas holds every step that applies to it, Leipzig takes bookings and names its prices next; a level changed in one space stays there, and Later and Mark as done are each space's own (#2872) | `test/core/demo/demo_setup_status_test.dart` |
| The setup guide inside the demo says what the demo is — nothing leaves the device, it resets, which space and persona — and switches between the space set up and the one half way (#2872) | `test/core/demo/demo_setup_card_test.dart` |
| A link into the demo chooses the space, the viewpoint and the screen — and nothing else: an unknown persona or space is ignored, a screen outside the allow-list never opens, and the link applies once (#2872) | `test/core/demo/demo_link_test.dart` |
| A link, followed: the demo opens in the space the link named, as its persona, on its screen, through the real router and its guards (#2872) | `test/core/demo/demo_link_apply_test.dart` |
| The workspace data report rendered from the Pézenas space: every section present, the registers across the sheet, every page numbered, and each total equal to the workbook's column for the same rows (#2862) | `test/features/workspace/workspace_data_report_test.dart` |
| The visitor's own reservations of both spaces, read as one installation answers a workspace host's page: the acting member's rows only, in start order, keyset pages forward and backward without a duplicate or a gap (#2553) | `test/core/demo/demo_my_reservations_test.dart` |
| The second space (Leipzig): German, basic (a new space's features, no VAT, no accounting), coherent, answered from its own repositories; Ada (its co-owner) and Bruno are members of both, so Me lists two spaces and the bills of both | `test/core/demo/demo_second_space_test.dart` |
| The cast is a whole person on screen — a name, an e-mail, a number that could reach nobody — so a guide image can be shot here instead of in a real space (#1514) | `test/core/demo/demo_identity_test.dart` |
| Reset to baseline, and the fence against an in-flight write | `test/core/demo/demo_session_test.dart` |
| Personas resolve through the real permission model, and a persona is who ACTS: bookings, decisions and requests follow it, while membership edits survive it (#1565) | `test/core/demo/demo_persona_test.dart` |
| The bar: where it mounts, 360 dp, reduced motion, the persona ring | `test/core/demo/demo_bar_mount_test.dart` |
| The bar and the Reset control, driven | `test/core/demo/demo_workspace_test.dart` |
| The demo's pages agree with each other and settle — documents, finances, analytics, status, plan, clock, colour — and every process has something to show: the public directory, guest visits, saved analyses, a message request, the kiosk tablet (a fourth persona) and the development twin with its deployment journal (#2327) | `test/ux/demo_consistency_test.dart` |
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
