# Current orchestration state

Snapshot: **2026-11-02 09:53 UTC**. Verify GitHub and current session summaries before acting. All times are UTC unless explicitly marked.

## Owner instruction

The replacement team implements the open issues under one orchestrator. The old Claude sessions completed their drain and remain stopped. Routine implementation, review, commits, pushes and eligible merges are delegated. The owner wants efficient time/token use, pragmatic fixes and meaningful Demo use cases for changed behavior.

The orchestrator coordinates/advises and does not execute product code, migration SQL or deployments. Read-only inspection and authorized coordination writes are in use. Runtime sandbox controls still apply: blanket conversational permission is not a technical override or permission to bypass a rejected action.

## Team and active work

| Role | Existing session UUID | Current responsibility |
| --- | --- | --- |
| Orchestrator | 01a19218-9136-7920-bff3-4a1a4b345d3a | Priorities, shared ownership, decisions, efficiency and handover |
| Reviewer | 01a19b63-22e4-72c1-8ea5-49e361e4ff4f | Exact-head review, eligible merges, closure, #2596 and migration ledger |
| Engineer 1 | 01a19b63-49df-7961-ba1c-1faa87cdd67a | #2470 recovery merged; cleanup complete; independent review available |
| Engineer 2 | 01a19b63-6e38-7be2-8b35-f6c3d9f28930 | #3070 supplier balance and scoped payable navigation |

All three replacement sessions personally acknowledged the roster and reverse messaging. Their names/titles can change; route by UUID and refresh identity during takeover.

### Engineer 1

PR [#3251](https://github.com/fdittgen-png/deskilo/pull/3251) **MERGED at 09:42:40 UTC** as **189fb73ed13357bc22c399191475a6a412680a61**, from approved head **84275da130d53696997fcaf385fdc320021a48f7**. Final Quality run 41420626290 succeeded. E1 reports its clean worktree/local branch removed, remote branch absent and claim archived.

Migration **0652 is APPLIED and MERGED**, hash **8a05fb7ecdf2523bb863b1c6031a36921e6ad46e71c342040391334e77d13196**. Reviewer ledger confirms master schema 652 and released tenure. E1 released HMRC, London Demo, DEMO_COVERAGE and database aggregate locks; reviewer explicitly handed #3070 SQL/Demo/aggregate integration to E2.

E1 has no new implementation claim at this snapshot; remains available to independently review any reviewer-authored #3070 test. #2470 stays open for real HMRC application/sandbox acceptance and unproved accepted-return receipt reconstruction. Do not equate this recovery checkpoint with complete issue acceptance.

### Engineer 2

#2519 reasons/enforcement completed in [#3250](https://github.com/fdittgen-png/deskilo/pull/3250), merge **246e9a55e6da987bab5246c7bd4998567c3fbc37**, approved head **be1f64ec2c936102858a8d846545194c892f6fae**. Own branch/worktree removed and claim archived. The epic remains open; reviewer records exact remaining acceptance rather than assuming parent closure.

Current claim: **#3070**, branch `feat/3070-supplier-balance`, worktree `/private/tmp/deskilo-3070-supplier-balance`, last observed local head `a683e3772d0fbd3c0162098ec2f1f586ebbb91fb` (refresh before review). No PR at snapshot. Existing supplier list/last bill/annual spend are already implemented. Deliver authoritative outstanding balances and supplier-scoped payable navigation, with complete currency-separated amounts and actual Demo workflow.

The reviewer accepted the read direction with required corrections: use the complete remaining-balance rule including `applied_invoice`, signed allocations and cancelled state; explicitly enforce supplier-wide permission, workspace and purchases-feature gates; preserve old RPC compatibility and keyset continuation beyond 2,000 rows. Do not sum the old capped 20×100 client fetch and present it as complete.

**Lock correction at 09:38 UTC:** #3251 changes no ARB/localization/help files. E2 may generate and verify its localization outputs and run UI tests now. Older instructions holding all l10n/help until #3251 merge are superseded. That hold has ended: E1 released shared locks and reviewer handed SQL/Demo/aggregate integration to E2. E2 status may lag the handoff receipt; use reviewer CURRENT and ledger to reconcile.

**0653_supplier_balance_reads is APPLIED to dev, not merged**, at 09:51:38 UTC by reviewer. Reviewed SQL head `70eaf2d187602ce724bde906347b0401debae5c2`, SHA-256 `018f543347d5847d49237de5c47cdf14575ce52547401eb8efe3dc0e0179733b`. Ledger reports schema 653, both RPCs present and anon denied. Master remains schema 652. E2 rollback harness reports 27 assertions with no failures; final pgTAP/CI and exact-head review remain pending. Next: genuine APPLIED/contract artifacts, meaningful supplier Demo journey, consolidated final gates and one PR. Tenure remains E2 until merge.

### Reviewer implementation assistance

The owner permits bounded coding help when review capacity is free. Reviewer may help #3070 with one explicitly handed-off adversarial pagination/recovery test file in a separate worktree. E2 must first supply a compilable SHA and exclusive file ownership; E2 integrates into the same PR. No duplicate tests/helper PR/third checkpoint. E1 independently reviews reviewer-authored changes; the reviewer cannot self-approve them. No helper handoff or authored code was confirmed at snapshot.

## Checkout and branch state

Root `/Users/floriandittgen/orgcowrk` is an inspection/coordination checkout, observed detached at `c352b2cf3e407e7b93e5fa802d5c9466dc96f933`, not the current implementation base. Pre-existing root changes in .claude/settings.json, .mcp.json and supabase/.temp/cli-latest plus untracked artifacts are preserved. Always create an isolated worktree from freshly fetched origin/master. Git remote: fdittgen-png/deskilo. Default development branch: master.

Keep `hosting/godaddy` (production deployment source) and `coord/cloud-codex`. Preserve `/private/tmp/deskilo-cloud-exchange`; do not assume ownership of that existing checkout.

## External or deferred work

- #2470: real HMRC Developer Hub application and recorded sandbox acceptance still missing.
- #3235: signed-in real-browser return and native Back evidence remain; code is already merged. Do not reimplement or invent identity/device proof.
- #3092: paired Vault/Edge push secrets, FCM account and permitted recipient/device evidence remain missing.
- #2578: full one-transaction performance proof NOT RUN; direct development connection needed. Management API timeout/split timings do not substitute. Keep the documented synthetic dev marker; do not delete its owner/tombstones.
- #2581: positive export proof blocked by an automatic rejection of test-identity creation. Do not retry via SQL, another role or another credential route.
- Provider/certificate gates such as #2377/#3159 and release/drop gate #3141 remain separate from code completion.
- #2832–#2836 and #3120 are deferred next-version work; #2855 wider guides and #2494 refactoring remain paused unless current owner/queue explicitly resumes them.
- Available Android/iPhone devices, remote-phone pairing and active cloud-session presence: **UNKNOWN currently**. No always-on connection or watcher is assumed.

Development project reference: `zwzbynivewivvjmripeb`. No secret values are stored here. Cloud tooling must be rediscovered; the historical cloud report lacked Flutter/Dart/native toolchains.
