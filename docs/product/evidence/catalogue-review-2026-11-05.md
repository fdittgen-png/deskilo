# Catalogue evidence reconciliation — 5 November 2026

This review reconciles the [source catalogue](../capabilities.json) with the
application and retained evidence at
[`d058068d8ae7cb7d1dff8a2f421fec0a6463e4e2`](https://github.com/fdittgen-png/deskilo/commit/d058068d8ae7cb7d1dff8a2f421fec0a6463e4e2).
It records what each result establishes and its limits. It adds no provider,
current-runtime or device qualification and changes no feature maturity.

## Current automated evidence

[Quality run 41975986042](https://github.com/fdittgen-png/deskilo/actions/runs/41975986042)
completed successfully on that exact source, including the
[report job 127082297297](https://github.com/fdittgen-png/deskilo/actions/runs/41975986042/job/127082297297).
The [workflow](../../../.github/workflows/quality.yml) and
[quality manifest](../../../.github/quality-manifest.psv) define the checks.
A green run proves the invoked checks; it does not turn optional rehearsals or
older operator observations into current-run results.

## Recovery: two different exercises

The CI **Restore drill** calls [restore_check.sh](../../../scripts/restore_check.sh)
without `--application`: a public/auth database dump is restored into a fresh
database, counts and tenant separation are checked, financial reconciliation
passes, and deliberate damage is detected. That invocation does not restore
Storage objects or exercise the Auth service and app together.

The opt-in `--application` mode calls
[application.py](../../../scripts/recovery/application.py). Its
[native recovery test](../../../test/core/instance/local_recovery_test.dart)
skips without `DESKILO_RECOVERY_FIXTURE`; the ordinary always-run evidence is
the [guard test](../../../test/tool/local_recovery_guards_test.dart).

The [3 November report](../../testing/evidence/pilot-recovery-2026-11-03.json)
records `ready` on disposable local source/target stacks, schema **664**, with
**38 database assertions**, registered users, native exports, database and
private-object restore, target Auth and app reads, and object-damage detection.
The [pilot ledger](../../testing/PILOT_JOURNEY_EVIDENCE.md#candidate-re-run--3-november-2026-1974)
identifies the tested source as
[`a6c9aa7d8ea61dd639f806a5a6171b70f652f3df`](https://github.com/fdittgen-png/deskilo/commit/a6c9aa7d8ea61dd639f806a5a6171b70f652f3df);
the JSON report itself has no candidate-SHA field.

This historical pass excludes hosted recovery, email delivery and MCP.
Raw Unicode Storage keys are unsupported. Synthetic accounts and identities
are restored; active sessions, refresh tokens, MFA/OAuth configuration and
external credentials are excluded. Target installation and MCP configuration
are retained. The pass is not a rehearsal of the current source.

## Existing-community pilot: accepted with recorded gaps

The owner [accepted and closed #1974 on 3 November](https://github.com/fdittgen-png/deskilo/issues/1974#issuecomment-6614729953).
Its [ledger](../../testing/PILOT_JOURNEY_EVIDENCE.md) explicitly combines different
trees: Dart runs used `351af01a6` plus branch changes; the strict preview decoder
and recovery used `a6c9aa7d8`; database runs used schema 664. These results must
not be collapsed into one current-candidate qualification.

The operator's six-step TalkBack walk passed on a Galaxy S23 Ultra / Android 16,
but the app version was not recorded. The two Edge windows passed live update,
conflict refusal, reload and reconnect using **the same account**. A separate
owner/member browser pair and iPhone/VoiceOver were not run. The effective pilot
profile was maintainer-derived, statement-to-handoff agreement remained partial,
and hosted restore/email were not exercised; named checks were not rerun.
Closure records acceptance of those gaps, not their removal.

## Setup guide: the newcomer study was waived

The owner [closed #2874 on 3 November](https://github.com/fdittgen-png/deskilo/issues/2874#issuecomment-6607410948)
with the five newcomer sessions and their evidence document **NOT RUN, waived**.
The accepted decision keeps `setupGuide` at beta; scripted step timings remain
estimates. The [screen journey](../../../test/ux/first_booking_journey_test.dart),
[member path](../../../test/features/workspace/setup_member_path_test.dart) and
[authenticated database journey](../../../supabase/tests/database/345_first_booking_clean_journey.sql)
are distinct proofs, not five unassisted newcomer sessions.

## WebMCP: retain the two browser runs separately

The [public-page run](https://github.com/fdittgen-png/deskilo/issues/2500#issuecomment-6598232631)
on 3 November used **Edge 156.0.4314.58**, the WebMCP flag and pages served locally
from **`1194197ec`**. It exercised setup, product and guide tools.

The [signed-in app run](https://github.com/fdittgen-png/deskilo/issues/2500#issuecomment-6598345387)
on the same date used the published web app in **Edge 156**, WebMCP flag on:
24 tools registered after the device switch was enabled, and reads and refusals
passed. **No writes were performed; the published app SHA/version was not
recorded.** The public-page SHA must not be assigned to that app run.
Confirmed writes remain covered by the
[wiring tests](../../../test/app/webmcp_wiring_test.dart) and
[confirmation tests](../../../test/app/webmcp_confirmation_sheet_test.dart).
`get_availability` is intentionally not offered. The epic was closed with
these decisions; neither browser observation qualifies current app writes.

## Personal/workspace separation: local proof, wider acceptance open

[Physical topology](../../../scripts/topology_stacks.sh) runs three separate
local stacks with seeded identities. Its
[HTTP/readback cases](../../../test/topology/three_stacks_test.dart) and
[fault cases](../../../test/topology/topology_faults_test.dart) prove named
boundaries, personal-session continuity, workspace outages and stale-response
refusals. [#2560](https://github.com/fdittgen-png/deskilo/issues/2560) still carries
the wider personal rework acceptance: those fixtures do not prove complete
one-registration onboarding, external identity-provider handoff or all native
platform journeys.

Historical observations in this note remain prose evidence with their actual
candidate limits. They supply no invented manifest scope, outcome fingerprint
or current-release pass.
