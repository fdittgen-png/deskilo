# DesKilo — read this first

Binding rules for humans and agents live in `docs/AGENT_RULES.md` (hard
rules, coding, feature-flag lifetime, testing, git, setup.html, reports,
identity form, one-branch-at-a-time). This file indexes the skills and execution entry points.

## Project skills (`.claude/skills/`)

| Skill | Use it when |
|---|---|
| `deskilo-ship-feature` | starting ANY issue: claim → worktree → flag ritual → local gates (suite lock) → docs → PR → merge master once |
| `deskilo-supabase-migration` | a migration, RPC, policy or pgTAP file: number at push time, prove on dev, apply, predict the contract |
| `deskilo-widget-test-gotchas` | a widget test fails for a reason that is not the code |
| `deskilo-reports` | anything printed: kinds, placeholders, layouts, the CLI, the letter standard |
| `deskilo-ci-release` | after the push: required checks, watchers, auto-merge, the release train, the web publish |
| `deskilo-forms` | any form: the scaffold (sheet, dialog, wizard, screen), the form kit, domain-first validation, the form checklist and ratchets |
| `deskilo-documentation` | the guides, the help anchors, the screenshot pipeline: anything under `docs/wiki`, `assets/help` or a help symbol |
| `project-evolution-playbook` | the project-agnostic method, for OTHER repos only |

Global skills that also apply: `git-pr-workflow`, `flutter-dart-best-practices`,
`dart-flutter-mcp`, the platform deployment skills.

Which issue to take next: [#2596](https://github.com/fdittgen-png/deskilo/issues/2596) (programme selection; #1447 keeps the pilot/release qualification). Read the selected issue, its later corrections and the current claims.

Ready, Done, closure (`Refs` vs `Closes`) and the glossary: `docs/AGENT_RULES.md#ready-done-and-closure`.

## Execution loop

Read #2596 and the selected leaf before choosing work, and again after a handoff
or context compaction. Check actual branches and `.agent-work` claims. Keep at
most two coding workstreams and one owner per shared producer/consumer contract.
Do not repeat delivered checkpoints or substitute easier breadth without recording
the exact blocker and return condition in the existing queue.

After creating your worktree, run `python3 scripts/worktree_prepare.py`.
`--resolve` explicitly initializes root and independent packages; no shared Pub
workspace is created. For database work choose `--require-database` or
`--database-ci` and name the actual fixture/run evidence. Tool readiness is not
test success. Do not silently narrow analysis to hide unresolved packages.

Before pushing: preflight `--list`, only implicated generators, then analyze,
lint and affected tests on the resulting tree. Preserve original exits and review
generated edits. Do not run the full preflight/build_runner on a shared worktree
by default, and never reset another contributor's edits to make setup pass.
A clean preflight is not proof of full CI acceptance.

Finish code + actual consumer + success/refusal/recovery tests. If behavior is
done and only evidence is missing, obtain the evidence without rewriting code.
Close a leaf when its own scoped acceptance is verified; parent scope alone is
not a closure blocker. Keep release/operator gates separate. Record the next
outcome in #2596. Do not deploy or change permissions automatically.

## Non-negotiables in one breath

One registry-touching branch at a time. Harness a migration before you apply it.
Every user-facing string in ARB ×5. Every functionality behind a `WorkspaceFeature`. No hardcoded business value — configuration with a UI point (`docs/AGENT_RULES.md`).
`web/setup.html` in the same PR as any parameter. Before a push: `dart analyze --fatal-infos`,
`flutter test test/lint` and the affected test folders — the full suite runs in CI only. Never format whole directories. Never use the `alpha1`
track — `alpha` is the closed test the testers are enrolled in, and the train ships to it.
