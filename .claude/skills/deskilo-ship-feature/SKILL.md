---
name: deskilo-ship-feature
description: The end-to-end ritual for shipping a functionality in DesKilo — issue, ONE branch at a time, the feature-flag registries (enum, manifest, names, description, ARB ×5, setup.html, pin = enum size, file budgets), migration harness, tests, wiki ×5 + build_help, PR, CI, squash-merge, beta train. Trigger at the start of any feature or fix, and whenever a PR touches the flag/placeholder registries.
---
# Ship a feature in DesKilo

## 0. Before code
- A GitHub issue exists (`gh issue create`); big work → `epic-triage`.
- **One registry-touching branch at a time.** Cut from `origin/master`,
  merge, then cut the next. If two must overlap, stack the second on the
  first and merge in order. Five parallel PRs on 2026-09-05 cost a
  hand-merged rebase EACH — see `git-pr-workflow` "rebase cascade".
- Never start a `flutter test` in the background and then switch
  branches: the suite reads the working tree as it runs.

## 1. The flag ritual (every functionality, forever — AGENT_RULES #502)
Edit ALL of these in the same commit:
1. `lib/features/workspace/domain/workspace_feature.dart` — enum value
   (append at the end) + `featureManifest` entry (`requires:`).
2. `feature_names.dart` — label; `features_screen.dart` — description.
3. ARB fragments `lib/l10n/_fragments/<topic>_{en,fr,de,es,it}.arb`
   (keys `featureXxx`, `featureXxxDesc` + the feature's strings). NO `{`
   in message text unless it is an ICU placeholder — write "text.key",
   not "{{ text.key }}". Then `dart run tool/build_arb.dart && flutter gen-l10n`.
4. `web/setup.html` — a FEATURES line + the REQUIRES map entry.
5. `test/lint/feature_registry_test.dart` — pin = the enum's size, with a
   dated `// N→N+1 (date): #issue …` changelog line.
6. Budgets: `test/lint/file_length_test.dart` — bump WITH a dated reason
   comment; `workspace_feature.dart` grows ~10 lines per flag.
7. Routes: `lib/app/router.dart` GoRoute with `featureEnabled(...)`
   redirect + `test/lint/route_registry_test.dart` pin.
Validation domains grow in FOUR places (AGENT_RULES #767/#769); the
placeholders registry has its own pin (`deskilo-reports`).

## 2. Code
- Domain pure Dart (no Flutter, no l10n) — the CLI imports it.
- `catch (e, st)` + TraceLogger; `// trace-exempt:` marker when rethrowing.
- No `Text('literal')` without an `l10n?.x ?? 'literal'` — hoist
  computed strings into a variable (the lint greps `Text('`).
- `AppRadius.mdAll`, not `BorderRadius.circular`.
- `dart format` ONLY the files you created. Formatting legacy files
  (member_page, supabase_workspace_repository, invite_sheet,
  members_screen, mock_providers, test/features/profile) yields hundreds
  of churn lines; revert and re-apply your edit.

## 3. Verify
```
flutter analyze --fatal-infos lib test tool
flutter test test/lint <your tests>
flutter test > scratchpad/suite-<pr>.log 2>&1    # background, then grep '\[E\]'
```
Codegen after freezed/@riverpod edits: `dart run build_runner build --delete-conflicting-outputs`.

## 4. Docs in the same PR
Wiki ×5 (`docs/wiki/User-Guide.md`, `Guide-utilisateur.md`,
`Benutzerhandbuch.md`, `Guia-de-usuario.md`, `Guida-utente.md`) —
insert before the next `### `/`## ` heading, cite the issue number —
then `dart run tool/build_help.dart` (commits `assets/help/*.md`).
An ADR in `docs/decisions/NNNN-*.md` for a decision; `docs/AGENT_RULES.md`
for a rule the next agent must obey.

## 5. PR → merge → deploy
Conventional title with `(#issue)`, body with What/Tests, the session
footer. Then `deskilo-ci-release`. Record non-obvious lessons in the
memory file, not in the wiki.

## 6. Lessons of 2026-09-07
- **Stacking.** Cut the next branch FROM the previous feature branch
  (`git checkout -B next prev`); after the base PR squash-merges,
  `git rebase --onto origin/master <old-tip-hash> next` and
  `push --force-with-lease`; the PR body loses its "stacked on" line.
- **`Closes #a and #b` closes only the first** — close the others with
  `gh issue close` and a one-line comment naming the PR.
- **Default-off flags** are pinned in THREE tests: `workspace_feature_test`
  (two lists), `features_screen_test` (`featureManifest.length - N`
  switches on) — and the features screen viewport grows with the list.
- **Entity registries for deployment** (0186+): a new configuration
  domain = anchors in `export_workspace_configuration` AND
  `import_workspace_configuration`, an entry in `deployable_entities()`,
  a natural key in `entity_row_key` for a new table, a name in
  `deploymentEntityName` and the fake registry. A key that lives only on
  `workspaces` (payment_instructions) still needs all of it — the
  invoice's bank block went missing on the prod for want of it (#1010).
- **A trigger for user actions:** `runGuarded` logs `<what> — started`
  and `— done` (#1012); a button "that does nothing" shows a start with no
  end. Phrase `message:` as `'<what> failed'` so the breadcrumb reads well.
- **Non-ASCII in a python heredoc** (guides ×5): run with `PYTHONUTF8=1`
  or the script dies on the first « ».
- **Register a new fake repository** in `standardTestOverrides`
  (`deployment:` → `FakeDeploymentRepository`) or every app test that
  reaches the provider hits Supabase.instance.
