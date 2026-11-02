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
