---
name: deskilo-ci-release
description: Watching CI, merging and deploying DesKilo — the JSON check-state idiom (the analyze job is named "analyze · l10n gate · test · coverage"), background watcher loops, cancelled jobs, mergeStateStatus, squash-merge, the beta release train, the opt-in web Pages publish, and what must never be used (alpha track, --admin, force-push to master). Trigger after opening a PR or when asked to deploy.
---
# CI, merge, deploy (DesKilo)

## Watch a PR without polling by hand
```
gh pr checks <n|branch> --json name,state          # states: SUCCESS|FAILURE|SKIPPED|IN_PROGRESS|PENDING
until s=$(gh pr checks <n> --json name,state) && ! echo "$s" | grep -qE '"state":"(PENDING|QUEUED|IN_PROGRESS|EXPECTED)"'; do sleep 60; done
```
Run that in the background (`run_in_background`) with a leading `sleep`;
`gh pr checks --watch` right after `pr create` exits 1. Do NOT grep the
plain output for "pass": the analyze job's name contains "l10n" and
"test", which pollutes greps. Failing test: `gh run view <id> --log-failed | grep -a "❌"`.
A job in state `cancelled` is a runner hiccup — `gh run rerun <id>`.

## Merge
`gh pr view <n> --json mergeable,mergeStateStatus` → `MERGEABLE CLEAN`
then `gh pr merge <n> --squash --delete-branch`. `BLOCKED` = checks
missing; never `--admin`. With a stacked PR do not `--delete-branch` the
base (GitHub closes the child). `BEHIND`/`CONFLICTING` after a sibling
merged = the cost of parallel registry branches — avoid by serialising
(`deskilo-ship-feature`); if it happens anyway, `git rebase origin/master`,
resolve by keeping BOTH sides in order (plain concatenation, never
line-dedupe — it drops shared closers like `),`), re-pin
(feature pin = enum size), regenerate l10n, `git commit --amend`, push
with `--force-with-lease`, then hand-merge any data-map call site where
two branches touched the same lines.

## Deploy
- Beta train (iOS TestFlight external + Play closed alpha + web + DMG + MSI):
  `gh workflow run release-train.yml -f track=beta -f release_notes="…"`;
  watch `gh run view <id> --json status,conclusion`.
- Web Pages publish is opt-in: `gh workflow run web.yml -f ref=master -f deploy=true`.
- Never the Play "alpha1"/open testing track; F-Droid is frozen.
- Owner-side blockers stay listed in memory (BETA_CONTACT_PHONE, logo upload).

## Lessons of 2026-09-07
- The reliable waiter: `until gh pr checks <n> --json name,bucket | jq -e 'length>0 and all(.bucket!="pending")'; do sleep 30; done`
  then `gh pr view <n> --json mergeable,mergeStateStatus`. Start it with
  a leading `sleep 120` right after `pr create`; a force-push restarts
  the checks — start a NEW waiter, the old one reports the old head.
- `analyze · l10n gate · test · coverage: cancel` = a runner cancellation:
  `gh run rerun <run-id>` (find it with `gh run list --commit <sha>`),
  never a code change.
- Several merges in a row need ONE train: dispatch after the last merge.
  Every train + web publish pair is watched with `gh run watch <id> --exit-status`
  in the background and reported per job.
- The wiki mirror: clone `deskilo.wiki.git` into the scratchpad once,
  copy `docs/wiki/*.md` after each merge that touched them, commit, push.

## Lessons of 2026-09-09

- **Workflow names follow `<Group> · <what it does>`** — CI, Nightly,
  Release, Publish, Status, Tools — the same convention as Sparkilo, so
  one habit reads both sidebars. `.github/workflows/README.md` has the
  table and the rules; `test/lint/workflow_naming_test.dart` enforces
  the shape, uniqueness and sentence case.
- **A workflow name is free to change; a JOB name is not.** A job name
  is a required status-check context, so renaming one can block
  auto-merge until branch protection is updated in lockstep. Rename the
  workflow, leave `analyze · l10n gate · test · coverage` alone.
- **Android deploy, in one line each.**
  `gh workflow run release-train.yml -f track=beta -f release_notes="…"`
  puts iOS and Android on the same commit — that is the point of the
  train. `play-internal.yml -f track=internal` is the Android leg alone.
- **A commit pushed by `GITHUB_TOKEN` starts no workflow run.** The
  lockfile-regeneration workflow pushes as the bot, and every check on
  its commit then sits at `action_required` for ever. Re-author that
  commit (`git commit --amend` from a real user, force-with-lease) and
  the runs start. Waiting is not a strategy — nothing is coming.
- **Another agent may hold the working tree.** Mid-task the checkout
  switched branches under me. Commits already pushed are safe; finish
  from a fresh `git clone --depth 3 --branch <b>` in the scratchpad
  rather than fighting over the directory.
