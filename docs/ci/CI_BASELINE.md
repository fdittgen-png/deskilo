# CI baseline — what a pull-request run costs

Measured with `scripts/ci_timings.sh 20` on **2026-09-20** over the 20
most recent completed pull-request runs of `CI · Quality report`. Twenty
runs is a sample, not a distribution: p95 over twenty is the
second-slowest run. The run ids are listed below so the table can be
re-derived rather than believed (#1446 C0).

Read the September-18 figures in this file's history as a separate
sample, not as a before-and-after: the two were taken on different days,
different change classes and unlabelled cache states, and nothing here
is a speedup claim.

| job | n | success | queue p50 | queue p95 | run p50 | run p95 |
|---|---|---|---|---|---|---|
| analyze · l10n gate · test · coverage | 20 | 18 | 3 s | 3 s | 1 466 s | 1 530 s |
| classify the change | 20 | 20 | 3 s | 3 s | 22 s | 26 s |
| quality · database | 20 | 14 | 3 s | 3 s | 593 s | 610 s |
| quality · report | 20 | 13 | 3 s | 4 s | 8 s | 11 s |

Steps of twenty seconds or more, median over the runs that ran them:

| job · step | median | n |
|---|---|---|
| code · Tests with coverage | 1 377 s | 20 |
| code · Analyze (lib + test) | 36 s | 20 |
| code · Run subosito/flutter-action@v2 | 21 s | 20 |
| database · Database disciplines | 413 s | 20 |
| database · Migration safety | 65 s | 20 |
| database · Install, resume and upgrade a real schema | 51 s | 20 |
| database · Run subosito/flutter-action@v2 | 20 s | 20 |

## The sample

Twenty runs, all `pull_request`, all first attempts (`run_attempt` 1), so
no rerun and no cancelled runner-seconds are folded into the numbers.
Thirteen succeeded, five failed, two were cancelled as superseded.

```
35494426470 4eb12b126 success    35482079602 223dd72e3 success
35489325766 8400b40ac failure    35481612937 2268ee46f cancelled
35489178736 78da437d1 success    35470259739 0f47f60e8 success
35488757482 262d01b27 failure    35469035609 e2a87053e success
35488678413 dffc660e8 failure    35468555908 b0d3711b8 success
35487711868 cd595268b failure    35464603756 d6986a804 success
35487032160 60684f469 success    35463662649 24a863712 cancelled
35486045793 f413d419b failure    35463406285 21b2ab711 success
35485239663 eb14cf3cd success    35460612454 6d97ab135 success
35483870526 35b6e7f5c success    35459106628 e220644da success
```

**Change class.** The `classify the change` job ran on all twenty and
required the database job on all twenty — every sampled pull request was
database-relevant, so this sample says nothing about what a
docs-or-widget-only change costs. There is no second class to compare
with here.

**Cache state.** Not labelled by the API, so the SDK setup step stands in
for it: 15–34 s in seventeen of the eighteen runs measured, and 87 s once
(35488757482). That spread is small next to a 1 377 s test step, which is
the honest conclusion — **not** that a warm cache is 66 s faster than a
cold one. No number in this file is a cache-hit-versus-cold comparison.

## What this says

- The code job is the critical path and **94 % of it is the one coverage
  run of the suite** (1 377 of 1 466 s). Everything else in that job —
  checkout, SDK, generation, analyze, the gate — is under ninety seconds
  together. Any real saving is in the suite or it is noise.
- The database job is 40 % of the code job's wall time and runs in
  parallel with it, so it is not on the critical path. Its restore drill
  costs about two seconds; removing it would change nothing.
- Queueing is not a cost on this repository: p50 3 s, p95 4 s.
- Seven of twenty runs did not succeed, and the two halves did not fail
  together: the code job succeeded in 18 of 20, the database job in 14
  of 20 and the report in 13. A code job that is green while the
  database job is red is the enforcement problem below, not a timing
  one.

## What runs for which change (C2)

`tool/ci_classify/classify.dart` reads the complete pull-request diff
(`git diff --name-status -z base head` over full git data, renames
counted under both names) and says, per heavy discipline, `required` or
`not_applicable` with its reason and the classifier version. It starts
from a positive list of paths that cannot reach the database job —
docs, help assets, localisation, presentation and provider code, the
platform folders, widget and unit tests — and everything else, every
push to master, the nightly run, a dispatch, a missing base, an empty
diff, or a change to a workflow, script, generator, lockfile or the
classifier itself, runs everything. The code job always runs: the
Flutter suite is the required context, and a wiki or setup change is
its concern (help generation, parity tests), not a docs stub.

Browser-relevant paths are `web/`, `lib/`, `assets/`, `packages/`,
`pubspec.yaml`, `pubspec.lock` and the web workflow itself.
`packages/` was added by #1446 R3: `packages/deskilo_push` is a path
dependency that `lib/core/push/push_providers.dart` imports, so a
`dart:io` import added there breaks `flutter build web` and nothing
else. `web.yml`'s `pull_request` filter carries the same list, and
`test/tool/ci_classify_test.dart` fails when the two drift.

The workflow calls the classifier through `scripts/ci_classify.sh`,
which is fail-closed by construction: a base git cannot resolve, a diff
git cannot write, a change list whose records are cut short or carry a
status git does not emit, all classify as `required`; a classifier that
exits nonzero, or a verdict file with a discipline missing, ends the
step red and leaves no verdict. `test/tool/ci_classify_script_test.dart`
drives each of those through the real script over a real temporary
repository — a rename, a deletion, names with a space and a newline,
over 300 files — with a docs-only change as the green control.

When the database job is stood down it still reports: every database
row says `not_applicable` with the reason, and `scripts/quality_report.sh`
accepts that only because `report/classification.txt`, the classifier's
own verdict, says so.

## The gate

`.github/quality-manifest.psv` names every row the report must carry
and which job produces it. `scripts/quality_report.sh` fails when a row
is missing, duplicated, unknown, or `skipped` where the manifest does
not allow it. The code job ends in a `Gate` step that fails on the test
run, the row derivation or the coverage gate, so the one required
context carries the complete code result rather than a subset of it.

`scripts/coverage_gate.sh` refuses a layer with no measured lines as
well as one below its floor (#1446 R2): an LCOV that lost `domain/` and
`presentation/` used to score 100 % and exit 0, because two of the three
floors were never measured. Absent evidence is now a failure naming the
layer, and an empty, malformed or lib-less report fails as a reporting
error rather than a score. `test/lint/coverage_gate_test.dart` drives
each refusal through the real script.

## What is still not enforced

Live protection on `master`, read 2026-09-20:

```
contexts: ["analyze · l10n gate · test · coverage"]   strict: false
```

`scripts/branch_protection.sh` names three. The two that are missing are
not academic: on 2026-09-20 pull requests **#1569, #1571, #1573 and
#1574** merged into master with `quality · database` *and*
`quality · report` red — one cause, a stale `assets/instance/contract.txt`
after migration 0255 — while the one required context was green.

Applying repository settings is an owner operation. The command is

```
scripts/branch_protection.sh apply-checks
```

which PATCHes the `required_status_checks` sub-resource only, leaving
reviews, restrictions, linear history and the force-push and deletion
settings untouched — unlike `apply`, which PUTs the whole protection
object and resets every field it does not name. #1446 R1a made it
additive — it reads the live list and sends live ∪ committed at the live
strictness, so an extra context, its app binding and the current `strict`
survive — and made `apply` refuse over protection it has read
(`apply --reset` to mean it) or could not read.

**Three results, never two.** Every command ends on one `result=` line,
and the exit status says the same: `verified-match` (0), `verified-drift`
(1, a branch read as unprotected included), `unverified-access` (2,
nothing was looked at: 403 or no answer). Only the first is settings
proof, and the CI step runs `verify --advisory`, which exits 0 whatever
happens but prints and summarises that line.
`test/tool/branch_protection_test.dart` drives the real script against a
stub API for each answer.

## Reproduce

```
scripts/ci_timings.sh 20
```

Requires `gh` and `jq`; reads the Actions API only.
