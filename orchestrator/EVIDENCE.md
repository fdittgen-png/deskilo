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
| `84275da130d53696997fcaf385fdc320021a48f7` | Adds genuine APPLIED/contract records only after corrected UI candidate. Reviewer APPROVED exact head, ready and auto-merge armed; [final run 41420626290](https://github.com/fdittgen-png/deskilo/actions/runs/41420626290) was still running at inspection. Never use the proof run as final-head green CI. |

Migration `0652_hmrc_recovery.sql` SHA-256:
`8a05fb7ecdf2523bb863b1c6031a36921e6ad46e71c342040391334e77d13196`.

Reviewer applied these exact bytes on dev `zwzbynivewivvjmripeb` under transactional guard, original exit 0. Postcheck: schema 652; marker column/v2 present; authenticated denied/service_role allowed. Ledger APPLIED; merge pending at snapshot. Pre/post application rollback harnesses intentionally returned HARNESS OK via original exit 1, with independent rollback/state checks. Preserve that distinction.

The contract predictor initially failed to consume the CLI JSON envelope (exit 255). Normalizing its rows and retrying exited 0; final candidate contract matches the proof replay artifact byte for byte. Do not hide the original failure.

Local evidence: `/private/tmp/deskilo-2470-db-ci.log`, `/private/tmp/deskilo-2470-ci-proof/`, reviewer `~/.deskilo-exchange/reviews/3251.md`. Earlier `~/.deskilo-exchange/evidence/2470-recovery-wip/` and the old harness hash `6d26017f...` are historical sequential smoke, not current-candidate proof.

Deno receipt: 21 tests passed. Local full pgTAP/two-session execution was NOT RUN because an isolated local database was unavailable; CI supplied the actual database proof. No real HMRC call or production migration is inferred.

## Current 3070 evidence

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
