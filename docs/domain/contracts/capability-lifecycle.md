<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Capability lifecycle — stopping new work for a country without losing the work already admitted

## Baseline

- Source commit: 010b6dfea01b1e15609c7d057d018a3eb7455fc2
- Refs: #3336 (provenance envelope, capability lifecycle, the connector guard split), #3335 (the attempt identity the provenance envelope hangs on), #3328 (the modular epic), #3331 (the capability resolver with explicit refusal)
- Canonical sources: `supabase/migrations/0595_accounting_connections.sql` (every accounting-connector entry point is gated on one feature switch today), `docs/decisions/0045-a-closed-book-period-refuses-after-the-fact-changes.md` (closed periods are core-enforced), `supabase/migrations/0604_retention_disposition.sql` (retention holds), `docs/decisions/0043-features-can-be-available-by-country.md` (features by country), `e-invoice-transmission.md` (the attempt whose late outcome must still be recordable)
- Existing review: the body of #3336 already states the lifecycle table; this page adds the identity, the coupling rules and the evidence map, nothing else.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| capability | one jurisdiction's or one target's way of producing a durable result: a VAT filing writer, an export format, an e-invoice channel, an accounting target | module id + implementation version |
| installed | the capability's code is present on this installation | a fact about the deployment, not a state the operator switches |
| operational state | whether the capability admits **new** work: `active`, `servicing`, `retired` | per workspace (or per installation; open decision D1) |
| qualification | the evidence that the capability was proven against its authority or provider | unchanged: the existing capability evidence model |
| durable result | an issued document, a filed return, an export handed over, a prepared transmission attempt | the existing business identity of each |
| provenance envelope | which implementation produced a durable result: module id and version, contract and input-schema version, rule revision and effective date, format version, issuer and jurisdiction context, source snapshot and digest, artifact and digest, the business and attempt identity | recorded with the durable result at the moment it becomes durable; **proposed**, new results only; existing rows read `legacy_unknown` |
| admitted operation | work that began while the capability admitted it, and has not reached its final outcome | the attempt or job identity it carries |

