# Operating instructions

## Authority and scope

Latest explicit owner direction and numbered decisions supersede earlier queued messages. #2596 is the only live assignment queue; current source and timestamped receipts resolve factual state. A stale message is not a new reversal. Check CURRENT before reacting.

Two active implementation checkpoints maximum, normal target two open PRs, hard cap four including drafts. One migration tenure and one registry-touching branch at a time. Reviewer assistance within an existing checkpoint is allowed with exclusive files and independent review, not a third stream. Do not create work merely to occupy an idle session.

Orchestrator selects outcomes and resolves scope/ownership. Engineer owns implementation, tests and candidate receipts. Reviewer owns routine design feedback, exact-head review, merge/closure and queue/ledger. Route only material unresolved tradeoffs to the orchestrator; no repetitive design approval rounds or owner questions for already-delegated routine decisions.

## Communication

On the Mac, use the supported CLI:
```sh
codex queue --thread SESSION_UUID --message "DECISION/QUESTION/READY: issue, exact SHA, concise finding, action and evidence path"
```

Use UUIDs from CURRENT, not ambiguous session titles. The command has an existing approved prefix in this runtime, but successor permissions may differ. Do not alter sandbox settings, write internal queue databases or click approval controls to evade restrictions. A queued message is not proof it was read. Validate two-way routing once on takeover; do not create acknowledgement loops.

Local status directory: `/Users/floriandittgen/orgcowrk/.agent-work/coordination/`. Each session edits only its own reviewer.md / engineer-1.md / engineer-2.md; orchestrator owns README and this knowledge base. Put a short CURRENT section first: decision revision, checkpoint/claim, full SHA and dirty state, next action, real blocker, evidence links. Historical receipts follow.

When local files are unavailable, use #2596 and selected issue/PR comments plus this Git branch. Existing branch inboxes are `to-cloud-codex.md` and return `to-a2.md`; their old role names are historical, not permission to revive a2. The current reviewer can relay Git messages to local sessions at work boundaries; confirm that arrangement personally. No cloud ACK, continuous polling or immediate delivery is assumed. Do not resurrect retired Claude jobs/watchers.

Notify only actionable blockers, material findings, ownership transfers, review-ready candidates and actual merge receipts. Read relevant deltas at claim/push/review/merge/long-task completion. Batch small related findings; do not paste complete histories or full logs.

## Implementation and review

Read CLAUDE.md, docs/AGENT_RULES.md and the selected issue's corrections. Implement in one owned worktree, with an issue claim and explicit producer/consumer/file reservations. Never edit another session's worktree or remove unrelated dirty files.

Pinned Flutter 3.47.5; observed Dart 3.13.4. Worktree readiness: `python3 scripts/worktree_prepare.py --resolve`, with `--database-ci` when relying on isolated CI proof. These are implementer commands, not evidence that tests passed. Independent packages must be initialized.

Use preflight --list, only implicated generators, fatal-info analyzer, guarded lint and affected tests with explicit paths. Full suite in CI only. Preserve original exits, candidate/tree, run/attempt and artifacts. Reuse evidence only when relevant inputs are unchanged and provenance is explicit; final required CI still runs on the final head. Do not rerun passing checks just to produce activity or blindly retry deterministic failures.

Every changed user-visible behavior includes a reachable existing Demo use case, actual flow and state readback, relevant permission/refusal/recovery coverage, reset/isolation and updated coverage. Synthetic Demo is not provider/device evidence. A reason-only or harness-only change may state precise Demo N/A.

Review exact head and actual source delta. A new head invalidates affected approval/evidence. Arm eligible squash merge with expected head; no bypass. Merge master once only for actual relevant overlap/conflict; no periodic rebases/force-push chain. Clean only owned merged branches/worktrees after verified merge, preserving retained branches.

## Database lane

Reviewer reserves the number from fresh master and ledger at handoff/push. Ledger: `~/.deskilo-exchange/migrations.md`. A claimed number is not applied; applied is not merged. Never rewrite applied bytes.

Read project migration skill before SQL. Required pattern: reviewed exact bytes, authorized development target, rollback harness and independent rollback postcheck, authorized application, actual applied hash/schema/roles, contract/bundle outputs and final CI. Some harnesses deliberately raise HARNESS OK and exit 1 to roll back; keep that original exit and prove rollback separately.

