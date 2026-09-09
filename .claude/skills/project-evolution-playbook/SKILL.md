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

## Documentation and help (the portable half)

`docs/guides/help-framework.md` holds the method in full. The three rules
worth carrying to any repository:

- **One anchor names four things** — the help symbol, the guide heading,
  the screenshot and its crops. It is what makes the symbol open the
  exact object, and what makes a new screenshot replace the old one for
  free. Carry it as an invisible HTML comment above the heading, never a
  visible `{#id}`.
- **A guide that is not translated yet compiles into its own language
  only**, and no help symbol may point into it until every language has
  it. A reader never gets a page that changes language halfway.
- **Write the text before the screenshot exists**: an `<!-- image: name -->`
  slot renders as nothing, a tool lists what is waiting, and filling one
  never touches a sentence.

Adopting it in an app with no help surface: the pipeline, the guides and
the technical reference first — the wiki becomes real without touching
the product — then the help screen as ordinary feature work, with a
ratchet lint counting the symbols that still open the nearest section.

## Reviewing, and the discipline around a live finding

- **Fix a live exposure before you write it up, if the repository is
  public.** A review that publishes an unauthenticated hole in a public
  issue is an advisory with a working address in it. Close the grant,
  verify it, then describe it in the past tense. `gh repo view --json
  visibility` costs nothing and decides how you write.
- **Quantify, root-cause, and name the worst case.** "Some functions are
  over-permissioned" moves nobody. "99 of 260, because `CREATE OR
  REPLACE` preserves the ACL, and here is the one with no internal
  check" gets fixed the same afternoon.
- **Verify before reporting a hole.** Two functions looked equally
  exposed; one guarded itself one call deeper (`my_active_member` →
  `auth.uid()`) and was fine. Reporting it would have cost the review
  its credibility. Read the body, not the name.
- **Say what is already right.** RLS on every table, four policy-less
  tables that are the deliberate deny-all secrets tables, a coverage
  gate whose own comment explains why it moved. A review that is only
  faults reads as a list of grievances; one that says what holds is
  trusted about what does not.
- **Measure the cost of a recommendation before making it.** "Turn on
  the strict analyzer modes" is an opinion; "12 findings across 177 000
  lines, 3 of them errors, all one idiom" is a decision someone can take
  in an afternoon.
- **Decline the findings you did not measure.** Eleven sorts inside
  `build()` look like a finding and are probably nothing at that size.
  Writing "no task, deliberately — profile it first if a list ever feels
  janky" is worth more than a task nobody can justify.

## Handing work to another agent

One issue, not a tree. Ordered tasks with the dependencies stated, one
PR each, acceptance criteria per task, the gates spelled out — and an
explicit **what not to do**: do not open child issues, do not mass-fix
the harmless instances of a pattern (the diff buries the ones that
mattered), do not refactor for a line count alone.
