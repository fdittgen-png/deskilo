# Night handover — local Codex → new Claude CLI
<!-- dated: 2026-10-31 — operational snapshot; verify live heads before acting -->

Prepared at the owner's request on 2026-10-31, approximately 22:55 UTC (15:55 PDT).
No secret values are included. Incoming role: **a2 (night implementer)**.

Final live check **2026-10-31T22:58:45Z**: both3179 and3180 are OPEN at the exact heads below; both implementation worktrees are clean and pushed.3179 has e1 approval, green native packaging/validators/gate tests, with money/database/FOSS and aggregate completion still pending.3180 has started web validation and queued Quality; formal review remains pending in the observed inbox. Re-check live state before acting. Durable Git copy: communication-only tag **handover/night-2026-10-31**, file NIGHT-HANDOVER-2026-10-31.md.

## Owner instruction — read this before older handovers

**DRAIN ONLY WAS REVOKED.** The owner's newer instruction is: “Stop when all issues are implemented. Not earlier. And listen to the Claude code sessions.” e1 acknowledged at **2026-10-31T22:14Z** and restored the v1 closure queue. Do not follow the drain-only directions in earlier snapshots.

The owner now wants this new Claude CLI session to take over the work for the night. This document transfers the current checkpoints and queue; it does not claim all issues are done. Outgoing Codex will take no new coding claim during transfer. Before pushing, announce takeover to e1/gate and reconcile live claims. Continue the agreed v1 queue without waiting for routine approval. No automatic production release is authorized.

Maintain **≤4 open implementation PRs across all lanes, drafts included; ≤2 active coding workstreams; one migration lane**. Finish acceptance rather than opening many partial slices. e1 owns formal review and issue closure. Preserve the protected production branch **hosting/godaddy**.

## First actions

1. Read this file, then current `CLAUDE.md`, `docs/AGENT_RULES.md`, and the selected project skills from a current worktree. The root checkout is stale; use origin/master as integration authority.
2. Read `~/.deskilo-exchange/{to-a2.md,status-a2.md,queue.md,migrations.md,README.md}`, open PRs, actual worktrees and claims. Read current issue bodies and latest corrections before implementation.
3. Append a UTC acknowledgement to `to-e1.md` and `to-gate.md`: “a2(claude-night) took over HANDOVER-codex-to-claude-night-2026-10-31.md; owns PR3179/3180 at the recorded heads, subject to live state; next2488 after capacity frees.” Update `status-a2.md` and root `.agent-work` claims.
4. Fetch normally. Verify PR3179 and PR3180 states and exact heads. If already merged, clean only their clean worktrees and advance. If a current candidate is red, diagnose the real failure and coordinate with e1 before pushing to an approved/armed branch.
5. Finish these existing PRs; then take #2488 in the order below. Do not create a third coding stream while both remain active.
6. Read the inbox every work cycle, after a push and before idle. **Do not create a recurring job, assume/re-arm a watcher, or kill another session's fswatch/process.** The owner cancelled recurring job641c5f9c; do not recreate it.

## Repository and worktrees

Remote: `https://github.com/fdittgen-png/deskilo.git`. Default branch **master**, not main.
Observed origin/master: **2f3c1a45447bb29723898766887c9fc809fe8673**, merged #3178, schema631.

| Checkout | Branch / exact HEAD | Purpose |
|---|---|---|
| /private/tmp/deskilo-3094-ci-security | chore/3094-ci-security / **3ebe7be220b14d6cc58d6b8a2163df206be5ef12** | PR3179, #3094 security; clean, pushed, e1 APPROVED |
| /private/tmp/deskilo-3069-accounting-navigation | test/3069-accounting-navigation / **49986b4880d82e6ff1f0f8fc135decce5896ae06** | PR3180, #3069 navigation; clean, pushed, review/CI pending at publication |
| /private/tmp/deskilo-cloud-exchange | detached communication-only checkout | coord/cloud-codex; never merge this history into application source |
| /Users/floriandittgen/orgcowrk | detached **c352b2cf3e407e7b93e5fa802d5c9466dc96f933** | Common Git repository and local configuration; **never code here** |

