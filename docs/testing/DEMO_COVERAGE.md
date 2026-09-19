<!-- SPDX-License-Identifier: 0BSD -->
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
| Demo entry, the explanation before consent, and leaving | `test/core/demo/demo_entry_test.dart` |
| Isolation: the overrides are complete, and no outward edge is live | `test/core/demo/demo_scope_test.dart` |
| Isolation reaches the providers screens actually read | `test/core/demo/demo_scope_reach_test.dart` |
| The canonical dataset is coherent, and its cast is stable | `test/core/demo/demo_dataset_test.dart` |
| Reset to baseline, and the fence against an in-flight write | `test/core/demo/demo_session_test.dart` |
| Personas resolve through the real permission model | `test/core/demo/demo_persona_test.dart` |
| The bar: where it mounts, 360 dp, reduced motion, the persona ring | `test/core/demo/demo_bar_mount_test.dart` |
| The bar and the Reset control, driven | `test/core/demo/demo_workspace_test.dart` |
| The six journeys, end to end on the real screens | `test/ux/demo_journeys_test.dart` |
| The retired blur cannot come back | `test/lint/no_render_tree_blur_test.dart` |

## What the suite deliberately does not do

**It does not boot the app the way `main()` does.** The journey harness
supplies the device preferences in memory, because a test waiting on real
preference storage waits on the boot splash's timer rather than on the
product. The one test that does need the app's real widget position —
the bar above the Navigator — builds that position directly instead.

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
