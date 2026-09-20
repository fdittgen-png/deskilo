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
| Demo entry, the explanation before consent, leaving — and that a whole visit leaves the device's own preferences byte-for-byte as it found them (#1564) | `test/core/demo/demo_entry_test.dart` |
| Isolation: the overrides are complete — every repository, every outward edge, the schema probe, the push pair and every per-device preference (#1564) | `test/core/demo/demo_scope_test.dart` |
| Isolation reaches the providers screens actually read | `test/core/demo/demo_scope_reach_test.dart` |
| The canonical dataset is coherent, and its cast is stable | `test/core/demo/demo_dataset_test.dart` |
| The cast is a whole person on screen — a name, an e-mail, a number that could reach nobody — so a guide image can be shot here instead of in a real space (#1514) | `test/core/demo/demo_identity_test.dart` |
| Reset to baseline, and the fence against an in-flight write | `test/core/demo/demo_session_test.dart` |
| Personas resolve through the real permission model, and a persona is who ACTS: bookings, decisions and requests follow it, while membership edits survive it (#1565) | `test/core/demo/demo_persona_test.dart` |
| The bar: where it mounts, 360 dp, reduced motion, the persona ring | `test/core/demo/demo_bar_mount_test.dart` |
| The bar and the Reset control, driven | `test/core/demo/demo_workspace_test.dart` |
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
