# DesKilo — read this first

Binding rules for humans and agents live in `docs/AGENT_RULES.md` (hard
rules, coding, feature-flag lifetime, testing, git, setup.html, reports,
identity form, one-branch-at-a-time). This file only indexes the skills.

## Project skills (`.claude/skills/`)

| Skill | Use it when |
|---|---|
| `deskilo-ship-feature` | starting ANY issue: claim → worktree → flag ritual → local gates (suite lock) → docs → PR → merge master once |
| `deskilo-supabase-migration` | a migration, RPC, policy or pgTAP file: number at push time, prove on dev, apply, predict the contract |
| `deskilo-widget-test-gotchas` | a widget test fails for a reason that is not the code |
| `deskilo-reports` | anything printed: kinds, placeholders, layouts, the CLI, the letter standard |
| `deskilo-ci-release` | after the push: required checks, watchers, auto-merge, the release train, the web publish |
| `deskilo-documentation` | the guides, the help anchors, the screenshot pipeline: anything under `docs/wiki`, `assets/help` or a help symbol |
| `project-evolution-playbook` | the project-agnostic method, for OTHER repos only |

Global skills that also apply: `git-pr-workflow`, `flutter-dart-best-practices`,
`dart-flutter-mcp`, the platform deployment skills.

Ready, Done, closure (`Refs` vs `Closes`) and the glossary: `docs/AGENT_RULES.md#ready-done-and-closure`.

## Non-negotiables in one breath

One registry-touching branch at a time. Harness a migration before you apply it.
Every user-facing string in ARB ×5. Every functionality behind a `WorkspaceFeature`.
`web/setup.html` in the same PR as any parameter. `dart analyze --fatal-infos` (what CI runs)
and the full suite (one at a time on a shared machine) before a push. Never format whole directories. Never use the `alpha1`
track — `alpha` is the closed test the testers are enrolled in, and the train ships to it.
