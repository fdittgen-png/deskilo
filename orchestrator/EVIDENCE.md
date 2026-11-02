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
