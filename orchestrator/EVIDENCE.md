# Evidence register

Snapshot references are durable. Live status must be refreshed from GitHub.

## Completed checkpoint 3250

- Issue #2519; PR [#3250](https://github.com/fdittgen-png/deskilo/pull/3250).
- Approved head: `be1f64ec2c936102858a8d846545194c892f6fae`.
- Merged 2026-11-02 09:19:50 UTC as `246e9a55e6da987bab5246c7bd4998567c3fbc37`.
- Net change: reasons documentation and zero-unjustified-default ratchet. No runtime/default/schema change. Demo N/A.
- Exact-candidate receipt: preflight-selected tools exit 0, generated diff unchanged, analyzer exit 0, guarded lint exit 0 with 692 tests, diff check exit 0.
- [Quality run 41417491528 attempt 1](https://github.com/fdittgen-png/deskilo/actions/runs/41417491528) SUCCESS. Reviewer reports three required checks successful and exact-head merge arming.
- Local review: `~/.deskilo-exchange/reviews/3250.md`; local lint: `/tmp/deskilo-2519-r3-lint.log`.
- E2 owned branch/worktree removed, remote branch absent, claim archived. Epic #2519 remains open; do not infer all epic acceptance from this leaf checkpoint.

## HMRC proof and corrected candidate

PR [#3251](https://github.com/fdittgen-png/deskilo/pull/3251), issue #2470.

| Candidate | Evidence and limits |
| --- | --- |
| `06ef97302d32fa4d7b037f0e2029da8e4c18a10c` | Draft proof head; [run 41418089707 attempt 1](https://github.com/fdittgen-png/deskilo/actions/runs/41418089707), database job 125187066177. Replay and pgTAP 338 passed, all 6,449 pgTAP assertions passed, actual HMRC first/delayed/rollback races passed. Overall Quality FAILED on pending Effective contract. A separately reproduced refresh-failure UI defect prevents approval of this head. |
| `62e055307b1b61e97b468a84d869a5e3b40698a3` | Corrects UI acknowledgement reset and regression. Compared directly with proof: only hmrc_submit_sheet.dart and its test differ. Analyzer exit 0; guarded lint plus affected tests 732 passed. Database/migration/race inputs unchanged. |
| `84275da130d53696997fcaf385fdc320021a48f7` | Adds genuine APPLIED/contract records only after corrected UI candidate. Reviewer APPROVED exact head; [final run 41420626290 attempt 1](https://github.com/fdittgen-png/deskilo/actions/runs/41420626290) completed SUCCESS, ten jobs successful. Merged 09:42:40 UTC as `189fb73ed13357bc22c399191475a6a412680a61`. Final-head evidence supersedes the earlier pending snapshot, without changing the proof run outcome. |

Migration `0652_hmrc_recovery.sql` SHA-256:
`8a05fb7ecdf2523bb863b1c6031a36921e6ad46e71c342040391334e77d13196`.

Reviewer applied these exact bytes on dev `zwzbynivewivvjmripeb` under transactional guard, original exit 0. Postcheck: schema 652; marker column/v2 present; authenticated denied/service_role allowed. Ledger APPLIED and MERGED after #3251 integration. Pre/post application rollback harnesses intentionally returned HARNESS OK via original exit 1, with independent rollback/state checks. Preserve that distinction.

The contract predictor initially failed to consume the CLI JSON envelope (exit 255). Normalizing its rows and retrying exited 0; final candidate contract matches the proof replay artifact byte for byte. Do not hide the original failure.

Local evidence: `/private/tmp/deskilo-2470-db-ci.log`, `/private/tmp/deskilo-2470-ci-proof/`, reviewer `~/.deskilo-exchange/reviews/3251.md`. Earlier `~/.deskilo-exchange/evidence/2470-recovery-wip/` and the old harness hash `6d26017f...` are historical sequential smoke, not current-candidate proof.

Deno receipt: 21 tests passed. Local full pgTAP/two-session execution was NOT RUN because an isolated local database was unavailable; CI supplied the actual database proof. No real HMRC call or production migration is inferred.

## Current 3070 evidence

**10:59 UTC live reconciliation:** #3252 MERGED at 10:29:22 UTC as `7438b12c5881a348d64f19b3ef9bbfb0b7d26e2c`, approved head `927f49e8eebdbb711ae809fe94d24bc31098cb53`. All five candidate workflows completed SUCCESS, including Quality 41426054668. Reviewer reconciliation COMPLETE: run 41426054668 attempt 1, database job 125213290066, pgTAP 339 OK and all 6,476 PASS. Fresh master `7438b12c5881a348d64f19b3ef9bbfb0b7d26e2c` and dev schema 653; merged migration/APPLIED SHA-256 `018f543347d5847d49237de5c47cdf14575ce52547401eb8efe3dc0e0179733b` matches reviewed dev. Ledger MERGED, tenure RELEASED; #2596 and reviewer CURRENT updated. E2 instructed to clean only owned merged work, archive claim, then prepare a bounded remaining #3070 approvals/count acceptance crosswalk. Parent #3070 remains open. No new implementation branch/migration is assigned yet; incident publication constraints remain unresolved.


**Latest approval receipt:** At 10:08 UTC, reviewer APPROVED exact #3252 head `927f49e8eebdbb711ae809fe94d24bc31098cb53`; E1 independently reviewed the same head without actionable findings. Exact-head squash auto-merge is armed, with no bypass. GitHub still reports OPEN/unmerged; Quality 41426054668 and Web checks are running, three schema workflows succeeded. Required final CI and true pgTAP remain pending; 0653 tenure stays held until verified merge. #3070 remains open for approvals/count and other residual scope. Local receipt: `~/.deskilo-exchange/reviews/3252.md`. E1 review 10:05:55–10:07:30 UTC, no duplicate tests. Earlier review-pending statements below are historical.

**10:07 UTC update:** PR [#3252](https://github.com/fdittgen-png/deskilo/pull/3252) verified OPEN/non-draft at `927f49e8eebdbb711ae809fe94d24bc31098cb53`. E2 reports analyzer exit 0 and 745 guarded tests passed on candidate; [Quality run 41426054668](https://github.com/fdittgen-png/deskilo/actions/runs/41426054668) and other workflows still in progress. Real pgTAP/final CI and exact-head review pending. E1 assigned independent review; reviewer retains merge/ledger ownership. #3070 remains open for residual scope. The following 09:53 snapshot is historical and superseded for candidate readiness, not proof of final CI.

At 09:53 UTC, reviewer ledger records 0653 APPLIED on dev at 09:51:38, reviewed SQL head `70eaf2d187602ce724bde906347b0401debae5c2`, SHA-256 `018f543347d5847d49237de5c47cdf14575ce52547401eb8efe3dc0e0179733b`. E2 reports rolled-back harness `HARNESS_RESULTS count=27 failures=none`, including 2,007 distinct paged rows and roles/tenant/feature/balance cases; original numeric exit is not yet copied into this Git receipt (UNKNOWN here). Independent post-rollback schema was 652 and function absent; reviewer post-apply reports 653, both RPCs present, anon denied. APPLIED/contract source integration, full candidate pgTAP/CI, Demo and final review still pending. Last E2 local head `a683e3772d0fbd3c0162098ec2f1f586ebbb91fb`; SQL bytes unchanged from reviewed source. Do not treat this report as final-head approval.

E2's decoder/provider/page/fake tests have passed on intermediate read-client candidates. Some fake cases include 2,101-row continuation, separate currencies and partial/settled data. This is not PostgreSQL evidence or an end-to-end Demo journey. Generated localization was previously held unnecessarily; it is now released. Final UI/backend/Demo verification remains outstanding.

## Evidence receipt template

```text
issue/checkpoint | full candidate SHA and tree
implicated generators + original exits | generated diff reviewed
analyze/lint/affected tests + original exits
CI workflow/run/attempt/job/artifact + exact source/input hashes
database target/schema/migration hash and rollback/application distinction
reviewed SHA/reviewer | merge SHA/time
NOT RUN/BLOCKED + precise reason | remaining owner and next action
```

A test count is not a measure of complete acceptance. Preserve failing regressions, denied-role proofs, concurrency assertions, original exits and source/input provenance. Do not copy secrets or raw auth records into this branch.

## Private approver-read candidate — 11:20 UTC

Private local candidate `fa5445801737f6a992a7109e54fea682cdbdb3ea`, clean, in `/private/tmp/deskilo-3070-approver-reads`, branch `feat/3070-approver-reads`. 0654 exclusively RESERVED, NOT APPLIED, SHA-256 `8dee1ebe3218d9a29b5ac3983e202ad25a4a1224d8c6604b3efc5505c15d3cdc`. E2 reports fatal-info analysis passed, 692 lint tests and 54 affected tests passed; Demo actor/threshold 3 and detail retry passed. Original numeric test exits not separately copied here. Migration execution and 25-assertion pgTAP 340 NOT RUN; local Docker/Postgres unavailable. E1 exact-head read-only contract review requested; reviewer assessing established transaction-safe rollback harness route. No persistent dev application, public ref or final merge approval. Genuine APPLIED/contract records and full required CI remain pending.

This is a separate checkpoint after merged #3252; do not reuse its approval as approval of this candidate. First broad lint caught a raw spinner and grant syntax missed by focused checks; corrected, focused 22 passed, then final lint passed. Add state-primitives and migration-grants to affected focused preflight next time. Rerun only invalidated checks; no duplicate rerun requested for current passing gates.

## Failed approver-read rollback proof — reported 11:35 UTC

Reviewed immutable bundle identified as `8d6b6c3` was executed once. Original CLI exit **1**, `HARNESS_ASSERT_FAIL`: equal-count replacement actual **207**, expected **206**. This is a failure, not an intentional success marker. Independent postcheck: dev schema **653**, all new candidate RPCs absent, rollback confirmed. The harness used a custom assertion shim; actual pgTAP 340 and CI remain **NOT RUN**. Full bundle SHA/hash and private log path must be supplied by reviewer receipt before treating this short identifier as exact provenance.

E2 must diagnose the actual eligible-row transition before changing fixture expectations or contract, preserving the failed immutable bundle and original exit. No unchanged blind rerun or expected-count adjustment without cause. Later local E2 HEAD observed `47bf691d7a22a83eb47b344125c09f26fe3f8f6e`, 0654 hash `a4f51b73d1aa339939f4d2e0f7a0adb4f8fea9018625750a137648ed3a0cf1e9`; neither is asserted proven by the failed earlier bundle. Migration 0654 remains reserved and NOT APPLIED; disclosure/scope/stale-action review holds and publication hold remain.

## Receipt reachability correction — unresolved

The prior approvals queue exposed RLS-visible pending receipt detail to existing wide readers, without a receipt decision action or demonstrated event cross-link. A bill-only replacement removes that read entry. Existing Events/Alerts cannot be claimed equivalent or available to all prior viewers: useMessages, eventsTab and event voting eligibility are distinct gates. Earlier statements that unchanged Alerts preserved this behavior are withdrawn; no new receipt voting in this checkpoint does not establish preservation or full parent acceptance.

Actual lost read visibility and the capability-gated alternative remain unresolved #3070 acceptance. Orchestrator requires a bounded preservation of prior read-only receipt reachability for previously authorized readers, using existing access controls, without expanding voting/entitlements or bill-only RPC disclosure. Verify prior-reader reachability and denied-reader behavior; if no minimal preservation route fits, report the concrete conflict before approval. Keeping the parent open alone does not turn this into a non-regression. No fix, application or publication is asserted by this decision.

## Corrected 0654 rollback proof and current evidence reuse

Reviewer receipt at **2026-11-02T11:48:10.493195+00:00**, source `fefc73d708938b6d811d15a17a452c49818deb4e`: migration SHA-256 `a4f51b73d1aa339939f4d2e0f7a0adb4f8fea9018625750a137648ed3a0cf1e9`, fixture `5d0ae581aa2e0cf0f305e4fb6fac6be3c57831afa798cf73cbdefa73a9ce8bfb`, harness `f845eb7ee178fb0fb34bfc65724d34557f3f79054a4f7ce13a9bc469ac940c68`. Original CLI exit **1**, explicit **HARNESS_PASS assertions=48**, intentional rollback. Independent postcheck exit **0**, schema653/all four candidate routines absent. Receipt read from `~/.deskilo-exchange/evidence/3070-0654-receipt-verified/reviewer-receipt.json`. This is custom transactional shim evidence, **not actual pgTAP or CI**. 0654 remains NOT APPLIED.

Earlier failed proof remains failure. Intermediate plan44-vs45 and plan44-vs48 bundles were rejected before execution. Focused diagnosis identified an ineligible row selected for removal; corrected fixture proves eligibility and intermediate 205 count before returning to206.

Reviewer inspected later `c34fb3b4fe00b0aec7819f94afaaf28c135d86d7` receipt UI delta: receipt section renders independently of bill loading/refusal/instability; reported nine focused tests/analyzer pass, not reviewer-rerun. Only screen/test changed from fefc73d; unchanged database inputs retain the ORIGINAL shim proof attribution, not a blanket new-head pass. Full exact-head review, actual pgTAP/CI, genuine applied artifacts and publication remain pending.

## Real pgTAP rollback route — feasibility confirmed

Reviewer executed one bounded feasibility probe through the established linked CLI. Real pgTAP **1.3.3** was installed temporarily inside one transaction; two actual assertions exercised postgres/authenticated roles and finish/num_failed checks. Original CLI exit1 with explicit `FEASIBILITY_PASS pgtap=1.3.3 tests=2 intentional_rollback`; independent postcheck exit0 confirms schema653, pgTAP absent and all four candidate routines absent. Raw marker and postcheck inspected in `~/.deskilo-exchange/evidence/3070-pgtap-feasibility/`.

This proves route feasibility ONLY, not canonical340 or CI. Next: E1 offline generates/validates one faithful immutable canonical340 bundle; reviewer verifies its exact source/migration/fixture/harness hashes and runs one rollback-only proof, validating real TAP/plan/finish/failure results and independent postcheck. Preserve role/session semantics, no custom shim substitution or swallowed exceptions. Do not repeat feasibility, retry Docker, apply0654 or publish a ref. A canonical pass would establish real hosted rollback pgTAP evidence, not isolated full replay/concurrency/final CI.

## Actual canonical340 real pgTAP proof — 11:57 UTC reconciliation

**11:57 UTC verification update:** clean private candidate `c84e6cc3ec1f7e2131c3d72a47384e2058b120a1`. Actual canonical340 **real pgTAP PASS: plan1..51, 51 sequential ok, zero not ok** in one rolled-back linked-dev transaction. Executed bundle SHA-256 `5413b5df26cde07d9e9ac4475333efd084a6b3d7794ea520699dc2dc8112affd`; migration `a4f51b73d1aa339939f4d2e0f7a0adb4f8fea9018625750a137648ed3a0cf1e9`, fixture `724146802a090f8853d09a730753f701f6250ecf67d23c7b443234fb6b8dd369`. Original CLI exit1 with explicit PGTAP_PASS intentional rollback; independent postcheck exit0/schema653, extension and four routines absent. Reviewer receipt inspected at `~/.deskilo-exchange/evidence/3070-pgtap-c84e6c/receipt.json`. This is genuine hosted rollback pgTAP, not isolated full replay, final CI or application. 0654 RESERVED/NOT APPLIED; no public ref. Full final-head review and application/publication prerequisites remain.

Offline helper in `/private/tmp/deskilo-db-proof-tools/` is intentionally fixture-specific, with a fingerprint allowlist and full regeneration/byte comparison; it is not a general SQL parser or SQL safety proof. Reviewer independently inspected shim builder/five tests, real-pgTAP generator/seven tests, then settled hardening/nine tests. The executed real-pgTAP bundle is 5413b5df above. Later unexecuted settled bundle `1a4fd5974c0fb9cd46bae14f399bd9f73a6093e102aa2075b7e70358066f6ca1` adds version1.3.3 and single-plan guards; same migration/fixture/instrumentation, offline verification passed. Existing actual TAP and feasibility receipts cover the observed facts, so no duplicate database run was requested. Never relabel the executed proof as execution of the settled bundle. Shim candidate `316e85ac...` remains a separate unexecuted artifact, not the real-pgTAP receipt.

## Failed master workflows — bounded triage

At master `7438b12c5881a348d64f19b3ef9bbfb0b7d26e2c`, Dictionary41429205871/job125223256424 failed in the step named Migration replay, but actual failure was supabase start binding 0.0.0.0:54322 already in use. GHCR login/pulls succeeded; SQL replay failure is NOT established. Caller is dictionary-refresh.yml -> local-stack composite. Port owner/isolation cause still requires diagnosis before asserting a fix.

Nightly Journey41434774314/job125241749287: 3 pass/8 fail; first failure TaxReferenceUnavailable, later _pumpHub pumpAndSettle timeouts. tool/bench is outside test/flutter_test_config.dart initialization; missing equivalent bundled-reference initialization is the supported hypothesis to reproduce/fix. No performance-budget violation proven. Uploaded perf-journeys artifact does not establish successful benchmark evidence.

**12:10 UTC CI fix assignment:** E1 owns the second bounded local implementation checkpoint: benchmark bundled-tax-reference initialization and diagnosed dictionary stack port/config isolation. Dedicated owned worktree from fresh master; reserved tool/bench initialization/tests, dictionary-refresh.yml and necessary local-stack/config tests only. E2 retains0654/UI/DB aggregate ownership. Reviewer independently reviews both; no new migration or public ref for CI fixes. Benchmark fix reuses existing initializer, not increased timeouts/budgets. Port fix must establish ownership/config cause and preserve DB_URL/topology consumers; no arbitrary kills, guessed-port guarantee or migration edits.

## 0654 development application and live proof — 12:13 UTC

**0654 APPLIED at 2026-11-02 12:13:03 UTC** by reviewer, source `c7774b3eeb1d98b9b41e3e78e7647ab5cfd11cc7`, migration SHA-256 `a4f51b73d1aa339939f4d2e0f7a0adb4f8fea9018625750a137648ed3a0cf1e9`. Reviewer reports full analyzer/affected tests/692 lint passing before application. Independent postcheck schema654, four function bodies match, anon denied and only page/detail granted authenticated. Canonical340 real pgTAP **51/51 passed before application and against applied live functions in rollback**; post-apply intentional CLI exit1/PGTAP_PASS, independent postcheck exit0/schema654, temporary pgTAP absent and bodies/grants unchanged. Ledger APPLIED confirmed. Evidence `~/.deskilo-exchange/evidence/3070-0654-applied/`. E2 preparing genuine APPLIED/contract/bundle and necessary final local gates. Public ref/CI still held; parent #3070 remains open for atomic write-gate and evidence/FX residuals.

Original failed fixtures/shim runs remain historical failures, not overwritten by this success. E2 broad lint also encountered a native-asset signing collision while another Flutter test ran in the same worktree; serial retry after completion passed692. Serialize Flutter test invocations within a worktree; retain original exit and distinguish this infrastructure retry from deterministic defect retries. No repeat database application or unchanged pgTAP is required merely to refresh metadata.

## Benchmark initialization partial repair — private candidate

Clean private `3f5e75ce9e5ed5da4543f0e3faf1f97da02203f0` in `/private/tmp/deskilo-ci-harness`: one file `tool/bench/flutter_test_config.dart` reexports existing test bootstrap. Baseline invitation failed TaxReferenceUnavailable exit1; same focused journey passed exit0 after correction; default tool/bench11/11 with9 samples, targeted fatal analyzer and perf_gate_test reported passing. No budget/timeout changes. Logs `/tmp/deskilo-ci-journey-before.log`, `-after.log`, `-default.log`, `/tmp/deskilo-ci-perf-gate.log`, `/tmp/deskilo-ci-perf-lint.log`.

Actual workflow gate remains FAIL: now-executed pending_leave_return trips13 exceeds8, back_corrections1 versus2. Earlier “no budget overrun proven” applied to the failed initialization run; this later run establishes measured gate failures. A successful test runner or uploaded artifact is not complete workflow success. Reviewer asked to assess bootstrap patch narrowly; E1 continues bounded call-origin and recipe-contract diagnosis without changing budgets or inventing an extra back action. No new owner approval needed for diagnosis; any proposed contract change needs concrete evidence. Same second checkpoint, separate commit/proof for later correction. Dictionary port owner remains unknown, no workflow/stack edit or claimed SQL defect; no public ref.

## Pending journey phase trace and metric-contract blocker

One-sample focused trace `/tmp/deskilo-ci-pending-phase.log` exited0; temporary instrumentation restored and HEAD clean. Observed calls are actual repository calls, not meter duplication: fetchMyMember4 (two at initial entry, two selecting ws-b), capability6 (myDatabaseCapabilities plus account-bound mcpAccessStatus at Assistants entry/request/withdraw), workspace.fetchMine1, request/withdraw1 each =13. Cause of paired membership rebuilds is not yet proved. Do not infer realtime invalidation. Distinct client/account contexts prohibit blind cache sharing. Eliminating all four membership calls alone leaves9, still above8 with other behavior unchanged; this does not prove all remaining calls irreducible.

Back metric counts explicit probe.back. #1816 used Back from Profiles and Back from Assistants; #2136 commit99c12c923 replaced the first with workspace selection from Me. Current recipe truthfully has one Back, while gate requires2. Reclassifying selection or adding meaningless navigation is not a valid correction. No budget/metric change authorized; full nightly remains red.

Bootstrap3f5 remains independently source-approved. E1 now limited to recording the old/new metric contract and a bounded read-only investigation of paired membership rebuilds; no generic lifecycle rewrite or broad reruns to chase the target. A meaningful provider improvement, if established, must preserve context/authorization and be judged separately from the stale metric contract. Gate completion requires an explicit contract/product resolution; it is not a mechanical initialization fix. Dictionary ownership remains unknown, no edit.

## Private containment and resumed implementation — 12:38 UTC

GitHub repository API independently confirms private=true/visibility=private, current account admin access. Reviewer reports Pages404/Actions enabled; master protected=false and protection/ruleset403 due private-plan limitation. Required exact-head review and CI remain manual mandatory merge conditions; no bypass or public restoration authorized. Privacy does not erase previous copies/history.

PR3253 published at reviewed d8d3c467; five workflows started12:37:18, independently verified in_progress12:37:48: Quality41446196242, Web41446196206, SAF-T41446196087, E-invoice41446196014, VAT41446196007. Reviewer owns through completion/merge handoff, E2 fixes actual failures. No success/merge claimed at this snapshot. Earlier publication-held statements are superseded, not retroactively proof that work was published then.
