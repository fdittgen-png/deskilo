# DesKilo — read this first

Binding rules for humans and agents live in `docs/AGENT_RULES.md` (hard
rules, coding, feature-flag lifetime, testing, git, setup.html, reports,
identity form, one-branch-at-a-time). This file only indexes the skills.

## Project skills (`.claude/skills/`)

| Skill | Use it when |
|---|---|
| `deskilo-ship-feature` | starting ANY feature: issue → branch → flag ritual → tests → docs → PR → merge → train |
| `deskilo-supabase-migration` | writing a migration or RPC: harness first, apply, verify live |
| `deskilo-widget-test-gotchas` | a widget test fails for a reason that is not the code |
| `deskilo-reports` | anything printed: kinds, placeholders, layouts, the CLI, the letter standard |
| `deskilo-ci-release` | watching CI, merging, dispatching the beta train or the web publish |
| `project-evolution-playbook` | the project-agnostic method; copy it to other repos |

Global skills that also apply: `git-pr-workflow`, `flutter-dart-best-practices`,
`dart-flutter-mcp`, `epic-triage` / `epic-scaffolder`, the platform deployment skills.

## Non-negotiables in one breath

One registry-touching branch at a time. Harness a migration before you apply it.
Every user-facing string in ARB ×5. Every functionality behind a `WorkspaceFeature`.
`web/setup.html` in the same PR as any parameter. `flutter analyze --fatal-infos lib test tool`
and the full suite before a push. Never format whole directories. Never use the alpha track.