Established reviewer route: `supabase db query --linked --project-ref zwzbynivewivvjmripeb -f FILE`, after CLI help/auth/target checks. Do not use stale harnesses or assume all nonzero exits are expected. No production substitution.

Local Docker/psql unavailable and Colima resource guard refused startup. Respect the guard. Existing quality.yml supplies an isolated candidate replay and real independent psql sessions. #2470 has an explicit proof-push exception: settled non-DB gates first, one draft CI proof, then reviewed dev application/metadata and one combined follow-up. No fabricated APPLIED record or false green proof. Do not generalize exceptions without recording their concrete need.

## Efficiency and maintenance

At handoff, CI failure and merge, review measured waits, invalidated repeated checks, CI cycles, conflicts and token trends. Fix the cause, record the result and avoid inventing savings. Locks should cover actual overlapping files/contracts; the l10n hold was removed after source comparison proved no overlap.

Use Git-accessible receipts for critical conclusions. Keep secrets out of messages, URLs and logs. Missing credentials/human/device/provider gates stay explicit. If permissions block an action, preserve the blocker and follow the platform approval mechanism; do not route around a rejection.

## Confidential business information

Owner rule: business-plan information is strictly confidential and must never be shared on GitHub. This applies to source and history, issue/PR text, wiki and coordination documents, fixtures, generated outputs, CI logs and artifacts. Redaction must remove the confidential information, not merely relabel it. Keep private investigations and detailed exposure inventories in an owner-authorized private location; public handovers contain only generic policy/status. Do not copy confidential material into this knowledge base. Current-tree deletion does not establish history/cache/external-copy removal; report each containment limit accurately. Coordinate shared-reference changes with current implementers before rewriting history, and respect platform access/approval controls.

## Database proof efficiency — adopted 2026-11-02

Select the proof route at claim time: local isolated PostgreSQL if already usable; otherwise the established authorized rollback probe; isolated CI when publication permits. Record missing Docker/psql/resource capacity once and revisit only after an actual environment change. Do not repeatedly retry startup or bypass guards, create external infrastructure or apply a candidate merely to obtain test evidence.

Use one canonical committed fixture. Generate the harness from immutable source; manifest records candidate, migration, fixture, harness, expected baseline/schema/roles, plan and generator version. An offline preflight must reject stale source, unsupported transformation, embedded-plan mismatch and tampered input before network/DB execution. Source plan and expected runtime assertion count must agree; static counting alone is not runtime proof. E1 owns a minimal local-only builder/validator assignment, reviewer reviews it; completion is not yet claimed. Avoid a general SQL parser/framework or another product PR.

Prove fixture eligibility before transitions, including maker identities and threshold boundaries. On failure capture selected IDs, eligible removed/added sets, count and unique count using synthetic data. One focused diagnosis per unresolved cause; share its receipt and rerun only for a new question. Never fix expected totals merely to suppress a failure.

Reviewer executes one reviewed immutable transaction with original exit/result plus independent rollback postcheck. A deliberate nonzero exit is success only when the expected complete success marker and postcheck agree; assertion failure remains failure. Keep custom shim, genuine pgTAP, concurrency/replay and final exact-head CI as distinct evidence levels.

Reuse prior proof for unchanged relevant migration/fixture/harness/environment inputs, with original candidate attribution. Client-only deltas require affected client checks, not automatic database repetition. Batch material contract findings before broad gates; include recorder, state-primitives and migration-grants in focused preflight. No fabricated APPLIED/contract artifacts or blanket final-head pass.

