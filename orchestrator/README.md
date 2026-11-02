# Deskilo orchestration knowledge base

This is the takeover entry point for the human owner or a replacement LLM. It preserves the current operating agreement, session routing, decisions and evidence so coordination can continue without rereading the entire conversation.

**Live dispatch:** [issue #2596](https://github.com/fdittgen-png/deskilo/issues/2596). Its reviewer-maintained body is the sole assignment queue. This knowledge base explains that queue and records snapshots; it is not a competing queue.

## Read in this order

1. [Current state](CURRENT.md): owners, exact candidates, locks, next actions and external blockers.
2. [Operating instructions](OPERATING.md): takeover, two-way messaging, authority, safe execution and review.
3. [Decision register](DECISIONS.md): current decisions and superseded instructions.
4. [Evidence register](EVIDENCE.md): merge, migration, verification and original-exit receipts.
5. [Efficiency measurements](METRICS.md): objective baseline, limitations and changes to improve work.

Read only the selected issue's current corrections and relevant source delta afterward. Historical branch-root handovers and old inbox messages are evidence, not current dispatch.

## Fast takeover

- Confirm the owner's handover and identify yourself. Read #2596 and refresh open PR heads/status before issuing work.
- On this Mac, read the CURRENT section of each `.agent-work/coordination/*.md` and the active claims. Never treat older paragraphs as active assignments.
- Contact each live session once, naming your identity, decision revision and the work you intend to preserve. Obtain one personal acknowledgement; queue delivery alone is not acknowledgement.
- Preserve current branches, dirty work, migration tenure and external gates. Do not restart retired sessions, create polling jobs or issue duplicate claims.
- Reconcile actual source/applied state and publish the current owner/next action in #2596 through its sole writer.
- Resume the next bounded action. Do not repeat completed audits or reopen superseded decisions.

## Locations and maintenance

Git branch: `coord/cloud-codex`, directory `orchestrator/`. Retain this branch and protected `hosting/godaddy`. Never merge coordination-only records into application source merely to publish them.

Local readable mirror: `/Users/floriandittgen/orgcowrk/.agent-work/coordination/knowledge-base/`. The Git copy is portable; the local mirror and Mac-only evidence paths are not available to a cloud session.

Orchestrator owns decisions and this knowledge base. Reviewer alone edits the #2596 dispatch and migration ledger. Update CURRENT/EVIDENCE after material assignment, merge, migration or blocker changes. Add a timestamp and exact SHA; do not rewrite historical evidence as a current pass. Update metrics at handoff/failure/merge boundaries, without creating a recurring job. Fetch the latest file SHA before Git updates.

No tokens, passwords, certificates, raw credentials or private session transcripts belong here. Access to the repository remains necessary.
