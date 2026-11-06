# ADR 0048 — A rule that spans data, time, authority and a third party gets a contract page beside the invariants

**Status:** proposed · **Date:** 2026-11-06 · **Refs:** #3335, #3336, #3328

## Context
`docs/domain/INVARIANTS.md` (#1248) lists each business rule with what
enforces it and which test executes it. That works for a rule that fits
one row. Two open issues do not fit: #3335 (a document that may or may
not have left for a government platform) and #3336 (a country capability
switched off while a submission is in flight). Each spans a data model,
a lifecycle, an authority rule, a concurrency rule and a recovery rule,
and each already had a long review comment restating the same facts in
prose, in a place the lint cannot read and the next issue cannot cite.

The alternatives considered:

1. **A global conceptual model** of the whole product (entities,
   cardinalities, every state machine) that every schema or state change
   must edit. Rejected: it concentrates unrelated edits in one file, it
   repeats what `docs/ci/SQL_CONTRACT.md` and the generated dictionary
   already say about the physical schema, and the dictionary refresh
   workflow exists precisely to keep that kind of file off the migration
   pull request.
2. **Keep it in the issue.** Rejected: the issue is mutable and closes;
   the next change to the same rule starts from zero.
3. **One page per rule that needs it**, written before the behaviour
   changes, updated in the same pull request, lint-checked for shape
   only. Chosen.

## Decision
1. A contract page lives in `docs/domain/contracts/`, with the sections
   its `README.md` defines: baseline, concepts and identity,
   relationships and cardinalities, states and transitions, invariants,
   processing, evidence, open decisions, stop condition.
2. It states the **conceptual** rule in plain words and, under it, the
   **implementation mapping** — the function, column, constraint and
   test. The physical schema is not repeated.
3. A page is required when a change alters a business relationship, an
   invariant, an authority rule, a lifecycle transition or an externally
   observable effect. The issue carries the delta; the page carries the
   result, in the same pull request. A refactor states "contract
   unchanged".
4. Risk and modelling stay separate: the risk tier decides the review
   and the evidence; the kind of change decides which section moves.
5. `test/lint/domain_contract_test.dart` refuses a page that cannot be
   checked — a missing section, a transition naming an undeclared
   state, a path that no longer exists, a baseline without a full
   commit — and nothing more. Whether a rule is right stays with the
   review (ADR 0040: project rules stay lint tests).
6. The first page is the e-invoice transmission (#3335). The second is
   the capability lifecycle (#3336). No existing issue is rewritten.

## Consequences
- An issue that changes one of these rules is reviewed against a stated
  set instead of a trigger nobody reads — the same reason the invoice
  transitions were written out in `INVARIANTS.md`.
- The evidence section lists obligations with their oracle. A list of
  outcome labels is not a test plan: two concurrent requests can both
  answer *success* and still break the one-in-flight rule.
- A page is a claim about today only where it says *held*; *proposed*
  rows name the issue they come from. A page is not proof.
- If no third page is wanted within a few cycles, the convention is
  still cheap: two pages and one lint test.
