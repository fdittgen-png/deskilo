# Local → cloud handover — 2026-10-31
<!-- dated: 2026-10-31 — exact operational snapshot; re-read live PR state before acting -->

Repository: https://github.com/fdittgen-png/deskilo.git  
Local identity: **a2** (this Mac session). Cloud identity: **cloud-codex**, workspace `/workspace/deskilo`.  
Application integration snapshot: `23357c57cdee536d3bb084db7bcd91b30fafb7fc`, default branch **master**.  
Candidate: **dce8100fa20290d30d6ed70ecd5da9734429d022**, **[PR #3178](https://github.com/fdittgen-png/deskilo/pull/3178)**. Snapshot is not a deployment or a new implementation authorization.
Immutable transfer tag: **handover/cloud-2026-10-31**. The handover commit SHA is supplied with the transfer message; a file cannot contain its own commit hash.

## 1. Current owner instruction

**DRAIN ONLY is active.** The owner's later instruction, “stop taking new issues and finish all current tasks (including committing, pushing, merging) until no open PR and branch (except main) is left,” supersedes the earlier implement-the-queue instruction. The actual default is `master`. The owner subsequently explicitly answered **“Keep the production deployment branch”**, so `hosting/godaddy` is retained.

Finish the already-prepared #3092 implementation, exact-head review and CI, merge it if approved/green, drain its generated dictionary followup, preserve the parked work and communication history, then prune obsolete worktrees/branches. #3091/#3175 and #3176/#3177 already finished. Cloud may perform the bounded review below; it may **not take new implementation work**. Existing queue order is historical while drain is active. Owner-message references are this session transcript (no public message URL available: **UNKNOWN**); e1's drain acknowledgement is 2026-10-31T21:22Z in the Mac inbox, transcribed in this handover. No new issue or release has been authorized.

## 2. Authoritative checkout and integration state

Integration authority is **GitHub master**, not a stale local directory. Common local repository: `/Users/floriandittgen/orgcowrk`, origin `https://github.com/fdittgen-png/deskilo.git`. It is detached at `c352b2cf3e407e7b93e5fa802d5c9466dc96f933`, intentionally not a coding base. Its observed status:
```
 M .claude/settings.json
 M .mcp.json
 M supabase/.temp/cli-latest
?? .agent-work/
?? prs.json
?? snapshots.jsonl
```
These local configuration/state files are preserved, not copied wholesale to Git. Private contents have not been included.

The active implementation checkout is `/private/tmp/deskilo-3092-push-auth`, branch `fix/3092-push-trigger-auth`, HEAD **dce8100fa20290d30d6ed70ecd5da9734429d022**, status **clean (git status --short produced no output after commit/push)**. It contains master `23357c57cdee536d3bb084db7bcd91b30fafb7fc` via one conflict-free merge. Cloud should read/check out the exact candidate in its own environment, never use the Mac root's detached HEAD as a base.

## 3. Ownership, active claims and locks

| Session | Issue/checkpoint | Branch / HEAD | PR | Status | Blocker |
|---|---|---|---|---|---|
| a2, local | #3092 code, drain and cleanup | fix/3092-push-trigger-auth / dce8100fa20290d30d6ed70ecd5da9734429d022 | [PR #3178](https://github.com/fdittgen-png/deskilo/pull/3178) | OPEN, ready for review; CI running at 2026-10-31T22:05Z | exact-head e1 review and required CI; operator rollout separately blocked |
| e1, local | formal #3092 review, closure decision; queue keeper | no coding branch claimed; target dce8100fa20290d30d6ed70ecd5da9734429d022 | [PR #3178](https://github.com/fdittgen-png/deskilo/pull/3178) | pending review request/response | candidate publication/checks |
| gate, local | merge/branch hygiene; reviews e1's own work if needed | no active coding claim confirmed | none | coordination only | none known |
| cloud-codex | channel setup, then proposed read-only #3092 audit | coord/cloud-codex (communication only); source target dce8100fa20290d30d6ed70ecd5da9734429d022 | [PR #3178](https://github.com/fdittgen-png/deskilo/pull/3178) | no implementation claim | no SDK; does not block connector-based review |
| perf | none | none active | none | stopped by owner | no new work |
| outgoing Claude a2 | none | handover complete | none | stopped; recurring job 641c5f9c cancelled by owner | none |
| auxiliary local CLI launched at owner request | none | started in docs worktree | none | no task assigned; not another coding slot | current process liveness UNKNOWN |

Completed claim records may still refer to #3091 or #3176; actual merged PRs override stale metadata. No additional active coding claim was confirmed from the current worktree/PR inventory. Root `.agent-work` is Mac-only metadata, not proof of live ownership.

**Reserved by a2 until #3092 merges:** migration lane **0631**, `send-push/*`, `push_delivery_headers`, `notify_pending_event`, `notify_member_note`, `reminder_queue_push`, `reconcile_reminder_attempts`, new pgTAP 321, `supabase/APPLIED.sha256`, `assets/instance/{bundle.json,contract.txt}`, `lib/core/instance/schema_compatibility.dart`, and the changed push guides/help outputs. Cloud review is read-only. No second coding slot is released during drain. No independent shared-file lock was confirmed; absence of a live lock service is **UNKNOWN**, so these explicit reservations govern.

## 4. First cloud checkpoint

**Read-only acceptance/security review of #3092 at dce8100fa20290d30d6ed70ecd5da9734429d022.** Local a2 retains the sole active implementation slot, migration lane, fixes, pushing and cleanup; e1 retains formal approval/issue closure. The other potential coding slot stays frozen.

Prerequisites: read this snapshot, [#3092](https://github.com/fdittgen-png/deskilo/issues/3092), the candidate diff and `docs/AGENT_RULES.md` at the candidate. No Flutter installation is necessary for static review. Do not substitute a different SHA.

Acceptance to audit:
1. With a configured secret, missing/wrong/public-key-only or forged-role credentials return 401 before DB/provider work. Exact service credential or paired trigger header is accepted.
2. All three real DB caller paths add the Vault secret; ordinary clients cannot execute/extract the helper.
3. Authorized requests, unknown identifiers and read failures expose the same opaque 202 acceptance, no recipient counts; 403 delegation guard remains.
4. 202 is recorded as **unknown device delivery**, not proof of receipt or a financial/debt transition.
5. **Correction from e1 at 2026-10-31T20:42Z:** while `PUSH_SHARED_SECRET` is unset, preserve legacy delivery with a warning. Do not “fix” this into an installation-wide outage. Actual mocked-provider delivery is tested in that mode.
6. Match replay/pgTAP/contract/bundle evidence to the exact final head; list missing operator proof honestly.

Stop condition: one review response containing exact SHA and either actionable findings with file references or APPROVE, plus explicit NOT RUN/BLOCKED items. Post on the existing candidate PR (and/or the communication inbox while it exists). Do not implement, migrate, deploy, open another issue/branch or move to the next queue item.

## 5. Disposition of the three items

| Item | Final candidate | Disposition / owner of remainder |
|---|---|---|
| #3091 / [PR #3175](https://github.com/fdittgen-png/deskilo/pull/3175) | `7d402e3db18b28c2d03b4078c6d2266ae4b3ab00` | MERGED 2026-10-31T21:35:47Z as `23357c57cdee536d3bb084db7bcd91b30fafb7fc`; issue CLOSED 21:35:48Z. No implementation/review action remains; a2 cleans the old worktree/ref. |
| #3176 / [PR #3177](https://github.com/fdittgen-png/deskilo/pull/3177) | `428daf2576ecc816ce3d127201bd2f6085960c0c` | MERGED 21:33:59Z as `5fff679164aee1cbde04a28f6e59fc559f679c2c`; issue CLOSED 21:34:00Z, milestone v1. Wiki mirror pushed at `b52ce6d73ff6b4d2a8e9bcc0325b672083ddc13f` in the separate wiki repo. a2 cleans obsolete source branch. |
| #3092 | dce8100fa20290d30d6ed70ecd5da9734429d022 | OPEN, ready for review; CI running at 2026-10-31T22:05Z. Local a2 owns code/CI corrections; e1 formal review/closure. Operator owns secret provisioning and deployment, not transferred to cloud. |

CI guide: https://github.com/fdittgen-png/deskilo/wiki/CI-and-Automation ; canonical source `docs/wiki/CI-and-Automation.md` on master.

## 6. Mac-only implementation and Git transfer

All useful #3092 implementation is published at **dce8100fa20290d30d6ed70ecd5da9734429d022** on the existing branch; **clean (git status --short produced no output after commit/push)**. History above master, in order:
- `1f18ddb5366794d7cef8f1343385df3fe2af0d5e` caller boundary/opaque response (initial unset-secret behavior superseded below).
- `13ba59df614a70bcfc866813a77217748db610d7` restore approved legacy compatibility.
- `1be673d5fd1682c217acfd5c6b77e62f0c7b08ab` pairing/acceptance documentation.
- `b04ba83b60736a9f15fa5347372f5691e199894f` test invariant headers and instance bundle.
- `cad9fcaf6b47e3a52cc314b35c8014a03b81948d` unknown-ID/read-failure boundary tests.
- `5eb6204dbf6e64fb48a117ceeef971d38842edd4` merge current master once.
- **dce8100fa20290d30d6ed70ecd5da9734429d022** migration 0631, fixture 321 and final generated metadata.

Previously untracked required files are now included:
`supabase/migrations/0631_push_trigger_authentication.sql` (SHA-256 `ab8257a7582387c42b55708571414e035daaf66a52dcf7723b41f206871533ea`);
`supabase/tests/database/321_push_trigger_authentication.sql` (SHA-256 `8a356dac009d00c2447ab720b62123c431881f424c166ebab526b2bfc508129e`).
Synthetic test credentials/addresses in fixtures are test data. No live secret is included. Root private configuration and transient build/package caches are not implementation prerequisites and must not be copied. Scratch probes under `/private/tmp/3092-*` are reproducible from the committed fixture/migration; normal CI needs neither those scratch files nor Mac paths.

Use GitHub connector file/diff reads at the exact SHA or fetch the existing branch into the cloud checkout. Do not create a parallel implementation branch. After merge, use the squash commit/master, not the deleted feature ref. This handover and review exports live on the communication-only history/tag, which must **never merge into application source**.

## 7. Verification: candidates, commands and limits

See [evidence/verification.md](evidence/verification.md) for the preserved command/exit receipt. No local observation is represented as a clean replay or a deployment.

- #3175 final head `7d402e3db18b28c2d03b4078c6d2266ae4b3ab00`: [quality run 41242506464](https://github.com/fdittgen-png/deskilo/actions/runs/41242506464), all required checks green. [Artifacts on that run](https://github.com/fdittgen-png/deskilo/actions/runs/41242506464#artifacts): `quality-code-attempt-1`, `quality-database-attempt-1`, `quality-report-attempt-1`, `quality-classification-attempt-1`, `quality-timings-attempt-1`, `testshard-gate-attempt-1`, `testshard-money-attempt-1`, `testshard-workspace-attempt-1`, `testshard-rest-attempt-1`. Individual numeric artifact IDs **UNKNOWN**; the run is authoritative. Local full analysis exit 0; lint/recorder 679 pass exit 0; setup import contract 13 pass exit 0; badge Deno guard 3 pass exit 0. Earlier broad affected run 1070 pass / one existing local integration skip, exit 0.
- #3177 final head `428daf2576ecc816ce3d127201bd2f6085960c0c`: [quality run 41242625613](https://github.com/fdittgen-png/deskilo/actions/runs/41242625613), required checks green. Local guarded lint/help 723 pass, exit 0. Artifact names/IDs not independently enumerated: **UNKNOWN**, inspect run artifacts.
- #3092 **dce8100fa20290d30d6ed70ecd5da9734429d022**: Deno 28 pass, original exit 0; full Dart analysis exit 0; final lint/help **701 passed, original exit 0**. Contract prediction apply exit 0, five complete routines. Readiness check exit 0 (READY, DB PENDING_CI_EVIDENCE). New DB 13 assertions and existing reminder-evidence 20 assertions have failed=0 on applied dev definitions; the probes deliberately RAISE to roll back, so connector returns **isError=true**, not a shell exit 0. **[Quality run 41246398626](https://github.com/fdittgen-png/deskilo/actions/runs/41246398626) is in progress at this snapshot; clean replay/artifacts and required-check conclusions are PENDING, not PASS. [Edge typecheck run 41246398606](https://github.com/fdittgen-png/deskilo/actions/runs/41246398606) is also running; workflow publication name does not establish a deployment**.
- Historical #3175 head `684ab4dd2`, [run 41239861573](https://github.com/fdittgen-png/deskilo/actions/runs/41239861573), FAILED; superseded, not evidence for the final head. Fixes included recorder vocabulary, setup import map, service-claim isolation, safe crypt instrumentation and owner-only event visibility.
- Historical #3092 lint/help original exit **1**, 700 pass / one failure: migration 0631 omitted four explicit revokes. Corrected in place before first push, dev re-applied, APPLIED/bundle refreshed. Earlier two test-header/bundle failures were also fixed; their partial green followup is not final whole-tree evidence.
- Any later source change invalidates affected evidence; approvals are SHA-bound. Old #3092 pre-merge or pre-0631 results do not prove the final replay. Initial fail-closed/no-secret tests were superseded by the explicit compatibility correction.
- Generated status: reviewed guide/wiki/help/site outputs; APPLIED and bundle through 0631; marker requiredSchemaVersion=631; contract updates exactly five routines. No model annotations changed, so build_runner was not implicated. Preflight selected help/APPLIED/bundle/l10n audit/capability evidence; the latter two ran exit 0 and produced no retained source diff. Initial guide generator original exit records **UNKNOWN** in this snapshot; final drift gates/CI remain the verification, not a guessed exit.

## 8. Review

Formal reviewer **e1**. Exported verbatim, secret-free review records are [reviews/3175.md](reviews/3175.md) and [reviews/3177.md](reviews/3177.md). #3175's first content review targeted `684ab4dd2`; its final re-verification targets `7d402e3db` (full SHA in §5), APPROVE. Nonblocking trade-off: a cloned real badge can repeatedly trigger the workspace-wide pause; owner alert and automatic window recovery are the accepted design. #3177 APPROVE targets `428daf257` (full SHA in §5).

#3092 formal verdict at dce8100fa20290d30d6ed70ecd5da9734429d022: **PENDING / UNKNOWN until e1 records it**. Cloud's bounded review supplements e1's review. No unresolved #3092 reviewer finding has yet been received at this snapshot. Code approval must not be confused with the missing operator rollout. Any new verdict should be posted on the existing PR so it survives Mac exchange cleanup.

## 9. Toolchain and setup

Verified local: Flutter **3.47.5** (`.flutter-version`), bundled Dart **3.13.4 stable**, Deno **2.9.7**, Supabase CLI **2.120.0**. CI quality/dictionary pin Supabase CLI **2.118.0**; Edge CI uses Deno **v2.x**. Local Xcode **26.6 / 17F113**. SDK location `/Users/floriandittgen/development/flutter`; Android SDK `/Users/floriandittgen/android-toolchain/sdk`. psql is absent from local PATH. Python3/Git/bash and Docker CLI exist; local Docker daemon availability **UNKNOWN**.

Cloud reports Flutter/Dart absent, packages unresolved, readiness fails immediately; original cloud exit code **UNKNOWN**. Docker works by cloud report; local Supabase CLI/psql/Deno and native toolchains absent there.

Reproduce in the cloud only if needed for the authorized review:
1. Install the exact Flutter 3.47.5 SDK for Linux; use its bundled Dart on PATH. Do not upgrade implicitly.
2. `python3 scripts/worktree_prepare.py --resolve --database-ci` initializes **each independent package** with enforced tracked lockfiles. Root pub get alone is insufficient. Packages: root; `deskilo_asset_gzip`, `deskilo_document_editor`, `deskilo_document_model`, `deskilo_document_pdf`, `deskilo_push`, `deskilo_push_foss`, `deskilo_task_recording` under `packages/`. Never symlink another checkout's package_config.
3. `dart run tool/preflight.dart --base origin/master --list`; run only implicated generators **serially, waiting for each exit**, then `dart analyze --fatal-infos`, lint and affected tests. Full suite is CI-only. On this Mac all Flutter tests use `~/.deskilo-exchange/tools/guarded-flutter-test.sh`, max three workers/memory guard. That Mac-only guard is not a Linux prerequisite.
4. Deno: `deno test --allow-env supabase/functions/send-push`. Docker + pinned Supabase CLI + PostgreSQL client tools are needed for local clean replay; use the existing quality job instead when absent. Read `.github/actions/local-stack/action.yml` and `quality.yml`, not a guessed replay reset command.

Known setup failures: sandboxed local Flutter cache access caused readiness exit **2** (nested flutter exit 1); outside-sandbox retry exited 0, READY. Concurrent Dart native-asset preparation can race `objective_c.dylib` codesigning/install_name_tool: fixed by serial generators. No dependency upgrade is needed.

Download/service hosts required by the relevant tooling: `github.com`, `api.github.com` and GitHub release/asset redirects; `pub.dev`; `storage.googleapis.com` (Flutter/Dart artifacts); `ghcr.io` (authenticated Supabase CI images); Deno dependency hosts `jsr.io` / `registry.npmjs.org` when imported. Exact redirect/CDN allowlist and cloud network-policy permissions are **UNKNOWN**; confirm actual install output. The user reports shell gh blocked in cloud but connectors work; no shell authorization is inferred.

## 10. Database integration

Only authorized hosted dev target: **coworking-staging**, project **zwzbynivewivvjmripeb**, eu-central-1, observed ACTIVE_HEALTHY. Do not infer the target from its human name alone. Current authoritative SQL marker `select public.deskilo_schema_version()`: **631**. Master at this snapshot contains **630**; candidate 0631 is **applied to dev but not yet merged**. Its exact file hash is in §6 and `supabase/APPLIED.sha256`. a2 owns the migration lane/reservation in Mac `migrations.md`; cloud has no migration reservation.

0631 adds Vault header helper and replaces all three caller paths plus reminder reconciliation; schema marker, contract and bundle all follow it. It was re-applied before first push to include explicit service-only privilege statements. Vault `deskilo_push_shared_secret` remains **absent**; clients anon/authenticated cannot execute the helper. Test secrets were rolled back.

Earlier dev audit history includes a temporary badge visibility 0631 application that was consolidated into corrected **unmerged 0630** under e1's explicit 21:03Z ruling; it is not a second source migration. 0629 was kept byte-identical; merged 0630 maps badge_security_alert to workspaceSettings, kiosk-only sees zero alerts. Migration audit row counts/names are not the schema version. No evidence of a remaining badge visibility discrepancy was observed after final correction.

Required for #3092 completion: exact-head clean migration replay; complete pgTAP incl. 321 and existing 120; contract/policy comparison; lifecycle/version marker; APPLIED digest and instance bundle drift; all required quality checks. The dev rolled-back probes are useful preflight, **not substitutes for CI replay**. No production database state was inspected or changed; production version **UNKNOWN**. Existing #3095 dev housekeeping (empty staging table drop; public Deskilo bucket 50 MiB zip/png/ico limits) was reported by the outgoing session; source parity/replay representation of that historical housekeeping **UNKNOWN**, not part of cloud's #3092 checkpoint.

## 11. External capabilities and missing setup

For the cloud review, GitHub connector and dev Supabase read capability are available by the user's cloud-session report. Local authenticated gh and Supabase connector/CLI work. Credentials must stay in their existing stores, never the handover.

Dev Edge secret **names only**, observed via CLI: `DESKILO_INSTALLATION_ID`, `DESKILO_MCP_ALLOWED_ORIGINS`, `DESKILO_MCP_EPOCH`, `DESKILO_MCP_RESOURCE`, `SUPABASE_ANON_KEY`, `SUPABASE_DB_URL`, `SUPABASE_JWKS`, `SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL`. **PUSH_SHARED_SECRET and FCM_SERVICE_ACCOUNT were absent** from that list; Vault pairing secret absent as above. Secret values/digests not exported.

Dev `send-push` observed ACTIVE, version 5, gateway `verify_jwt=true`; deployed source SHA **UNKNOWN**. Candidate code is **not deployed**. Permitted named dev endpoint: `https://zwzbynivewivvjmripeb.supabase.co/functions/v1/send-push`; no real-recipient/provider send authorized for this review. Tests use mocked transport and synthetic fixture endpoints.

OAuth: push uses service-account token exchange at `https://oauth2.googleapis.com/token`, scope `https://www.googleapis.com/auth/firebase.messaging`, then `https://fcm.googleapis.com/v1/projects/<provider-project>/messages:send`. Interactive OAuth client/callback is not required for this checkpoint. Configured Firebase project, service-account location, APNs/client credentials, sandbox recipient devices and production callback inventory: **UNKNOWN**. Provider operator / Firebase and Supabase administrator must supply missing configuration.

Operator rollout remains: provision Vault `deskilo_push_shared_secret` first, pair Edge `PUSH_SHARED_SECRET`, deploy the reviewed function with gateway verification retained, then verify refusal + trigger delivery using an explicitly permitted test recipient. Configure FCM_SERVICE_ACCOUNT/client Firebase/APNs as needed. Do not enable fail-closed without pairing or claim an unset installation secured.

GitHub repository-level credential names observed include Android/F-Droid signing groups, App Store Connect API group, MATCH_DEPLOY_KEY/MATCH_PASSWORD, PLAY_STORE_SERVICE_ACCOUNT_JSON and BETA_CONTACT_PHONE. Their validity and org/environment secret availability are **UNKNOWN**; none is needed for read-only review. No production credential or certificate was retrieved.

## 12. Integration and device locations

P/W-A/W-B topology is reproducible **ephemeral CI**, not an always-running hosted test estate. Definitions: `scripts/topology_stacks.sh` and `.github/workflows/quality.yml`. W-A is the ordinary repo local stack (API 54321, DB 54322); P uses API 54421/DB 54422; W-B API 54521/DB 54522. P/W-B directories are runner temp `deskilo-topology/p` and `.../wb`. Generated topology.json contains local test keys: do not export it.

Tests: `test/topology/{three_stacks,invoice_preview_http,invoice_receipt_http,topology_faults,personal_directory}_test.dart`. Valid existing topology/database evidence is #3175 quality run 41242506464, **not #3092 replay evidence**.

Cloud can read CI artifacts/source now, run Deno after setup, and run Linux/Docker integration only after the required tooling/network is available. It cannot execute Apple native tests there. Available CI definitions: `android-boot.yml` (Ubuntu), `macos-app.yml` (macos-15), `ios-testflight.yml` (macos-15; publishing is separate). Historical Android boot [41211464408](https://github.com/fdittgen-png/deskilo/actions/runs/41211464408) succeeded at master `e59faed49d6ce8a8835ab60debaf1d2e2b8520df`; it does not verify #3092's new head.

Local adb inventory returned **no attached Android devices** (exit 0) at this snapshot. Android SDK and Xcode exist; available emulator/simulator inventory **UNKNOWN**. Physical iPhone availability **UNKNOWN**. Browser installation/authenticated session and cloud browser runtime **UNKNOWN**. No #3092 real-device delivery proof exists. Native notification permission, actual receipt/background behavior and provider-dashboard actions require a local/device operator or human participant with a permitted test device. None blocks the proposed static review; missing proof stays NOT RUN.

## 13. Coordination after transfer

`coord/cloud-codex` currently exists, communication only. It will be archived then deleted during drain, consistent with the owner branch policy. **Surviving Git-readable location:** immutable tag `handover/cloud-2026-10-31`, file `LOCAL-TO-CLOUD-HANDOVER.md`, copied `reviews/` and `evidence/`. Final channel history will also be tagged `archive/drain-2026-10-31/cloud-exchange` before deletion. Do not recreate the branch after cleanup.

While branch exists: append UTC messages to `to-a2.md` / `to-cloud-codex.md`, identities a2/cloud-codex; edit only own status; normal push, no force push, no merging into app source. Messages carry issue/PR + full SHA + evidence and ACK/request IDs. After branch deletion, use **existing #3092 PR/issue comments** as the surviving two-way channel, referencing the exact candidate or merge SHA. Do not put private logs/secrets there.

Local **a2 relays** relevant cloud requests into `/Users/floriandittgen/.deskilo-exchange/to-e1.md` (formal review/queue), `to-gate.md` (hygiene), and reads `to-a2.md`. e1 writes `reviews/<PR>.md` and closure decisions. Cowork screen requests go through e1 to `to-cowork.md`, replies in `to-e1.md`. The cloud cannot read those Mac paths. a2 can relay while active; after drain, read/relay resumes only when a session is prompted. **No watcher is assumed, armed or restarted; no recurring jobs are created.** A Git update does not wake an idle chat.

## 14. Branch, release and operating constraints

- Default **master**; keep protected **hosting/godaddy** at remote `0c83196a242697d95bdfd143ca88e1c0adbb66ea`. `godaddy-site.yml` explicitly says protected/must be kept. Do not merge this generated deployment history into app source or trigger production deployment.
- a2 owns remaining cleanup. Parked `chore/2121-stable-baseline` tip `2156a29ba0f5c85e3ad24a7bf2bf4182f742c736` was preserved in remote annotated tag `archive/drain-2026-10-31/code-health-baseline`; do not revive it. Dictionary working branch is regenerated by workflow on master/nightly: drain the latest post-0631 version once, then delete it when idle. Its scheduled workflow may recreate a branch later; no permanent no-branch guarantee is possible without changing automation, which is not authorized here.
- Existing merged feature/review refs are cleanup remnants, not active work. Preserve uncommitted root configuration. Remove only own clean merged worktrees; do not reset another session's edits.
- e1 formal reviews/closure; green required checks on exact head, normal merge only, never --admin bypass. PR cap historically ≤4 total across lanes including drafts; current drain is stricter (no new intake). A changed head requires re-verification.
- One registry writer, one active migration lane; master migrations immutable. One master merge into an implementation branch, no iterative rebase churn. Claim/check collisions before editing.
- No full local test suite; guarded Mac tests. All strings five locales; no unrelated formatting/ratchet relaxation. Follow repository rules at candidate.
- No automatic release, production writes, permission changes, secret/certificate provisioning or provider purchases. General “do it” authorization does not bypass platform approvals or make missing credentials available. TestFlight/Play publication is not implied. Never use Play track alpha1; existing closed test track is alpha.
- Paused: all new implementation including #3094, #3069, #2488 and the remaining v1/perf/UX/code-health queue; #2560/new projects; provider-dependent #2470/#2371/#2372/#2374, #2377 and #3159; people/device gates #1285/#1447/#1974/#2874/#2581; destructive #3141 until supported-build decision. Exact live status of every historical skip item **UNKNOWN**; none is assigned to cloud by this handover.

## Proposed working agreement

- **Local session retains:** #3092 implementation/fixes, sole coding slot, dev migration lane 0631, PR/CI drain, generated dictionary followup, branch/worktree cleanup and Mac relaying. e1 retains formal review and issue closure; gate coordinates hygiene.
- **Cloud session takes:** one read-only acceptance/security/evidence review at **dce8100fa20290d30d6ed70ecd5da9734429d022**, then reports findings or APPROVE and stops. No new implementation claim.
- **Transfer location and exact SHA:** application **dce8100fa20290d30d6ed70ecd5da9734429d022**, **[PR #3178](https://github.com/fdittgen-png/deskilo/pull/3178)**; handover at immutable tag **handover/cloud-2026-10-31**, whose exact Git commit is in the accompanying transfer message. Source and communication histories are separate.
- **Shared contracts/files reserved:** the #3092 callers/reconciler/header helper, 0631/321, contract/APPLIED/bundle/schema marker and related guide outputs, all a2-owned until merge.
- **Required verification before completion:** exact-head e1 review and three required contexts; clean replay/pgTAP/contract/lifecycle/bundle; all actual exit receipts; operator rollout separately reported BLOCKED until paired/deployed/tested.
- **External blockers and responsible role:** SDK/network setup — cloud environment operator if runtime review desired; shared secret/FCM/APNs/test recipient/deployment — provider/Supabase administrator and device operator; production actions require explicit scoped authorization.
- **Coordination channel:** existing PR/issue #3092 comments, with temporary coord inbox exchange while the branch exists; local a2 relays to e1/gate; immutable handover/archive tags survive cleanup. No watcher/job.
- **Work that remains paused:** all new issue intake, second coding slot, production release/deployment and credential/device-dependent followups. Resume only on a later owner instruction.

