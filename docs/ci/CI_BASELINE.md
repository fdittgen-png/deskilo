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
else. `web.yml` no longer carries a `pull_request` path filter of its
own: it starts on every pull request and asks the same classifier,
through `.github/actions/classify-change`, whether the build is
required — one decision, two consumers, no second list to drift — and
stands the build down only after reading `web|not_applicable` back from
its `web-classification` artifact. The release train and a dispatch are
not pull requests and always build; publication stays a separate,
explicitly authorised step, and a stood-down or failed build never
publishes. `test/tool/ci_classify_test.dart` holds that shape.

Both workflows call the classifier through `scripts/ci_classify.sh`,
which is fail-closed by construction: a base git cannot resolve, a diff
git cannot write, a change list whose records are cut short or carry a
status git does not emit, all classify as `required`; a classifier that
exits nonzero, or a verdict file with a discipline missing, ends the
step red and leaves no verdict. `test/tool/ci_classify_script_test.dart`
drives each of those through the real script over a real temporary
repository — a rename, a deletion, names with a space and a newline,
over 300 files — with a docs-only change as the green control.

When the database job is stood down it still reports: every database
row says `not_applicable` with the reason, and BOTH the job and
`scripts/quality_report.sh` accept that only after reading the verdict
back from the `quality-classification` artifact. Every other outcome of
the classifier — `required`, an empty output from a classify job that
died, a word nobody expected — runs the database work.

## The gate

`.github/quality-manifest.psv` names every row the report must carry
and which job produces it. `scripts/quality_report.sh` fails when a row
is missing, duplicated, unknown, or `skipped` where the manifest does
not allow it. The code job ends in a `Gate` step that fails on the test
run, the row derivation or the coverage gate, so the one required
context carries the complete code result rather than a subset of it.

