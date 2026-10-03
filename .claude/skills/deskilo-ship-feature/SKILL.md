---
name: deskilo-ship-feature
description: The DesKilo issue-to-merge ritual — claiming work beside other agents, one registry-touching branch at a time in its own worktree, the feature-flag checklist (enum, manifest, names, ARB fragments ×5, setup.html, process catalogue, server registry migration, featureAssessments), code rules, the local gates (dart analyze, lint tests, the shared suite lock, preflight --list), docs in the same PR, Refs vs Closes, and merging master once when it moves. Trigger at the start of any DesKilo issue (feature or fix), when adding a WorkspaceFeature, route, permission or validation domain, before any push, or when another agent's work overlaps yours.
---
# Ship a feature in DesKilo

The rules are binding in `docs/AGENT_RULES.md`; this skill is the how.
Migrations: `deskilo-supabase-migration`. After the push: `deskilo-ci-release`.

**Essentials**
1. Issue first; claim it; one registry-touching branch at a time, in your own worktree.
2. Every functionality behind a `WorkspaceFeature` — the §1 checklist in ONE commit.
3. Strings only in `lib/l10n/_fragments/*_{en,fr,de,es,it}.arb`; `web/setup.html` in the same PR.
4. Gates before push: `dart analyze --fatal-infos`, `flutter test test/lint` + the affected test folders (§3); the full suite runs in CI only.
5. `Refs #N` unless the whole acceptance is met; no tool/AI mention anywhere; master moved → merge it ONCE (§5).

Lessons by topic, with their incidents: [reference.md](reference.md).

## 0. Before code
- A GitHub issue exists; big work → `epic-triage`. Run `git log origin/master --grep '#N'`
  first: issue bodies go stale and checkpoints may already be merged.
- **Other agents (Codex, other sessions) push as the same GitHub user**, so
  `gh pr list --author @me` is not "mine". Read `.agent-work/*.json`, the tail of
  `AGENT_HANDOFF.md`, open PRs and the issue's last comments; write your own claim
  (`.agent-work/<issue>.json`).
- **Own worktree**: `git worktree add /private/tmp/deskilo-<issue> -b <branch> origin/master`,
  then `flutter pub get` in it — without `.dart_tool` a worktree resolves
  `package:deskilo` to the MAIN checkout and generators write stale output.
  Never switch branches in a shared checkout, and never while a suite runs in it.
