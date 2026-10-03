# deskilo-ship-feature — reference

Lessons behind the checklist, grouped by topic. Read the section you need.

## Flags

- **Default-off flags are pinned in two tests**: `workspace_feature_test`
  (`defaultOffFeatures` and the lists derived from it) and `features_screen_test`
  (`featureManifest.length - N` switches on, one comment line per flag) — and the
  features screen viewport (`physicalSize`) grows with the list.
- **A default-ON child of a default-OFF parent is a contradiction every builtin
  template inherits.** `build_builtin_templates.dart` expands a profile from the
  registry defaults, and `template_contract_test` then refuses "`spaceInquiries` is
  on but its parent `publicListings` is off". Give such a flag no `requires` and let
  the server refuse the case the parent would have covered, or make it default off.
- **Adding a flag to a process moves counts in other tests.** `process_overview_test`
  switches a whole process off in a fixture map and pins "0 of N features on"; a new
  flag in that process joins the fixture and N. The Pézenas rehearsal
  (`supabase/tests/database/54_pezenas_template.sql`) carries the variant's
  configuration byte for byte and needs the new keys too.
- **Entity registries for deployment** (0186+): a new configuration domain =
  anchors in `export_workspace_configuration` AND `import_workspace_configuration`,
  an entry in `deployable_entities()`, a natural key in `entity_row_key` for a new
  table, a name in `deploymentEntityName` and the fake registry. A key that lives
  only on `workspaces` (payment_instructions) still needs all of it — the invoice's
  bank block went missing on the prod for want of it (#1010).

## Working beside other agents

- **Stacking (avoid; one issue at a time is the default).** If two branches must
  overlap, cut the next FROM the previous (`git checkout -B next prev`). After the
  base PR squash-merges, `git rebase --onto origin/master <old-tip-hash> next` and
  `push --force-with-lease` — the one place a feature branch is rewritten; the PR
  body loses its "stacked on" line. Never `--delete-branch` a stacked base:
  GitHub closes the child PR, and the local base branch is gone too (so rebase
  by hash, never by branch name).
- **A branch whose PR was superseded is deleted, not merged.** Compare its files
  with master (`git show origin/master:<f> | md5`). If every feature file is
  identical and only generated files differ, merging would revert newer work.
- **Closing.** A remainder that needs other infrastructure is collected in ONE
  follow-up issue (e.g. #1789 for four issues' race tests), linked from the closing
  comment. An open issue someone else may continue gets a "Handoff (for whoever
  continues)" comment: what is done, the files, the next step.

## Code and lints

- **A trigger for user actions:** `runGuarded` logs `<what> — started` and
  `— done` (#1012); a button "that does nothing" shows a start with no end. Phrase
  `message:` as `'<what> failed'` so the breadcrumb reads well.
- **When a change pushes a file over its length budget, extract — then LOWER the
  baseline.** #1056's overflow menu put `invoice_template_sheet.dart` 19 lines
  over; moving the pair into `report_history_controls.dart` left it 20 UNDER, so the
  baseline went 1180→1160. The ratchet only shrinks if somebody makes it shrink.
- **Extracting into a NEW library can trip the layering ratchet.** `layering_test`
  counts cross-feature import lines per file, so a helper moved out of a
  presentation mixin re-imports `plan/` and `workspace/` and pushes
  `reservations -> plan` over its pin (#1813). When the helper only serves that one
  library, make it a `part` of it (`others_booking_tap.dart` is the worked example).
- **Three analyzer strict modes are on** (`strict-casts`, `strict-inference`,
  `strict-raw-types`, #1060): `?? const []` does not pass — write `?? const <Event>[]`.
- **Material already translates the generic actions.** `MaterialLocalizations.of(context)`
  carries `closeButtonTooltip`, `deleteButtonTooltip`, `previousMonthTooltip`,
  `nextMonthTooltip`, `showMenuTooltip`: 15 of #1055's 25 unlabelled icon buttons
  needed no new string.
- **A one-line string fix still needs the ×5 sweep and a pin.** "My badge" appeared
  twice in Settings because two keys held the same value in all five locales —
  perfectly parallel, so `arb_key_parity_test` was satisfied. Parallel is not correct.

## Editing technique

- **Adding a named argument to many call sites in one file: ONE ordered forward
  pass.** Per-marker searches hit the wrong call — `rindex` walks back past a
  `suffixIcon:` into an unrelated helper, and a marker that appears twice matches
  the first occurrence both times. Collect anchors in file order, walk once,
  advancing the cursor past each insertion.

## Tooling

- **A stale `build_runner` blocks later ones silently.** A hung `build.dart.aot`
  from hours earlier holds the lock: `ps -eo pid,etime,time,command | grep build.dart.aot`
  (CPU time not moving = stuck), kill that pid only, `rm -rf .dart_tool/build`, retry.
