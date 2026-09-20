<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Local preflight

```
dart run tool/preflight.dart              # against origin/master
dart run tool/preflight.dart --base HEAD~1
dart run tool/preflight.dart --list       # decide only, run nothing
```

Every generated tree in this repository has a drift gate, and every drift
gate runs in CI. A generator forgotten locally therefore costs a full
round trip — twenty minutes and a runner — to learn something the working
tree already knew: that `docs/testing/TEST_INVENTORY.md` does not list the
test just added, or that `assets/instance/bundle.json` is one migration
behind the folder next to it.

The preflight reads the changed paths, selects the generators that own
the outputs those paths invalidate, runs them in dependency order, and
says which generated files it had to rewrite.

| exit | meaning |
|---|---|
| 0 | nothing drifted, or nothing was selected |
| 1 | a generated file was out of date and has been rewritten — commit it |
| 2 | a generator failed |

## What selects what

| input | generator |
|---|---|
| `lib/l10n/_fragments/**` | `build_arb.dart`, then `flutter gen-l10n` |
| `workspace_feature.dart` | `build_feature_registry_sql.dart`, `build_builtin_templates.dart`, `build_setup_l10n.dart` |
| `workspace_process.dart` | `build_process_catalogue.dart`, `build_process_labels.dart` |
| `web/setup.html`, the feature copy | `build_setup_l10n.dart` |
| `docs/wiki/**` | `build_help.dart` |
| `supabase/migrations/**` | `record_applied_migrations.dart`, then `build_instance.dart` |
| `supabase/functions/**`, `supabase/restore/**` | `build_instance.dart` |
| any hand-written `lib/**.dart` | `l10n_audit.dart` |
| any `test/**.dart` | `test_inventory.dart` |

The order in `tool/preflight/preflight.dart` is the dependency order: the
ARB aggregate is built before `gen-l10n` reads it, and the applied
baseline is recorded before the instance bundle reads it.

## What it deliberately does not do

* **It selects nothing for a path it does not recognise.** A preflight
  that ran every generator on every change would be switched off within a
  week. The drift gates in `test/lint` remain the authority; this is the
  reminder, not the proof.
* **A generated file selects nothing by itself.** It is an output. If it
  did select its own generator, running the generator would select it
  again, forever.
* **It never touches a backend or GitHub.** It runs generators and `git`.
  It does not merge, close, assign, dispatch, apply a migration or write
  to a database — the boundary #1447 draws around a delivery helper.
* **It does not replace `flutter analyze --fatal-infos lib test tool`
  or the suite.** Run those too, as `docs/AGENT_RULES.md` requires.

## Adding a generator

Add the input rule in `tool/preflight/preflight.dart`, put the command in
`_order` at the position its inputs demand, and add the case to
`test/tool/preflight_test.dart`. Bump `preflightVersion` when a rule
changes, so a report can say which rules decided.
