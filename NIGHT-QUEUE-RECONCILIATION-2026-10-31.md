# Queue reconciliation after the night handover

Observed 2026-10-31T23:10:23Z. Read-only audit by outgoing a2(codex), also
called codex-local. This takes no implementation claim, changes no priority,
and closes no issue. e1 owns queue updates and closure review; incoming
a2(claude-night) retains implementation and the migration lane.

The Mac queue's closure heading still says next #3091, its checklist still
lists #3091/#3092 code, and #2488 says not started. These are historical
entries: the night handover records #3175/#3178 merged, and incoming Claude
acknowledged #2488 start at 23:02Z. Read actual issue/PR state before working.

| Issue | Verified disposition / next action for e1 |
|---|---|
| [#3074](https://github.com/fdittgen-png/deskilo/issues/3074) | **Closure candidate, not a proven closure.** Its last comment's two remainders have merged: XML v5 decor/import in [#3160](https://github.com/fdittgen-png/deskilo/pull/3160), merge `340830d5a3236d3af86dbccc728f067c7e2f2d7b`; grid wall dragging/Undo in [#3168](https://github.com/fdittgen-png/deskilo/pull/3168), merge `825ef7428202b97f94b413ef93fbbb3423bd52d0`. Printed-plan coverage is [#3158](https://github.com/fdittgen-png/deskilo/pull/3158), merge `5bfaee1d9bf3dc01bcab55cf1e78f48e9e476385`. e1 should compare whole acceptance with earlier #3079 and these receipts before closing; do not reimplement the old remainders. This audit inspected merged state and PR descriptions, not CI artifacts or the full editor matrix. |
| [#2521](https://github.com/fdittgen-png/deskilo/issues/2521) | OPEN. Queue's checked client step is not whole completion. [Latest correction](https://github.com/fdittgen-png/deskilo/issues/2521#issuecomment-6539222331): #3038 delivered client gates/structural routes; remaining replayed-function audit and missing server gates for expenseRepartition and moneyTab-owned writes require the migration lane. invoiceSettlement already has a server gate. Do not duplicate client work or reserve a competing migration now. |
| [#3132](https://github.com/fdittgen-png/deskilo/issues/3132) | OPEN. Queue reports slices #3142/#3157/#3163 merged, but the issue body still has unchecked writes. Reconcile operations.json, confirmation/refusal/recovery tests, fingerprint and setup path against those slices before identifying the next missing write. This audit does not claim all five writes are absent or complete. |
| [#3060](https://github.com/fdittgen-png/deskilo/issues/3060) | Explicit [v1 scope](https://github.com/fdittgen-png/deskilo/issues/3060#issuecomment-6429017689): five journeys, six specified viewports, keyboard/semantics and route-by-viewport evidence. Its [execution map](https://github.com/fdittgen-png/deskilo/issues/3060#issuecomment-6429617588) makes this shared acceptance, not a duplicate redesign branch. Check final evidence after owning screen fixes. |
| [#3061](https://github.com/fdittgen-png/deskilo/issues/3061) | Explicit [v1 scope](https://github.com/fdittgen-png/deskilo/issues/3061#issuecomment-6429018165): overview/pending, reservations, members and one agreed money list; loading/empty/failure/retry/denied/input-preservation/double-submit plus one existing-harness E2E transition. Land bounded fixes with the owning screen to avoid shared-file overlap. No evidence audit completed here. |
| [#3062](https://github.com/fdittgen-png/deskilo/issues/3062) | Explicit [v1 scope](https://github.com/fdittgen-png/deskilo/issues/3062#issuecomment-6429018617): final six-step clean-workspace owner/member first-booking journey, persisted facts and reload/resume, route/auth/setup/reservation tests. Reuse #2864/#2871; no extra wizard. Do not lose this final gate when the screen queue drains. |
| [#3120](https://github.com/fdittgen-png/deskilo/issues/3120) | OPEN but explicitly [moved to v2](https://github.com/fdittgen-png/deskilo/issues/3120#issuecomment-6543635358). Do not silently pull into the night v1 queue. The comment records the commit-order/data-loss risk of a timestamp-head cache. |
| [#3141](https://github.com/fdittgen-png/deskilo/issues/3141) | OPEN, release-compatibility gated: do not drop profiles.last_seen_at until no supported app needs the legacy export column. Supported-version rollout proof is UNKNOWN here. Needs backup naming, migration proof, pgTAP and current workspace export when authorized prerequisites hold. |
| [#3159](https://github.com/fdittgen-png/deskilo/issues/3159) | OPEN, explicit external blockers: IT SdI intermediary sandbox acceptance; ES #2358 record persistence and seller AEAT certificate. Actual provider acceptance plus refusal/issuance tests precede lifting flags. Credential or operator availability UNKNOWN here. No secrets inspected. |

Recommended action: e1 reconcile stale status and include the omitted v1
acceptance/remainder entries in its maintained order, while preserving explicit
v2/rollout/provider gates. Incoming Claude continues #2488 and e1's agreed
finance/performance order. No new PR or source edit was created by this audit.

## Reviewer correction received after the audit

2026-10-31T23:11Z: e1 checked #3074 and explicitly rejected closure for now.
The merged implementation remainders do not prove these acceptance tests:

- Editor move, resize and delete of a decor symbol.
- Reserve displays decor to an ordinary member.
- pgTAP decor-row RLS: a member reads but cannot write; another workspace's
  decor is invisible.

e1 queued one small test-only PR for incoming Claude before the performance
items, intended to close #3074 only after the whole acceptance and review pass.
This is the reviewer's reported gap assessment, not a new local test run or
an implementation claim by outgoing Codex. Keep #3074 OPEN until verified.

## #3132 source reconciliation

Master was independently read through GitHub as
`2f3c1a45447bb29723898766887c9fc809fe8673`. Source was inspected in the clean
security worktree at `3ebe7be220b14d6cc58d6b8a2163df206be5ef12`; a scoped
`git diff --quiet` against that master returned **0** for MCP contracts,
registry, Edge handler, client tests and the three operation pgTAP files.

| Decided write | Merged/source evidence |
|---|---|
| set_workspace_basics | [#3142](https://github.com/fdittgen-png/deskilo/pull/3142), merge `df3b22b78e07d8eccf7d315185bccd690a7575b9`; registry lib/core/mcp/mcp_operations.dart:401; pgTAP 316_mcp_set_workspace_basics.sql. |
| set_member_permissions_preset | [#3163](https://github.com/fdittgen-png/deskilo/pull/3163), merge `d76f14555535c291d2d2444b73798999309bffe9`; registry line 414; pgTAP 319_mcp_set_member_permissions_preset.sql, including pending_validation without granting the rights. |
| create_invitations | [#3157](https://github.com/fdittgen-png/deskilo/pull/3157), merge `1c70d0310aaa152064e7a2ae8f58386f98ca8e62`; registry line 425; pgTAP 317_mcp_create_invitations.sql, including invitation_id/status without a join code. |
| create_subscription_level, then create_membership_plan | Absent under these operation names from contracts/mcp/operations.json, the Dart MCP registry and inspected MCP handlers/client tests. These remain implementation work, not an invitation/preset redo. |
| set_payment_instructions | Absent from the same catalogue/handler surface. Still needs the decided definer command, manageBilling re-check, old/new confirmation, audit event and owner notice. |

The three delivered operations occur in contracts/mcp/operations.json and
coverage.json with the named pgTAP files. Source inspection found their
confirmation/refusal assertions and the preset's pending case; **no tests were
run by this audit**. Per-write confirmation-declined recovery, setup assistant
path completeness and current coverage fingerprint execution are NOT VERIFIED
here and remain part of whole-issue closure review. Do not treat a manifest
entry or old PR description as fresh runtime acceptance.

When e1 reaches this issue, the efficient sequence is its already-decided
subscription-level command before membership-plan creation, then payment
instructions, using the existing confirmation/authorization/audit machinery.
Update contract, coverage/fingerprint and setup paths with each coherent
slice; keep Refs/Remains until all acceptance passes. set_legal_identity and
propose_floor_plan remain refused/in-app per the issue. This adds no claim,
changes no current priority and reserves no shared file or migration number.
