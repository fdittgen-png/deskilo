---
name: deskilo-ci-release
description: After a DesKilo push — the three required checks ("analyze · l10n gate · test · coverage", "quality · database", "quality · report"), one bounded background watcher per PR, cancelled vs real failures, auto-merge pinned to the head SHA, verifying MERGED, master red with every PR green, the release train (-f track=alpha|production), the opt-in web Pages publish, and what is forbidden (--admin, force-push to master, renaming a required job, the retired alpha1 track). Trigger once a PR is open, when a check is red or stuck, when master is red, or when asked to deploy.
---
# CI, merge, deploy (DesKilo)

**Essentials**
1. Required on master: `analyze · l10n gate · test · coverage`, `quality · database`, `quality · report`.
2. `gh pr merge <n> --auto --squash --match-head-commit <sha>`, then verify `MERGED` on origin/master. Never `--admin`.
3. One bounded watcher per PR in the background; read JSON states, never grep the plain output.
4. `cancelled` = runner/concurrency, rerun once; infrastructure flakes get ONE rerun; anything else is real.
5. Deploy with ONE train after the last merge: `gh workflow run release-train.yml -f track=alpha`.

Android build notes and older incidents: [reference.md](reference.md).

## Watch
```
sleep 90   # a watcher started right after a push sees the OLD run
until gh pr checks <n> --json name,bucket | jq -e 'length>0 and all(.bucket!="pending")'; do sleep 60; done
gh pr view <n> --json state,mergeable,mergeStateStatus,headRefOid
```
- Run it with `run_in_background`, exiting on MERGED or a failure. A new push
  restarts the checks: start a NEW watcher; the old one reports the old head.
  `gh pr checks --json` has `state`/`bucket`, no `conclusion` field;
  `gh pr checks --watch` right after `pr create` exits 1 (no checks yet).
- Do NOT grep the plain output for "pass": the analyze job's name contains "l10n"
  and "test". A failing test: `gh run view <id> --log-failed | grep -a "❌"`; a
  finished job's log mid-run: `gh api repos/{owner}/{repo}/actions/jobs/<job>/logs`.

## Failures that are not the code
- **`cancelled` / `CANCELLED`** — a runner hiccup or the concurrency group (a newer
  push superseded it): `gh run rerun <run-id>` (find it with `gh run list --commit <sha>`).
- **Infrastructure flakes get ONE rerun**: "port … is still held by an earlier
  pass", a Supabase CLI download rate limit. Anything else is real.
- **`quality · report` can read a stale attempt** after `gh run rerun --failed`; do
  not rerun it a third time — push an empty commit (`ci: re-run the quality report
  on a clean attempt`).
- **A red `quality · database` holds the PR OPEN/BLOCKED** — usually a stale
  `contract.txt` (`deskilo-supabase-migration` §4).
- **A commit pushed by `GITHUB_TOKEN` starts no workflow run** (checks sit at
  `action_required` for ever): re-author it as a real user. Waiting is not a strategy.
- **Master can be red with every PR green** (#1815 added a required constructor
  parameter, #1817 a test building the old shape). `dart analyze` on a fresh
  worktree of origin/master finds it; fix it in your PR with the one-line change
  and name it in the body.

## Merge
- `gh pr merge <n> --auto --squash --match-head-commit <sha>` — queue it as soon as
  the PR is open; a queued auto-merge is not a merge, and a new head SHA invalidates
  earlier evidence (AGENT_RULES "Ready, Done and closure"). Then confirm
  `gh pr view <n> --json state,mergedAt` and that the squash commit is on origin/master.
- `BLOCKED` = a required check is missing or red; never `--admin`, never force-push
  to master. `BEHIND`/`CONFLICTING` = merge master once (`deskilo-ship-feature` §5).
- A workflow's name is free to change (`<Group> · <what it does>`, enforced by
  `workflow_naming_test`, table in `.github/workflows/README.md`); a JOB name is a
  required status-check context — never rename `analyze · l10n gate · test · coverage`
  without updating branch protection in lockstep.

## Deploy
- **The train**: `gh workflow run release-train.yml -f track=alpha -f release_notes="…"`
  (or `-f track=production`). The input IS the Play track; it puts iOS (TestFlight
  external), Android (Play closed alpha), web, DMG and MSI on ONE commit. Several
  merges in a row need ONE train, dispatched after the last merge; watch each run
  with `gh run watch <id> --exit-status` in the background and report per job.
- `play-internal.yml -f track=internal` is the Android leg alone. The PR checks do
  not build Android; the train does.
- **Web Pages publish is opt-in**: `gh workflow run web.yml -f ref=master -f deploy=true`.
  Merging `web/setup.html` does not publish it.
- Never the Play `alpha1` / open-testing track. F-Droid is frozen (owner-blocked).
- The alpha → production countdown is not advanced by shipping: twelve testers must
  each opt in at `play.google.com/apps/testing/de.deskilo.app`, then 14 continuous
  days. A green train is not progress toward production.
- Wiki mirror after a docs merge: `/doc-wiki`.
