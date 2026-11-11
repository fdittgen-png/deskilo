<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Domain contracts — the meaning of a rule, next to what enforces it

`../INVARIANTS.md` lists the business rules one row at a time, each with
its enforcement and its test. Some rules do not fit a row: they span
data, time, authority, concurrency and a third party at once — a
document that may or may not have left for a government platform, a
country capability being switched off while a submission is in flight.
Those get a **contract page** here (ADR 0048).

A contract page states the rule that holds on master. It is updated in the pull request that changes the behaviour; the proposal, its open decisions, its obligations and its stop condition live in the issue (the checkpoint template's Contract reference and delta, Acceptance and tests and Done when). The page is short. It explains business
meaning; it does not repeat the schema — the schema has its own
representation (`docs/ci/SQL_CONTRACT.md`, the generated dictionary) and
repeating it here would be a second copy to keep true.

## What a page holds, and why in that order

| Section | Meaning |
|---|---|
| Baseline | The issues served and canonical sources summarized; no pinned source commit |
| Concepts and identity | Concepts and their identity scope |
| Relationships and cardinalities | Ownership, optionality and lifecycle qualifications |
| States and transitions | Declared states and the existing five-column transition table |
| Invariants | Rules that hold, with their enforcement point |
| Processing | Trigger/actor, guards, atomic/external effects and recovery |
| Evidence | Executable tests for the rules; explicitly identify a rule with no test |

### Two views, kept apart

The meaning, question and invariant columns state the **conceptual**
rule in plain words ("one logical transmission is one invoice to one
destination in one environment through one provider"). The identity,
qualification and enforcement columns map it to the implementation: the
actual function, column, constraint and test that realise it. A reader
who wants the meaning stops at the first; a reader who wants to change it
continues to the second. Mixing the two produced the booking-example
mistakes this convention was adopted to avoid: a model that was
internally consistent and wrong about the product.

### Cardinalities are questions, not arrows

Arrow and bracket notations are read two ways by two readers. Write the
question and its answer:

| question | answer |
|---|---|
| For one transmission attempt, how many invoices? | exactly one |
| For one issued invoice, how many attempts? | none or more — it is a log, not a state column |

Qualify by lifecycle where the answer changes over time: *at creation*
versus *as history*.

### A state table is the processing model

`from · event · guard · to · effects` is enough for the rules this
repository has needed. A diagram is welcome when it helps a reader; it
is never the only form, because the lint reads the table.
Use five nonempty cells with leading/trailing pipes and optional alignment.
Write `always` for an unconditional guard and `none` for no effects.

## When a page is required

Keep a simple or static rule in its invariant row. Use a page for a
complex lifecycle whose states, guards, concurrency or recovery need
more space, and update affected sections when behaviour changes.
Risk sets assurance under `docs/AGENT_RULES.md`: an index-only change
needs no contract edit; an authorisation change may need no schema edit.

| change | contract impact |
|---|---|
| wording, formatting, a presentation change on an unchanged rule | none; cite the page where it helps |
| a relationship, identity, cardinality or business value | Concepts / Relationships / Invariants delta |
| a lifecycle, guard, retry or external effect | States / Processing delta |
| authority, money, a destructive operation, a submission to a third party | every affected section, with explicit concurrency and recovery where applicable; existing review and authority rules apply |

The issue carries the **delta**; the row or page carries the **result**
in the behaviour's pull request. An unchanged contract is cited with
a reason; where no business rule is affected, say why. The checkpoint's
existing owner maintains the rule and coordinates its consumers.

Record each decision, reason and authority on the issue: implementer,
existing owner delegation, or a reserved owner action under
`docs/AGENT_RULES.md`. Delegation is not independent review.

## What the lint checks, and what it cannot

`test/lint/domain_contract_test.dart` checks the seven required headings
(and that this README's section table lists exactly those, in that order),
a `- Refs:` list item naming an issue, five nonempty transition cells,
declared states, and backticked repository-root or peer Markdown paths
(`page.md` or `./page.md`). It refuses proposal text on a page: an
`## Open decisions` or `## Stop condition` heading, a `- Source commit:`
line, and the whole word `proposed`. It does not scan this README or the
ADRs, which explain proposals. It checks file existence, not symbols,
anchors or test results, and it does not prove a rule is right or that a
cited test passed. Semantic correctness and a code change's contract
impact stay with the review and the tests the Evidence section names.
A page listed in the lint's `_unreconciled` set is exempt from the
proposal check only, until its own reconciliation removes it; the set only
shrinks.

## Three safeguards

1. **Current is not correct.** A rule extracted from the code documents
   what exists. A proposed change belongs to its issue, not to the page.
2. **Read the implementation before changing it.** The page points at
   the functions and tests; it does not replace reading them.
3. **The page is revised by evidence.** When implementation contradicts
   it, the page changes in the same pull request, and the change is
   reviewed as a decision, not as a typo.
