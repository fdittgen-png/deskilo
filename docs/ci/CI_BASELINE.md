# CI baseline — what a pull-request run costs

Measured with `scripts/ci_timings.sh 20` on 2026-09-18 over the **20 most
recent completed pull-request runs** of `CI · Quality report`. Twenty runs
is a sample, not a distribution: p95 over twenty is the second-slowest
run. Cache state is not labelled per run, so no number here is a
"speedup"; the point is to know where the minutes go before changing
anything (#1446 C0).

| job | n | success | queue p50 | queue p95 | run p50 | run p95 |
|---|---|---|---|---|---|---|
| analyze · l10n gate · test · coverage | 20 | 16 | 3 s | 7 s | 1 368 s | 1 560 s |
| quality · database | 20 | 14 | 3 s | 30 s | 500 s | 573 s |
| quality · report | 20 | 14 | 3 s | 3 s | 8 s | 11 s |

Steps of twenty seconds or more, median over the runs that ran them:

| job · step | median |
|---|---|
| code · Tests with coverage | 1 183 s |
| code · Analyze (lib + test) | 33 s |
| code · Accessibility (rerun of a subset) | 32 s |
| code · Localization (rerun of a subset) | 24 s |
| code · Flutter SDK setup | 25 s |
| database · Database disciplines (pgTAP) | 410 s |
| database · Migration safety (replay from empty) | 66 s |
| database · Install, resume and upgrade a real schema | 48 s (n=2, in flight) |

## What this says

- The code job is the critical path, and **86 % of it is the one
  coverage run of the suite** (1 183 of 1 368 s). The five discipline
  reruns that C1 removes cost about 100 s together — worth removing
  because each was a second Flutter start over tests that had already
  run, not because they were the problem.
- The database job finishes in a third of the code job's time. Its
  restore drill takes two seconds; dropping it would change nothing.
- Queueing is not a cost on this repository (p50 3 s).
- Four of twenty code runs and six of twenty database runs failed; the
  database failures include a day on which every run booked a Saturday
  (`24_booking_idempotency.sql`, fixed by #1476).

## What runs for which change (C2)

`tool/ci_classify.dart` reads the complete pull-request diff (`git diff
--name-status -z base head` over full git data, renames counted under
both names) and says, per heavy discipline, `required` or
`not_applicable` with its reason and the classifier version. It starts
from a positive list of paths that cannot reach the database job —
docs, help assets, localisation, presentation and provider code, the
platform folders, widget and unit tests — and everything else, every
push to master, the nightly run, a dispatch, a missing base, an empty
diff, or a change to a workflow, script, generator, lockfile or the
classifier itself, runs everything. The code job always runs: the
Flutter suite is the required context, and a wiki or setup change is
its concern (help generation, parity tests), not a docs stub.

When the database job is stood down it still reports: every database
row says `not_applicable` with the reason, and `scripts/quality_report.sh`
accepts that only because `report/classification.txt`, the classifier's
own verdict, says so. The browser build keeps its own path trigger,
which the classifier's `web` verdict mirrors.

## The gate

`.github/quality-manifest.psv` names every row the report must carry
and which job produces it. `scripts/quality_report.sh` fails when a row
is missing, duplicated, unknown, or `skipped` where the manifest does
not allow it. The code job ends in a `Gate` step that fails on the test
run, the row derivation or the coverage gate, so the one required
context carries the complete code result rather than a subset of it.

Live branch protection on `master` at the time of writing required only
`analyze · l10n gate · test · coverage`; `scripts/branch_protection.sh`
names the three contexts the repository intends.

## Reproduce

```
scripts/ci_timings.sh 20
```

Requires `gh` and `jq`; reads the Actions API only.
