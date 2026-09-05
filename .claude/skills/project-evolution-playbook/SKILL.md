---
name: project-evolution-playbook
description: Project-agnostic method for evolving a codebase with an agent, distilled from DesKilo — issue first, one registry-touching branch at a time, harness before apply, pins and budgets as ratchets, docs in the same PR, a memory file for the non-obvious, background suites and watchers, and how to recover from the rebase cascade. Trigger when setting up an agent workflow in a new repository or when asked to "apply the same method" elsewhere.
---
# Project evolution playbook (copy to any repo)

## Principles
1. **Issue first, one branch at a time.** Most repos have "registries"
   — enums, manifests, pins, generated lists — that every change appends
   to at the same spot. Parallel branches there conflict on every merge.
   Cut → PR → merge → next; stack only when work must overlap.
2. **Prove before you apply.** Anything irreversible (a migration, a
   deploy) runs first as a rolled-back harness whose assertions are the
   error message. Then apply the same text. Then read back what exists.
3. **Ratchets, not opinions.** Lint tests pin counts (features, routes,
   placeholders, file lengths, hard-coded strings, wall clocks). A bump
   is fine; a bump WITHOUT a dated reason is not.
4. **Producer and consumer ship together**, and docs ship with them:
   wiki (every locale), the setup questionnaire, the ADR, the agent rules.
5. **Tests tap what they add.** A new affordance without a tapping test
   is not done. Lazy lists, queued snackbars and taller columns are the
   usual reasons a good feature fails its test — fix the harness, not
   the feature.
6. **Never trust a suite that ran across a branch switch**, a formatter
   on files you did not author, or a green watcher whose grep matched a
   job name. Read the actual states.
7. **Memory holds the non-obvious**: ids, applied migrations, gotchas,
   owner decisions, the next number. The repo holds the rules.

## Per-project skill set (make one of each)
- `<project>-ship-feature`: the registries to touch and the verify commands.
- `<project>-<backend>-migration`: harness idiom + apply + verify.
- `<project>-widget-test-gotchas`: a symptom → cause → fix table, grown per incident.
- `<project>-ci-release`: exact commands to watch, merge, deploy; what is forbidden.
- Domain skills for the parts with their own vocabulary (reports, validation, billing).

## Working rhythm with an agent
- Batch reads; act as soon as enough is known; keep a scratchpad for
  staged scripts and suite logs.
- Long jobs (`flutter test`, CI) go to the background with a log file;
  a watcher loop polls JSON states and wakes the session.
- When the owner changes a rule mid-flight, write it into the repo's
  rules file and the memory in the same turn, then obey it from the
  next branch on.
- Report outcomes plainly: what merged, what deployed, what stays
  owner-side, what was filed instead of slipped in.