Existing project reference describes real pgTAP within a rolled-back probe; reviewer must assess that route once for actual extension/role/session/transaction support. Do not assume an old recipe works or call a shim pgTAP. See [Supabase database testing guidance](https://supabase.com/docs/guides/local-development/testing/overview). Public publication and persistent application holds remain separate.

## Real pgTAP rollback route — feasibility confirmed

Reviewer executed one bounded feasibility probe through the established linked CLI. Real pgTAP **1.3.3** was installed temporarily inside one transaction; two actual assertions exercised postgres/authenticated roles and finish/num_failed checks. Original CLI exit1 with explicit `FEASIBILITY_PASS pgtap=1.3.3 tests=2 intentional_rollback`; independent postcheck exit0 confirms schema653, pgTAP absent and all four candidate routines absent. Raw marker and postcheck inspected in `~/.deskilo-exchange/evidence/3070-pgtap-feasibility/`.

This proves route feasibility ONLY, not canonical340 or CI. Next: E1 offline generates/validates one faithful immutable canonical340 bundle; reviewer verifies its exact source/migration/fixture/harness hashes and runs one rollback-only proof, validating real TAP/plan/finish/failure results and independent postcheck. Preserve role/session semantics, no custom shim substitution or swallowed exceptions. Do not repeat feasibility, retry Docker, apply0654 or publish a ref. A canonical pass would establish real hosted rollback pgTAP evidence, not isolated full replay/concurrency/final CI.

## Highest-priority owner efficiency directive

The owner explicitly requires all issues to be resolved as efficiently in time/tokens and as pragmatically as possible. Prefer smallest complete acceptance, existing code/flows, exact-input evidence reuse and focused checks; batch findings, avoid repeated diagnoses, speculative frameworks and acknowledgement loops. Read current receipts before stale queued reports. On actual merge reconcile promptly, release locks and clean owned work. No fake savings, incomplete issue closure or bypass of correctness/confidentiality/required checks. These expectations apply to orchestrator as well as engineers/reviewer.


## Owner-directed idle-time scheduling — 2026-11-02

At every claim/review/push/CI/merge or blocking handoff, check whether an engineer can advance useful independent work. For an expected wait over five minutes, report once: UTC start | blocking dependency and owner | expected free window (range or UNKNOWN) | useful parallel task | return trigger. On resumption, record actual end/duration once. Tests running do not imply the session is idle. No periodic heartbeat, watcher, repeated ACK or fabricated ETA.

Priority for wait work: unblock the active dependency through a nonduplicated independent review; finish a missing acceptance/evidence subtask using existing artifacts; prepare the smallest implementable next leaf against current source and latest issue corrections. Do not use an old issue body to rebuild delivered work. Read only the selected issue/necessary corrections, not the entire backlog on every handoff. No extra runs merely to fill time.

Keep frozen CI candidates immutable. A bounded, interruptible side task uses an isolated worktree if editing, explicit disjoint locks, one prepared follow-up maximum per engineer and the existing normal two-PR/hard-four cap. No third simultaneous editing worker or second migration tenure. Current candidate findings and eligible merge/cleanup preempt side work. Proof-only CI publication may follow the established reviewer-controlled path; lack of final artifacts must be labeled rather than creating silent idle time.

Measure reported idle intervals, dispatch-to-start latency, useful accepted deliverables, invalidated tests/CI, conflict/rework and merge handoff delay. Do not count a queue receipt as work started or equate utilization with throughput. Audit these at material handoffs; no claim of always-on monitoring between turns.

### First measured dispatch

Verified45 open issues, including operator/provider-gated and deferred work. E1 reported idle13:53:00Z awaiting3255 CI/reviewer, expected durationUNKNOWN. E2 reported actual idle13:52:57Z awaiting0655 review/proof, expected durationUNKNOWN. At13:55:09Z assignments queued; personal CURRENT updates confirm:
- E1 started13:55:16Z: idle **2m16s**. Independent01501c56 concurrency-script fidelity and lock-order inversion review, read-only, <=15-minute deliverable, split from reviewer SQL/live-helper/DB ownership. Then bounded2599 existing-run timing/acceptance evidence if still waiting.
- E2 started13:55:14Z: idle **2m17s**. Bounded2380 QR/RF stored-reference-to-UBL/CII gap crosswalk; latest residual comment6571197332, not delivered import/unmatch. Conditional isolated mapping/test patch only if existing contract suffices and locks are disjoint; no new DB/registry/shared Demo work or PR before slot/lock check.
- Reviewer current dependency is0655 contract/live-helper/real DB proof and3255 CI/merge; current free-window report requested, not assumed idle.

Total observed engineer idle **4m33s**, not a before/after savings estimate. Assignment-to-start after observed dispatch was7s/5s. Outcomes and any interruption/resumption remain to be recorded; no throughput improvement claimed yet.
