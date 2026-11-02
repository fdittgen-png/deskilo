# Decision register

Current decisions below supersede conflicting historical inbox entries. A replacement orchestrator should preserve them unless the owner changes direction or new source evidence materially contradicts the premise.

| Revision | Decision | Evidence and implication |
| --- | --- | --- |
| Team activation | New team implements open issues; retired Claude drain remains | [Owner activation](https://github.com/fdittgen-png/deskilo/issues/2596#issuecomment-6572827522). Three existing Codex sessions; no extra spawned team. |
| D2519 R3 | Retain registry values; all 21 evidence-backed reasons and zero-residual enforcement only | [R3 correction](https://github.com/fdittgen-png/deskilo/issues/2519#issuecomment-6573077845). Ordinary creation already writes platform OFF except environmentPairs withTwin. Prior six-OFF authorization 6573032180 is superseded and its uncommitted changes were reconciled. PR #3250 merged. |
| Hardware defaults | Keep kioskMode, nfcBadges, nfcSeatTags, qrBadges and coOwner ON in registry | #341/#604 plus consumer evidence: explicit manual provisioning/issuance/assignment remains. Device requirements do not mean flag enablement performs setup. qrBadges OFF hides issuance; do not claim it disables existing QR scanning. |
| Setup triage | No setup-runtime expansion under #2519 | Web answerQuestion changes a local draft, summary exposes choices and export produces XML; app has preview and Apply. The cited source does not establish silent live activation. A separate reproducible loss of explicit choices needs a bounded follow-up, not another broad audit. |
| D2470 architecture | Reuse existing accounting connection, Vault and OAuth lifecycle | [Architecture correction](https://github.com/fdittgen-png/deskilo/issues/2470#issuecomment-6563403479); no separate token implementation or generic accounting-picker exposure for HMRC. |
| D2470 recovery v2 | Independent random marker per acquired attempt; opaque wire token bound to declaration/holder/marker | Current wire format is SHA-256 hex over those inputs; never raw holder or holder-only fallback. Marker rotates on acquisition, not reads/refusals. Active leases always refuse; stored accepted receipt wins; stale markers/holders cannot authorize later attempts. Legacy RPC fails closed for recovery. |
| D2470 timing | Fresh clock after insert/lock; statement-time read cutoff | Both waited insert-winner and locked recovery receive a fresh lease. Real delayed/rollback contention proof required. Earlier now()-based WIP and its harness are stale. |
| D2470 UI | Explicit fresh acknowledgement is consumed and cleared on loading/error | Successful fresh no-marker read can allow a no-token request; atomic server permits only safe initial claim or accepted replay, and blocks uncertain/active claim without POST. Failed/stale reads never enable retry. A refresh failure followed by the same marker must not resurrect an old acknowledgement. |
| D2470 filing | Failed acceptance persistence must not file locally | Return real accepted_not_recorded receipt honestly; no manufactured receipt or filed state. Duplicate provider refusal is not receipt reconstruction or proof of safe retry. |
| D2470 Demo | One existing London return begins as clearly simulated uncertainty | Normal UI check/recovery, reopening before/after, no-check and stale-marker tests. No second return/new Demo framework; real provider acceptance remains separate. |
| D2470 CI | Existing isolated database runner with one bounded draft proof push | [Live queue](https://github.com/fdittgen-png/deskilo/issues/2596); add focused race integration only, preserve required checks. Capture old proof with provenance, combine UI fix and genuine APPLIED/contract follow-up. No duplicate manual/PR run or premature dev apply. |
| D3070 | Authoritative supplier balances and supplier-scoped payable navigation | [Assignment](https://github.com/fdittgen-png/deskilo/issues/3070#issuecomment-6573668047). Existing list/last bill/annual spend delivered. Reuse full remaining-balance semantics, including applied_invoice, signed allocations/cancelled state; separate currencies; explicit wide permission/workspace/feature gates; keyset >2000 and legacy compatibility. |
| L10n lock correction | E2 generation/tests released before #3251 merge | Exact #3251 file comparison has no ARB/generated l10n/help changes. Migration aggregates, London Demo and overlapping coverage remain held until handoff. |
| Reviewer help | Bounded help within current checkpoint, independent review required | Owner permits spare reviewer capacity for implementation. Exclusive file handoff/separate worktree; E2 integrates one PR; E1 reviews reviewer-authored code. No third checkpoint or self-approval. |

## Lessons to preserve

1. Verify actual source semantics before making product-default decisions. A stale header caused an unnecessary OFF recommendation and real rework; R3 corrected it.
2. Update the current summary and reference a decision revision. Delayed queued reports repeatedly resurrected already-resolved questions.
3. Reserve actual changed files/contracts. A blanket localization lock prevented useful widget verification with no real overlap.
4. Separate design acceptance, source review, verification, application, merge and external acceptance. None implies the next.
5. Preserve useful old evidence under its original SHA; never relabel it as new-head proof. This avoided discarding valid HMRC database evidence while fixing a UI regression.
6. Prefer one coherent checkpoint and final combined metadata push. Extra messages, audits and CI runs are costs, not progress.

## Explicit Back-metric correction and bounded capability work

Orchestrator inspected commit `99c12c9236ebb0aa27000238b4d355f689e11b98` (#2136): pendingLeaveReturn removed the Profiles Back action and replaced it with workspace selection from Me, while retaining the Assistants Back. Decision: correct the gate to exactly **one actual Back**, with regression/source reference. This supersedes the earlier no-metric-change hold for this specific stale expectation only. Do not redefine workspace selection as Back, add meaningless navigation, or relax the **eight-trip ceiling** or timeouts.

E1 implements the previously authorized recordingPrivacy boolean selection with privacy/workspace/account regressions as a separate follow-up. Additional bounded MCP dedup design may be reviewed for genuinely equivalent account/session/target/lease context only; preserve connected-target isolation, validation, invalidation and failure/expiration semantics. Reviewer may approve a sound concrete design within that scope without another owner approval round. No blind personal-cache reuse. If no safe design exists, report a real remaining performance blocker; do not loosen the ceiling.

Keep active #3254 bootstrap head unchanged. No third PR while #3253/#3254 occupy the normal two-PR cap; one coherent follow-up after a slot clears. E2 frozen candidate unchanged, upstream semantic dependency communicated. A corrected Back expectation or 13->11 selector improvement alone is not a green nightly workflow.

## MCP sharing design review — implementation not yet approved

Metric correction implemented locally at81031c823aea5e47a2fd3305a929d74331b2b94d atop selectorfc39; reported17 gate tests pass including Back0/2 refusal and trips9 refusal. Active3254 unchanged; no third PR.

Source inspection confirms authState publishes IDs, registry retirement listener compares IDs, ActiveMcpTargetClient pre/post checks account, and commands.read retains a registry lease. These checks alone do not prove same-ID session replacement equivalence. In-flight coalescing is NOT yet authorized for implementation.

First prove personal/active capability requests overlap under unchanged benchmark scheduling, using one bounded start/completion trace. No injected delay or altered fake to manufacture a saving. If there is no overlap, stop this design as a way to achieve the measured budget.

Potential minimal seam: instance-local capability reader beneath both callers, with active MCP entering it inside its existing commands.read/client.run path; preserve every caller lease and pre/post validation. No account-ID global map or bypass using a personal result. Require real opaque auth/session-generation plus concrete client/repository identity; unknown provenance means no sharing. Same-account replacement, sign-out, client change and mutations fence old completions. Preserve connected-target/issuer/purpose isolation, per-waiter currentness, independent failures and slot cleanup that cannot delete a newer flight. Existing repository overrides must retain real metering and scope; no whole-auth refactor without demonstrated value and concrete reviewed contract. Selector/Back fixes need not wait for this unresolved design. Eight-trip ceiling remains.