Installed, operational state and qualification are three dimensions.
Conflating them is what makes a switch-off dangerous: the one feature
switch of 0595 gates reads, revocation and the delivery writer together,
so turning it off today blocks reading history and recording a final
outcome.

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one durable result, how many provenance envelopes? | exactly one, for results created after the migration | earlier results carry `legacy_unknown`; no historical version is invented |
| For one capability in one workspace, how many operational states? | exactly one at a time | the state changes by an attributable operator action |
| For one admitted operation, how many capabilities? | exactly one, the one that admitted it | it keeps that context to its end, whatever the state becomes meanwhile |
| For one capability, how many admitted operations may be unresolved when it is retired? | **proposed:** none — retirement waits, or the servicing path is retained | open decision D2 |
| For one workspace, how many capabilities for one country? | at most one `active` per kind | two active e-invoice channels for one country would be two mandates; the resolver refuses explicitly rather than falling back (#3331) |

## States and transitions

Declared states: `active`, `servicing`, `retired`.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | install and activate | the capability is installed; the operator holds the configuration authority; qualification is whatever the evidence model says, recorded, not required for activation | `active` | new operations admitted; reads, revocation and resolution allowed |
| `active` | deactivate | operator authority | `servicing` | new operations refused with an explicit, capability-scoped refusal; admitted operations continue; reads, revocation and the recording of late outcomes allowed |
| `servicing` | reactivate | operator authority | `active` | new operations admitted again; nothing historical is rewritten |
| `servicing` | retire | operator authority; no admitted operation is unresolved, or the servicing path for those is retained (D2) | `retired` | retained artifacts readable under the existing authority; credentials revocable; no new operation; a late outcome needs the retained servicing path |
| `retired` | reopen for servicing | owner decision, recorded with its reason | `servicing` | only to resolve an operation that was admitted before retirement; new operations stay refused |

Transitions that do not exist, by decision: `retired` → `active` without
passing through `servicing` and a reviewed reactivation; any state →
anything that bypasses a closed period (ADR 0045) or a retention hold
(0604). Those are core rules, enforced regardless of the capability's
state.

## Invariants

| invariant | status | enforcement |
|---|---|---|
| a closed book period refuses after-the-fact changes, whatever the capability's state | held | ADR 0045, core |
| a retention hold is honoured, whatever the capability's state | held | 0604, core |
| a feature that is off refuses the client entry points | held — too broadly | `feature_effective(…, 'accountingConnectors')` guards reads, revocation and the delivery writer alike in 0595; **this is the blocker #3336 splits** |
| only new operations depend on the operational state; reads, revocation and the recording of an admitted operation's outcome do not | proposed | the guard split: one predicate for admission, none (beyond the existing row-level and permission rules) for reads, revocation and resolution |
| the server resolves and verifies the capability for a consequential operation; a client cannot select an older or more permissive ruleset by sending a version | proposed | the resolver of #3331 runs server-side; a client-supplied version is an input to verify, never a selector |
| a stale client receives an explicit compatibility refusal for the affected capability only | proposed | the refusal names the capability; other capabilities and countries are unaffected |
| an admitted operation keeps its original context to its end | proposed | the attempt row of `e-invoice-transmission.md` carries provider, destination, environment and digest; the envelope adds the implementation that admitted it |
| deactivation never rewrites provenance | proposed | the envelope is written once, with the durable result; later states add facts, never replace them |
| a document issued under version 1 is unchanged after version 2 is deployed and version 1 is deactivated | proposed | the existing immutability (`invoices_no_mutation`) plus the envelope's `legacy_unknown` honesty for rows that predate it |

## Processing

- **Trigger and actor:** the operator changes the operational state from the capability's configuration; the owner alone reopens a retired capability for servicing.
- **Prerequisites:** installed; the operator authority; for retirement, no unresolved admitted operation or the retained servicing path.
- **Atomic effects:** the state row changes with actor and time; nothing else is written. The envelope is written by the operation that produces a durable result, at the moment it becomes durable, never by the state change.
- **Outcomes:** the new state, or an explicit refusal naming what blocks it (an unresolved operation, a missing authority).
- **External effects:** none from the state change itself. An admitted operation's external effect (an upload in flight) completes or resolves by its own contract.
- **Recovery:** a state change is reversible through the table above; a late outcome of an admitted operation is recorded through the servicing path; provenance is never reconstructed for rows that predate the envelope — they stay `legacy_unknown`.

## Evidence

Executed today, to keep:

| rule | executed by |
|---|---|
| the delivery writer and its `in_flight` answer, with the connector feature on in the fixture | `supabase/tests/database/324_accounting_delivery_in_flight.sql` |
| a closed period refuses after-the-fact changes | the tests ADR 0045 names |
| an issued invoice cannot be edited or deleted | `supabase/tests/database/20_money_invariants.sql` |

Obligations the proposed rules derive:

| # | given / action | expected | oracle | layer |
|---|---|---|---|---|
| L1 | an invoice issued under version 1; deploy version 2; deactivate version 1 | the invoice is byte-equal, its envelope says version 1 | the populated-upgrade comparison, extended to the envelope columns | database CI |
| L2 | deactivate while a transmission attempt is `sent` | the attempt reaches `accepted` or `rejected`, or stays `uncertain` and visible; it is never silently lost | the attempt row after the state change; no second upload | pgTAP with the attempt fixture of `e-invoice-transmission.md` |
| L3 | revoke credentials after deactivation | revocation succeeds | the credential row; the state unchanged | pgTAP |
| L4 | deactivate country A | country B's capabilities admit new work unchanged | an operation in B succeeds; one in A is refused with A's capability named | pgTAP |
| L5 | a stale client sends a version selector for a consequential operation | the server ignores the selector as authority and verifies against its own resolution; a mismatch is an explicit compatibility refusal | the operation's outcome and the refusal key | handler test |
| L6 | read issued documents and receipts under `servicing` and `retired` | readable under the existing authority | the select succeeds for the permitted member and fails for others, as before | pgTAP |
| L7 | a late outcome recorded under `servicing` for an operation admitted under `active` | recorded on the original attempt | same attempt id; envelope unchanged | pgTAP |
| L8 | retire with an unresolved admitted operation | refused naming the operation, or admitted with the retained servicing path (D2) | the state unchanged or the retained path present | pgTAP |
| L9 | any state; an operation inside a closed period or under a retention hold | refused by the core rule | the existing refusals of ADR 0045 and 0604 | existing tests, re-run against each state |

## Open decisions

| # | decision | who |
|---|---|---|
| D1 | whether the operational state is per workspace or per installation; the body of #3336 reads per workspace, the resolver of #3331 is per installation | owner |
| D2 | retirement with an unresolved admitted operation: refuse, or retain a servicing path for that operation only | owner — it decides whether an operator can ever be stuck |
| D3 | the storage of the envelope: columns on each durable table, or one envelope table keyed by the durable result | the implementer, with the generated dictionary and the SQL contract in view |
| D4 | which existing predicates become the admission predicate and which lose the guard; the split is per entry point of 0595 | the implementer, listed in the pull request |

## Stop condition

#3336 closes when L1–L9 are executed, the guard of 0595 is split so that
only admission depends on the operational state, and the provenance
envelope is written for new durable results with `legacy_unknown` on
the rest. Country-package extraction (#3332, #3333), the provider
adapters behind gateways (#3337) and the removability suite (#3338)
stay in their own issues.
