<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Domain contracts — the meaning of a rule, next to what enforces it

`../INVARIANTS.md` lists the business rules one row at a time, each with
its enforcement and its test. Some rules do not fit a row: they span
data, time, authority, concurrency and a third party at once — a
document that may or may not have left for a government platform, a
country capability being switched off while a submission is in flight.
Those get a **contract page** here (ADR 0048).

A contract page is written **before** the behaviour changes and is the
part of the issue that survives it. It is short. It explains business
meaning; it does not repeat the schema — the schema has its own
representation (`docs/ci/SQL_CONTRACT.md`, the generated dictionary) and
repeating it here would be a second copy to keep true.

## What a page holds, and why in that order

| section | answers |
|---|---|
| Baseline | the commit the page was checked against, the issues it serves, the canonical sources it summarises |
| Concepts and identity | the business things involved, and what makes two of them *the same one* — the scope of every "at most once" rule |
| Relationships and cardinalities | who owns what, what is optional, which lifecycle qualification bends the rule (a reservation keeps its history after its seat is deleted) |
| States and transitions | the declared states, then every transition as *from · event · guard · to · effects* — the processing rule in one table |
| Invariants | what must hold across all of the above, each marked *held today* or *proposed*, with its enforcement point |
| Processing | trigger and actor, prerequisites, atomic effects, outcomes, external effects and how an unknown outcome is recovered |
| Evidence | the tests that execute the held rules, and the obligations the proposed rules derive — each with its oracle, not only its label |
| Open decisions | what the page could not settle, and who settles it |
| Stop condition | where the change ends |

### Two views, kept apart

The page states the **conceptual** rule in plain words ("one logical
transmission is one invoice to one destination in one environment
through one provider"). Under it, an **implementation mapping** names
the actual function, column, constraint and test that realise it. A
reader who wants the meaning stops at the first; a reader who wants to
change it continues to the second. Mixing the two produced the
booking-example mistakes this convention was adopted to avoid: a model
that was internally consistent and wrong about the product.

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

`test/lint/domain_contract_test.dart` checks required headings, full commit
hash and issue-reference syntax, five nonempty transition cells, declared states,
and backticked repository-root or peer Markdown paths (`page.md` or `./page.md`).
It checks file existence, not symbols, anchors, commit existence or test
results. Semantic correctness and a code change's contract impact stay
with the review and the tests the Evidence section names.

## Three safeguards

1. **Current is not correct.** A rule extracted from the code documents
   what exists. A proposed rule names the issue or decision it comes from.
2. **Read the implementation before changing it.** The page points at
   the functions and tests; it does not replace reading them.
3. **The page is revised by evidence.** When implementation contradicts
   it, the page changes in the same pull request, and the change is
   reviewed as a decision, not as a typo.