- **One registry-touching branch at a time** (AGENT_RULES "One feature branch at a
  time"). Stacking is the exception — see reference.md.
- Flutter **3.47.5** only (`.flutter-version`).

## 1. The flag ritual (every functionality, forever — AGENT_RULES "Feature management")
Edit ALL of these in the same commit:
1. `lib/features/workspace/domain/workspace_feature.dart` — enum value
   (append at the end) + `featureManifest` entry (`requires:`, default).
2. `feature_names.dart` — label; `features_screen.dart` — description.
3. ARB fragments: keys `featureXxx`, `featureXxxDesc` + the feature's strings (§2 Strings).
4. `web/setup.html` — a FEATURES line `['key',0|1],` (no label: name and
   description come from the ARB) + the REQUIRES map entry; then
   `dart run tool/build_setup_l10n.dart` and commit `web/setup_l10n.js` AND
   `web/setup_catalogue.js` (the process grouping, #1330).
5. `workspace_process.dart` — primary subprocess or explicit internal reason;
   `dart run tool/build_process_catalogue.dart`.
6. `lib/features/workspace/domain/feature_lifecycle.dart` — the flag's
   `featureAssessments` line (#1850): `_legacy`/unreviewed until a review names
   evidence ids from `docs/product/capabilities.json`; maturity never gates
   anything. A removed flag's key moves to `retiredFeatureAssessments`.
7. **A migration** carrying `dart run tool/build_feature_registry_sql.dart`'s output
   (the server's copy of the manifest, #1333). A server gate calls
   `public.feature_effective(ws, 'key')`, never reads the flag by hand.
8. Routes: `lib/app/router.dart` GoRoute with a `featureEnabled(...)` redirect + a RouteRule.
9. Budgets: `test/lint/file_length_test.dart` — `workspace_feature.dart` grows ~10
   lines per flag; bump WITH a dated reason comment (better: extract, then lower it).

**No count pin to bump** (#2058): `feature_registry_test` checks manifest/name/
tier/dependency completeness and that every key any migration ever registered is
live or retired; `route_registry_test` reads the LIVE router and resolves every
deep link with all features off against a reviewed set — a route no flag owns
joins that set deliberately. What still pins: a **default-off** flag joins
`defaultOffFeatures` (`workspace_feature_test`) and `featureManifest.length - N`
(`features_screen_test`, whose viewport grows with the list); a flag in a process
moves `process_overview_test`'s fixture; a default-ON child of a default-OFF
parent breaks `template_contract_test` (reference.md "Flags").

Other registries: validation domains grow in FOUR places (AGENT_RULES); a new
`WorkspacePermission` needs the SQL catalog (`deskilo-supabase-migration`);
placeholders have their own pin (`deskilo-reports`); a new configuration domain
needs the deployment entity registry (reference.md "Flags").

## 2. Code
- AGENT_RULES "Coding rules" apply. `domain/` is pure Dart (no Flutter, no l10n) — the CLI imports it.
- `catch (e, st)` + TraceLogger; `// trace-exempt:` marker when rethrowing.
- **Strings.** `lib/l10n/app_<locale>.arb` is GENERATED — edit
  `lib/l10n/_fragments/<topic>_<locale>.arb` ×5, then
  `dart run tool/build_arb.dart && flutter gen-l10n` and commit both outputs (CI's
  l10n gate rebuilds from the fragments). No `{` in message text unless it is an ICU
  placeholder. `Text` literals are read by `tool/l10n_audit` (#2055, wrapped lines
  included): only `l10n?.x ?? 'English'` or a literal made of interpolations passes.
  Reach for `MaterialLocalizations` before inventing a key for a generic action.
- **Codegen.** A freezed class or a `@riverpod` provider body change changes its
  `.g.dart`: `dart run build_runner build --delete-conflicting-outputs`, commit the
  output. If a full run hangs in a worktree, use `--build-filter 'lib/<path>/<file>.g.dart'`
  (macOS has no `timeout`); a stale `build.dart.aot` holds the lock (reference.md "Tooling").
- **Never `dart format` an existing file** — the repo is not format-clean and one
  file yields hundreds of churn lines. Format only files you created; hand-place
  edits elsewhere at the surrounding indentation. Never format whole directories.

## 3. Verify
```
dart analyze --fatal-infos            # exactly what CI runs; flutter analyze misses the riverpod_lint plugin (missing_provider_scope)
flutter test test/lint <your tests>
dart run tool/preflight.dart --list   # which generators this change implicates — run THOSE yourself
```
Never run `tool/preflight.dart` in full on this machine: its build_runner step can hang.

**The full suite runs in CI only** — never `flutter test` without a path before a
push (the quality job runs it on every PR; local full suites on a shared machine
starve each other). Run the affected folders, never piped (a pipe masks the exit
code), and read the verdict line:
```
flutter test test/lint test/features/<yours> > scratchpad/<pr>.log 2>&1; echo EXIT=$?
grep -q "All tests passed!" scratchpad/<pr>.log   # never count [E] lines
```
Never `pkill -f flutter` / `flutter_tester` — it kills other agents' runs. A file
that fails only under load: rerun it alone, and name the flake in the PR rather
than skip the gate. Docs-only changes need only the lint/doc tests.

## 4. Docs in the same PR
The functionality's guide section in all five languages, citing the issue number, +
`dart run tool/build_help.dart` (how: `deskilo-documentation`). An ADR in `docs/decisions/NNNN-*.md` for a decision;
`docs/AGENT_RULES.md` for a rule the next agent must obey. When you change a rule,
grep the whole repo (skills, commands, workflow comments) for its old wording.

## 5. PR → merge
- Conventional title with `(#issue)`; body: What / Tests. `Refs #N` for a partial
  PR, `Closes #N` only when the whole acceptance is met (AGENT_RULES "Ready, Done
  and closure"); a partial landing gets an issue comment — what landed, what
  remains, the files, the next step. `Closes #a and #b` closes only `#a`.
- No tool or AI mention in commits, PR bodies, issues or code; no co-author trailer.
- Push only on a green verdict (analyze clean AND "All tests passed!" for lint +
  the affected folders), then `deskilo-ci-release`.
- **Master moved under your PR: merge it in ONCE — never rebase, never chase.**
  Conflicts in generated files (bundle, APPLIED, l10n output, the dependency map): `git diff --name-only --diff-filter=U -z | xargs -0 git checkout origin/master --`,
  then regenerate. In hand-written files keep BOTH sides in order (plain
  concatenation, never a line-dedupe — it drops shared closers like `),`).
  Never `for f in $files` in zsh: it passes all paths as one
  argument and conflict markers get committed. `git grep -l '^<<<<<<<'` before
  every push. If it conflicts again, stop and report.
- A branch whose PR was superseded is deleted, not merged (reference.md "Working beside other agents").
- Record non-obvious lessons in the memory file or a skill's reference.md, not in the wiki.
