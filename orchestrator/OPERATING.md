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