Every gate is `scripts/job_gate.sh` (#1446 C2): green only when each
outcome it is handed is exactly `success` — `skipped`, `cancelled`, an
empty outcome and a gate given nothing are red, where the inline loops
before it failed only on `failure`. The database and report jobs are
`if: always()`, because a job skipped by a failed dependency counts as a
passing required context; the report is the always-evaluated final
word, red unless the table is complete and every job it waited on —
the classifier included — succeeded. `test/tool/job_gate_test.dart`
and `test/lint/required_contexts_test.dart` hold that shape.

`scripts/coverage_gate.sh` refuses a layer with no measured lines as
well as one below its floor (#1446 R2): an LCOV that lost `domain/` and
`presentation/` used to score 100 % and exit 0, because two of the three
floors were never measured. Absent evidence is now a failure naming the
layer, and an empty, malformed or lib-less report fails as a reporting
error rather than a score. `test/lint/coverage_gate_test.dart` drives
each refusal through the real script.

## One candidate, bounded reuse (C4)

The release train resolves the requested ref **once**, in its `resolve`
job, to a full commit SHA (`gh api .../commits/<ref>`, so a branch, a
tag or a SHA all answer with one commit), and every leg — Play,
TestFlight, macOS, Windows, web — receives that SHA as its required
`workflow_call` input `source_sha`. Before #1446 C4 each leg checked out
a branch NAME at its own start, and the Android leg checked out `master`
whatever was asked: a push to master while the train ran put two commits
in one train under one label. A leg run alone pins its own source the
same way, before its checkout: the dispatch ref resolved through the
API, or the commit the event carries. The checkout takes the SHA, and
`.github/actions/source-identity` then refuses to continue unless
`git rev-parse HEAD` is that SHA, and records SHA, flavor, dart-defines
and base href in the step summary and in a `source-identity-<leg>`
artifact (replaced, never duplicated, on a rerun). Artifacts are named
after the built SHA, not the caller's dispatch-time `github.sha`. The
train's report lists `resolve` as a leg and counts a skipped leg as one
that did not ship. Nothing here publishes: the train is not dispatched
by this change, and the Pages deploy stays the separate explicit step.

Caches carry dependencies and toolchains only: the pub cache keyed on
`pubspec.lock`, CocoaPods on `Podfile.lock`, the emulator image on its
own API-and-device name; the Flutter SDK cache of `flutter-action` is
keyed by the action on version, channel and OS. No cache path is a test
result, a report or a build tree, no key names a run or a pull request,
and no publish job (`deploy`, `report`) restores anything — GitHub scopes
a pull request's cache to that pull request, so a fork cannot write what
a release job reads, and the lint keeps it that way by construction.
Runtimes stay as pinned as they were: Flutter by `FLUTTER_VERSION`, Ruby
3.3, Python 3.12, Java 17, WiX 5.0.2, `macos-15`; Xcode deliberately
floats to `latest-stable` because Apple refuses uploads built with an
older SDK. No dependency was bumped for this.

Concurrency groups are per workflow (the group starts with the file's
own name, so no workflow can cancel another's work) and, for anything a
pull request triggers, per ref. `cancel-in-progress` is `false` or
`${{ github.event_name == 'pull_request' }}` — never a bare `true`: a
superseded pull-request push cancels its predecessor, and a dispatch, a
nightly run, a train leg or a Pages deploy someone started on purpose
queues behind the one already running. That queue is GitHub's own
(at most one pending per group); it orders nothing and is not a
dependency. `test/lint/workflow_source_identity_test.dart` reads every
workflow as YAML and holds all of the above. No duration is claimed for
any of it: this checkpoint is correctness only, unmeasured.

## Shared setup without coupling (C5)

**One measured run per candidate and flavour.** The code job runs the
suite once, with coverage, and every row is derived from that stream
(C1). Two other Flutter runs exist and both are kept, because each is a
different candidate, not another report of the same one:

- `packages/deskilo_push` runs its own suite in the code job. It cannot
  live in `test/` because the F-Droid job swaps the package for its
  Google-free twin before running that tree (#1558); it is seconds.
- `CI · F-Droid no-GMS audit` runs the root suite again under the libre
  flavour. `tool/fdroid_foss_swap.sh` changes the resolved dependency
  graph — the Firebase transport for the twin, seven packages out of the
  lockfile — and the suite is the proof that the app compiles and
  behaves on that graph. Same tests, different candidate; a row derived
  from the first stream would say nothing about the second. It is
  path-filtered (`packages/`, `pubspec.yaml`, `lib/core/push/`,
  `fdroid/`, itself), so it is not a cost on every pull request. Its
  four successful runs of 2026-09-20 (35485239589, 35486020161,
  35494426503, 35495613901): job 1 230–1 662 s, of which the analyze-and-
  test step 828–1 098 s and the release build 357–521 s.
- Since C5a both trees regenerate through `scripts/generated_drift.sh`:
  the audit's regeneration is byte-equal to the commit or it says which
  file is not. On 2026-09-25 the audit was red on master for exactly
  that while the required job was green.

**One stack per job.** `supabase start` happens in one place,
`.github/actions/local-stack`, which the database job calls once as its
`migrations` step; the action publishes the database address as an
output and every step after it takes `DB_URL` from that output or asks
`supabase status` on the same runner. No file under `scripts/` starts a
stack. The Stripe checks already attach this way; an MCP or auth
producer is one more step after `migrations` — `if:
steps.migrations.outcome == 'success'`, `continue-on-error: true`, a row
in `.github/quality-manifest.psv` — and `test/lint/local_stack_harness_test.dart`
is red when it starts a stack of its own.

**Fixtures that do not depend on order.** All 44 pgTAP files open with
`begin;` and end with `rollback;` (the lint holds it), so none can read
another's rows. The race scripts create rows under fixed ids and remove
them; the payment checks name their users and sessions by run (`$$`) and
leave them; the restore drill's seed is the only fixture that stays in
the shared database, so it now runs after every step that expects to
find only its own rows there — before C5 it ran between the flag race
and the payment checks, with a comment saying it ran last. The lifecycle
and archive drills work in databases of their own, and archive reads the
empty project lifecycle leaves behind, so those two stay last in that
order. The lint holds the order and, for every script the job runs,
that it names its rows by run, removes them, creates its own database,
or writes nothing.

**Parallelism.** `flutter test` already runs one test process per core
(`--concurrency` defaults to the core count; `ubuntu-latest` has four),
with the file as the unit; nothing here changes it. `supabase test db`
offers no parallel option through the pinned CLI, and the pgTAP step is
363 s of a database job that runs beside the code job (558 s against
1 527 s): shortening it would not shorten a pull request. No parallelism
was added, and no number is claimed for any.

Nothing in C5 is a speedup and none is claimed: the composite runs the
same `supabase start`, the reorder moves a step without removing one,
and C5a ADDS a build_runner step to the critical-path job. The sample
that says what all of it costs, taken with a script that no longer
counts a cancelled job, is C5b.

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