The root local `master` ref was last observed at23357c57c; use **origin/master**, not that stale ref. Other local pr3178/pr3179 refs are review remnants, not new implementation work.

Root status, intentionally preserved:
```
 M .claude/settings.json
 M .mcp.json
 M supabase/.temp/cli-latest
?? .agent-work/
?? prs.json
?? snapshots.jsonl
```
Do not commit/copy private configuration or reset these edits. There is **no useful uncommitted implementation** in the two active coding worktrees. All required tests/fixtures are committed and pushed.

## Existing checkpoint A — #3094 / PR3179

PR: https://github.com/fdittgen-png/deskilo/pull/3179  
Head: **3ebe7be220b14d6cc58d6b8a2163df206be5ef12**  
Quality: https://github.com/fdittgen-png/deskilo/actions/runs/41248620765  
Formal review: `~/.deskilo-exchange/reviews/3179.md`, **APPROVE at3ebe7be22**, finding-by-finding; e1 said “arm on green” at22:33Z. Do not treat approval as a merge.

What is complete:
- Every third-party non-actions/* reference is pinned to an upstream-resolved full SHA; grouped weekly Dependabot PR limit1.
- Edge deployment uses pinned setup-cli and fixed Supabase CLI2.118.0; no credential-bearing releases/latest download.
- Gitleaks8.30.1 archive checksum pinned; quality gate scans current source plus complete PR commit range. A real negative control catches a new credential even in a fixture path, and a credential introduced then removed within the PR.
- Exceptions require **exact synthetic value AND exact path**; no blanket test-directory exception. Reports fully redact credentials.
- All workflows declare default read permissions; dictionary write rights are job-scoped. Windows/macOS build jobs stay read-only; release attachment write rights are in separate tag-only artifact jobs.
- Workflow inputs pass through env; Windows PR signing never loads PFX secrets; always-cleanup for PFX/keystore; doctor stderr excluded from public reports.
- Existing verify_jwt parity retained. CI wiki canonical source updated. No migration.

Local receipt:
- Full fatal-info Dart analysis **exit0**.
- Full guarded lint/help **709 passed, exit0** before integration.
- After one conflict-free master merge and typed-YAML correction: affected workflow/schema/bundle/help **57 passed, exit0**.
- Gitleaks current source + final two-commit PR range **exit0**, refusal/removed-credential checks **exit0**.
- Selected help/capability generators **exit0**, shell syntax/diff checks **exit0**.
- Original failures retained: strict lint red proof37 unpinned references,6 missing permissions,21 input interpolations; first full analysis9 dynamic YAML calls. All corrected. Do not rerun old failed candidates.
- Commits: addb4c2f2440626acfdeffbb013eae48db57c9b8; master merge821bb0f02fffc4e46977c35e20487c20473eaf41; final3ebe7be22.
- Private local logs: /private/tmp/3094-final-lint.log, 3094-analyze-final.log, 3094-post-merge-tests.log, 3094-final-source-range.log.

Latest observed CI: scanner install/scan controls, Edge tests, Windows MSI, macOS DMG, web build and official XML validators passed. Release attachment/deploy steps SKIPPED. Quality still finishing database/shards/aggregate; FOSS audit still running. **Refresh live status; pending is not PASS.**
The Linux scanner steps already passed inside the actual quality gate. No real certificate signing or publishing occurred.

Next action: let e1 arm/merge the exact reviewed green head; verify MERGED and squash SHA. If deterministic CI failure, fix it in this branch only after coordinating approval/arming state with e1. No --admin, no force push. Mirror the updated CI wiki from merged source afterwards.

## Existing checkpoint B — #3069 / PR3180

PR: https://github.com/fdittgen-png/deskilo/pull/3180  
Head: **49986b4880d82e6ff1f0f8fc135decce5896ae06**  
Quality: https://github.com/fdittgen-png/deskilo/actions/runs/41250250531  
Web validation: https://github.com/fdittgen-png/deskilo/actions/runs/41250250513  
Formal review was pending when published; check reviews/3180.md and to-a2.md.

Retained contract: read https://github.com/fdittgen-png/deskilo/issues/3069 and its corrections, especially implementation-ready comment6428921645 and coordination comment6429232994. #3063 is already merged; **do not rebuild its accounting navigation/page**.

Two changed files:
- `lib/app/shell/shell_drawer.dart`: financial groups no longer depend on administration.isNotEmpty. Each group already hides itself if empty. This fixes a supported **exportData-only** reader with valid accounting feature prerequisites who had a valid accounting route but no menu.
- `test/app/shell/accounting_navigation_test.dart`:14 acceptance cases cover owner/manager/member/no-rights, disabled features, drawer/permanent sidebar, export-only regression, every canonical moved route, and configuration's one link to the sole legal/VAT editor.

No route, feature gate, tax logic, parameter or editor was duplicated/moved. Existing #3063 setup/help links remain canonical; no new strings or configurable parameter. No migration.

Local receipt:
- Real supported red proof: both export-only navigation presentations failed before the guard fix; both green afterwards.
- An earlier VAT-with-Money-off fixture bypassed required feature dependencies; **discarded**, not acceptance evidence.
- Full guarded `test/lint test/app/shell test/app/purchase_process_navigation_test.dart test/app/route_access_test.dart`: **791 passed, exit0**.
- Final acceptance file after import-only correction: **14 passed, exit0**.
- Full `dart analyze --fatal-infos`: first exit1 on one import-order info; sorted imports, reran full analysis **exit0**.
- Filtered build_runner for shell_drawer.g.dart **exit0**; l10n_audit **exit0**; **no retained generated diff**.
- The filtered generator deleted183 unrelated generated files. They were all confirmed clean before the run; only those deletions were restored. Do not blanket-restore/stash another session's work.
- Diff check **exit0**. No source changed after the final receipts.
- Private logs: /private/tmp/3069-export-navigation-red.log, 3069-export-navigation-green.log, 3069-navigation-matrix.log. Final full test/analyze exits are also recorded in PR body/tool execution; do not invent a log path for terminal-only runs.

Next action: e1 formal review at49986b488, address findings, required CI, merge. PR says **Closes #3069**; e1 decides whole-issue closure. No extra UI polish or unrelated finance rewrite.

## Next issue after capacity frees — #2488

e1's22:14Z order: **#3094 → #3069 → #2488 → #2375 → #2380 → #2370 → #2578 → #3166 → #1917 → UX remainders**. Queue is at `~/.deskilo-exchange/queue.md`; actual GitHub state overrides stale unchecked lines.

#2488 has been read but **not claimed/coded**. Its prerequisite #2486 is actually CLOSED (2026-10-18); old parent status paragraphs are stale. No locale.default_* or directory endpoint rows were found in current settings seed. CountryCatalog is still the static32-country list. No migration number is reserved for this task.

Read:
- https://github.com/fdittgen-png/deskilo/issues/2488
- **Normative amendment:** https://github.com/fdittgen-png/deskilo/issues/2488#issuecomment-6174448509
- Parent design/correction: https://github.com/fdittgen-png/deskilo/issues/2483#issuecomment-6174423726
- Project migration skill plus its reference, global Supabase/Postgres rules before SQL.

Key boundaries already decided:
- Reuse a **typed country-catalogue domain in the existing reference store**, existing validator/version/editor/RPC/bundle pattern; no second country store or renewed architecture study.
- Capture current catalogue golden before moving it; preserve code/currency/timezone/banking scheme and existing API. Creation catalogue is not permission to issue invoices.
- Defaults and endpoints are platform settings with real consumers/editor/setup/l10n tests; **missing financial facts must remain unknown/refused**, never silently FR/EUR.
- Explicit managed source setting wins; then permitted build override; then documented bundle default. Build constants never overwrite shared server data. Show provenance.
- Validate URI scheme/credentials/fragments/origin/redirect behavior; no private token propagation, SSRF/private-network bypass or accidental public localhost policy.
- Multi-zone countries need explicit timezone selection; immutable per-source/revision snapshots and source-switch refusal/recovery are retained. No invented historical effective dates.
- Country catalogue and fallback/endpoint work have approved bounded checkpoints; finish one coherent acceptance at a time using Refs+Remains until whole #2488 is met.

After it, follow the queue's exact remaining acceptance. Do not reopen delivered #3077/#3169/#3091 or rewrite #3092 code for missing operator evidence.

## Database and external state

Only authorized hosted development project: **coworking-staging**, **zwzbynivewivvjmripeb**, eu-central-1. Schema marker **631**, matching master. Pending applied-but-unmerged ledger is **empty**. Next candidate number is **0632 only if still free at push time**. Read actual ledger and claims before reserving; do not reserve ahead during design.

#3092 / PR3178 is MERGED:
- reviewed head dce8100fa20290d30d6ed70ecd5da9734429d022
- squash/master **2f3c1a45447bb29723898766887c9fc809fe8673**
- quality41246398626 all required checks, clean replay/pgTAP/contract/lifecycle/topology GREEN.
- Source migration0631 and fixture321 are committed. No local-only SQL remains.
- **Issue3092 stays OPEN for operator evidence.** Dev Vault deskilo_push_shared_secret and Edge PUSH_SHARED_SECRET / FCM_SERVICE_ACCOUNT were absent when last checked. Candidate not deployed. Once configured, only exact service credential or shared header is accepted; while secret is unset, approved warned legacy delivery is intentionally preserved. Do not “fix” this into a notification outage.
- Pair Vault first, then Edge secret, deploy reviewed function with gateway JWT verification retained, prove refusal + actual trigger delivery on permitted test recipient. This is operator/provider work; no real-device/provider proof has been claimed.

Production state/credentials/certificates UNKNOWN; do not inspect/change them merely because implementation is authorized. GitHub authenticated CLI and Supabase connector/CLI work locally. Local psql not in PATH. Ephemeral P/W-A/W-B replay/topology runs exist in quality.yml and scripts/topology_stacks.sh; no permanent extra hosted projects are provisioned.

Android SDK exists, but latest adb inventory had **no attached devices**. Physical iPhone/browser login/device availability UNKNOWN. Native/browser/human evidence must be real, not substituted with fake acceptance.

## Toolchain and verification discipline

Flutter **3.47.5**; Dart **3.13.4**; local SDK `/Users/floriandittgen/development/flutter`. Deno **2.9.7**. Local Supabase CLI **2.120.0**; quality/dictionary pin **2.118.0**. Xcode26.6/17F113; Android SDK `/Users/floriandittgen/android-toolchain/sdk`.

Existing coding worktrees are initialized. Fresh worktree:
```sh
git fetch origin --prune
git worktree add /private/tmp/deskilo-ISSUE -b TYPE/ISSUE-SLUG origin/master
python3 scripts/worktree_prepare.py --resolve --database-ci
dart run tool/preflight.dart --base origin/master --list
```
Preparation initializes root +7 independent packages, enforces lockfiles and current-checkout package mappings. Root pub get alone is insufficient. READY/PENDING_CI_EVIDENCE is not database test success.

Run only selected generators, **serially and wait for each actual exit**. Parallel Dart native-asset prep races objective_c.dylib signing. Filtered build_runner can delete clean unrelated generated files: snapshot status first, restore only proven deletions from that invocation. Never format existing files/directories.

Before push: full `dart analyze --fatal-infos`, all lint, affected suites, generated diff reviewed, original exits preserved. **All Mac Flutter tests through**
`/Users/floriandittgen/.deskilo-exchange/tools/guarded-flutter-test.sh`.
Never launch the full local suite, never broad-pkill Flutter/testers. Guard exit99 is a real runaway to fix, not permission to raise memory limits. Its tailer can race log creation; read the named inner log and original process exit rather than assuming the whole run failed.

Required contexts:
- analyze · l10n gate · test · coverage
- quality · database
- quality · report

A current deterministic failure requires a corrected candidate. A superseded run stays cancelled. At most one justified infrastructure retry, whole Quality workflow/attempt, never failed-shard artifact mixing. A changed SHA invalidates affected receipts/approval. Master integration once if needed, no iterative rebase/force-push churn. Never --admin.

## Claude session coordination

Mac exchange: `/Users/floriandittgen/.deskilo-exchange`.
- **a2** incoming implementer: reads to-a2.md, writes status-a2.md.
- **e1** reviewer/queue/closure keeper: to-e1.md; writes reviews/PR.md and replies to-a2. Latest3179 review says APPROVE/arm on green.
- **gate** review/CI/branch hygiene: to-gate.md.
- **perf** stopped by owner; no active coding claim confirmed.
- **Cowork** screen/provider/device work: e1 writes to-cowork.md; replies go to-e1.md.

Append UTC messages; never rewrite another session's lines. Review request is **PR number + full SHA + issue + Refs/Closes + evidence**. e1 arms normal auto-merge after approval/green; never close an issue directly—send CLOSE evidence to e1. Do not push onto an armed branch without coordination and re-review. Owner asked that routine authorized decisions be made directly; do not park implementation on an unnecessary owner-review question.

The cloud session /workspace/deskilo cannot read Mac files. Its identity is cloud-codex; only read-only review was assigned. Git communication branch **coord/cloud-codex** has to-a2.md/to-cloud-codex.md/status files. It is **orphan communication only; never merge into app source, never force push**. No active watcher or automatic delivery is promised. Historical tags handover/cloud-2026-10-31 and handover/cloud-2026-10-31-reviewed describe older states; the latest owner override revokes their DRAIN instruction. Keep channel while implementation continues; archive before final cleanup.

## Branch/release cleanup and remaining gates

Remote protected exception **hosting/godaddy @0c83196a242697d95bdfd143ca88e1c0adbb66ea** MUST BE KEPT. It is the GoDaddy deployment source, not app history. No deployment implied.
Parked code-health commit2156a29ba0f5c85e3ad24a7bf2bf4182f742c736 is preserved by remote tag **archive/drain-2026-10-31/code-health-baseline**; its old branch was removed. Do not revive that reserved work without ownership reconciliation.

`ci/dictionary-refresh` currently carries schema631, observed6f65abd8c2cec333cb1185a5431a453c8b7c0465. Workflow41248149069 succeeded. Actions may push this branch without permission to create its PR. Keep one latest refresh, not a PR per merge; inspect actual schema after later migrations, then integrate final generated docs when appropriate. Never merge stale earlier refresh blindly.

The CI wiki is published at https://github.com/fdittgen-png/deskilo/wiki/CI-and-Automation . Canonical file docs/wiki/CI-and-Automation.md gets security updates in3179; mirror after merge. Separate wiki clone /private/tmp/deskilo-ci-wiki, master observedb52ce6d73ff6b4d2a8e9bcc0325b672083ddc13f.

#3091/3175 and #3176/3177 are merged/closed; their worktrees and feature branches were removed. Other merged local review refs can be pruned after confirming owners/clean state. Preserve local config. At eventual completion, finish commits/pushes/reviews/merges and remove obsolete branches/worktrees, retaining master and hosting/godaddy; scheduled dictionary automation can recreate its working branch later.

No automatic release, production writes, permission/protection changes, real payments/submissions, paid provisioning or credential creation. Never use retired Play track alpha1. All useful code is committed/pushed; missing external acceptance is BLOCKED/NOT RUN, never PASS.

## Transfer agreement

- Incoming a2 takes the existing3179 and3180 PRs at the exact heads above, then the e1 queue.
- e1 retains formal review, arming and closure; gate retains CI/hygiene coordination.
- No new coding starts until takeover/claims are reconciled and a stream is free.
- No active migration reservation; re-check before0632.
- Outgoing Codex creates no additional implementation claim during handover.
- Keep working through executable issues; report concrete provider/device/operator blockers with responsible role, without pretending they are implemented evidence.

