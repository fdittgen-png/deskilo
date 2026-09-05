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
