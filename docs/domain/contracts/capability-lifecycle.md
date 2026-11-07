<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Capability lifecycle — stopping new work for a country without losing the work already admitted

## Baseline

- Source commit: 0e61749f2f0920a4117735bb416b98ce3919dc7e
- Refs: #3336 (provenance envelope, capability lifecycle, the connector guard split), #3335 (the attempt identity the provenance envelope hangs on), #3328 (the modular epic), #3331 (the capability resolver with explicit refusal)
- Canonical sources: `supabase/migrations/0595_accounting_connections.sql` (shared feature guard), `supabase/migrations/0636_accounting_delivery_in_flight.sql` (current twelve-argument delivery writer/in-flight rule), `docs/decisions/0045-a-closed-book-period-refuses-after-the-fact-changes.md` (closed periods), `supabase/migrations/0604_retention_disposition.sql` (retention holds), `docs/decisions/0043-features-can-be-available-by-country.md` (features by country), `e-invoice-transmission.md` (attempt identity)
- Required review: [#3336 implementation review](https://github.com/fdittgen-png/deskilo/issues/3336#issuecomment-6659781059). Its inventory, safeguards and cases remain acceptance requirements, mapped to L1–L15 below. Lifecycle/provenance rules are **proposed**, not implemented at this baseline; only rows marked held describe current enforcement.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| capability | one jurisdiction's or one target's way of producing a durable result: a VAT filing writer, an export format, an e-invoice channel, an accounting target | module id + implementation version |
| installed | the capability's code is present on this installation | a fact about the deployment, not a state the operator switches |
| operational state | whether the capability admits **new** work: `active`, `servicing`, `retired` | workspace/issuer/capability operation scope; installed code and resolver availability remain installation facts (D1) |
| qualification | the evidence that the capability was proven against its authority or provider | unchanged: the existing capability evidence model |
| durable result | an issued document, a filed return, an export handed over, a prepared transmission attempt | the existing business identity of each |
| provenance envelope | applicable producer/context facts: module/version, contract/input schema, rule revision/effective date, format, issuer/jurisdiction, source/artifact references and digests, business/attempt identity | freeze at the relevant production boundary; distinguish server-established from client-declared facts. Issuance cannot prove a later renderer/artifact; absent historical facts read `legacy_unknown` |
| admitted operation | work durably admitted while active, with its original context pinned, whose completion/recovery contract is not yet satisfied | the existing attempt or receipted-command identity; a replay does not create new admission |

Installed, operational state and qualification are three dimensions.
Conflating them is what makes a switch-off dangerous: the one feature
switch of 0595 gates reads, revocation and the delivery writer together,
so turning it off today blocks reading history and recording a final
outcome.

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one durable result, how many provenance envelopes? | one applicable record at its production boundary, for new results | later artifacts/deliveries carry linked provenance of their own; earlier results read `legacy_unknown`, without backfill |
| For one admission scope (workspace, issuer, capability), how many operational states? | exactly one at a time | the state changes by an attributable operator action |
| For one admitted operation, how many selected implementations per affected capability? | one pinned selection for each | issuance, rendering and transmission can have different producers; their context is retained |
| For one capability, how many admitted operations may be unresolved when it is retired? | none; retirement refuses until they resolve | servicing stays available; no force-retire path in this slice (D2) |
| For one workspace, how many capabilities for one country? | **open:** selection uniqueness needs its target/destination/environment scope (D5) | no universal one-active-per-country/kind constraint; preserve government/customer and environment distinctions |

## States and transitions

Declared states: `active`, `servicing`, `retired`.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | install and activate | installed; configuration authority; existing action-specific release/pilot requirements remain satisfied | `active` | new work eligible for admission under its existing feature, authority and qualification rules; activation waives none and adds no universal qualification gate |
| `active` | deactivate | operator authority | `servicing` | new operations refused with an explicit, capability-scoped refusal; admitted operations continue; reads, revocation and the recording of late outcomes allowed |
| `servicing` | reactivate | operator authority and the same applicable admission requirements | `active` | new operations admitted again; nothing historical is rewritten |
| `servicing` | retire | operator authority; no unresolved admitted work, checked atomically against admission (D2) | `retired` | retained artifacts readable; credentials revocable; no new work; refusal leaves servicing available |
| `retired` | reopen for servicing | owner decision, recorded with its reason | `servicing` | only to resolve an operation that was admitted before retirement; new operations stay refused |

**Slice 1 (accounting connectors, 0691).** Until the state table of the
lifecycle slice exists, the operational state of the accounting
connectors is *derived* from the existing feature choice: `accountingConnectors`
on is `active`; off is `servicing`. In `servicing`, new work is refused with
the unchanged `0A000` (opening a connection, a mapping, a token, preparing a
**new** delivery, an export that logs), while the following keep working under
their existing authority: reading connections and transfers, the manageable
check for revocation, revoking a connection (repeat-safe), and recording the
outcome of, or replaying, a delivery that was admitted while `active`.
`retired` and the reopen decision do not exist yet. Authority is never
relaxed by the state: `accounting_connector_member` is the actor check without
the feature, and every door still needs a signed-in native-token active member
with the right permission.

The proposed table excludes `retired` → `active` without
passing through `servicing` and a reviewed reactivation; any state →
anything that bypasses a closed period (ADR 0045) or a retention hold
(0604). Those are core rules, enforced regardless of the capability's
state.

## Invariants

| invariant | status | enforcement |
|---|---|---|
| a closed book period refuses after-the-fact changes, whatever the capability's state | held | ADR 0045, core |
| a retention hold is honoured, whatever the capability's state | held | 0604, core |
| a feature that is off refuses the client entry points | current defect | `feature_effective(…, 'accountingConnectors')` guards reads, revocation and the delivery writer alike in 0595; **this is the blocker #3336 splits** |
| only new operations depend on activation; servicing never relaxes authority | proposed | split admission from active membership, native-token, permission, issuer/workspace and revoked-credential checks; keep the latter on each applicable entry point |
| the server resolves and verifies the capability for a consequential operation; a client cannot select an older or more permissive ruleset by sending a version | proposed | the resolver of #3331 runs server-side; a client-supplied version is an input to verify, never a selector |
| within supported schema deployments, an incompatible capability command gets a scoped refusal | proposed | preserve compatible old calls and `lib/core/instance/schema_compatibility.dart`: newer-client/older-database blocking stays global; no schema-gate redesign |
| an admitted operation keeps its original context to its end | proposed | the attempt row of `e-invoice-transmission.md` carries provider, destination, environment and digest; the envelope adds the implementation that admitted it |
| deactivation never rewrites provenance | proposed | the envelope is written once, with the durable result; later states add facts, never replace them |
| a document issued under version 1 is unchanged after version 2 is deployed and version 1 is deactivated | proposed | the existing immutability (`invoices_no_mutation`) plus the envelope's `legacy_unknown` honesty for rows that predate it |

## Processing

- **Trigger and actor:** the operator changes the operational state from the capability's configuration; the owner alone reopens a retired capability for servicing.
- **Prerequisites:** installed; existing operator/action authority; retirement requires no unresolved admitted operation. Credentials revoked during servicing are not reusable.
- **Atomic effects:** state change and durable new-work admission share a serialization boundary: admission commits before deactivation or is refused afterward. Record actor/time; pin context at admission. An authorised replay returns its existing result without re-admission; a late outcome only updates its admitted attempt. State changes never stamp provenance.
- **Outcomes:** the new state, or an explicit refusal naming what blocks it (an unresolved operation, a missing authority).
- **External effects:** none from the state change itself. An admitted operation's external effect (an upload in flight) completes or resolves by its own contract.
- **Recovery:** servicing completes only previously admitted work under current authority, never arbitrary new issuance labelled correction. Use the explicitly authorised linked-document correction route. Unresolved work blocks retirement; history remains after revocation, but recovery cannot use revoked access. Historical provenance is never reconstructed.

Finite producer/consumer inventory from the required review; extend current definitions, never restate 0595 over later migrations. Issuance metadata stays outside the legal snapshot and under immutability; any snapshot digest follows final QRR freezing. Record renderer/artifact facts only at their production/receipt boundary, with declared metadata distinguished from verified hashes.

| boundary | existing entrypoints to extend | obligations |
|---|---|---|
| Invoice issuance | shared `invoice_legal_freeze` / `invoice_qrr_freeze` hook pattern across `create_invoice_receipted_v1`, `create_invoice_replacement_v1`, `settle_invoices_v1`, guest-pass `create_invoice` | L1, L10–L13 |
| Export and file delivery | `record_book_export_v1`, `record_file_deliveries_v1`; preserve legacy no-log/no-op/generation behaviour | L11, L12, L15 |
| Accounting preparation/finalization | current `record_accounting_delivery` through `databaseStore` and `deliverPeriod`, retaining 0636/defaulted arguments | L7, L10–L14 |
| Read/manage/admission | `accounting_connector_actor`, `accounting_connections_v1`, `accounting_transfers_v1`, `accounting_connection_manageable_v1`; new connections/mappings retain admission checks | L4, L6, L10, L13 |
| Revocation | `supabase/functions/accounting-connect/lifecycle.ts` → manageable → revoke → `record_accounting_revocation`; retain HMRC-specific contracts | L3, L13, L14 |
| E-invoice preparation/status | #3335's preparation writer and existing send/status gateway; no competing prepare writer | L2, L7, L11–L14; O1–O14 in the transmission contract |

## Evidence

Existing test sources to retain; this page is not a new execution receipt:

| rule | executed by |
|---|---|
| the delivery writer and its `in_flight` answer, with the connector feature on in the fixture | `supabase/tests/database/324_accounting_delivery_in_flight.sql` |
| a closed period refuses after-the-fact changes | the tests ADR 0045 names |
| an issued invoice cannot be edited or deleted | `supabase/tests/database/20_money_invariants.sql` |

Obligations the proposed rules derive:

| # | given / action | expected | oracle | layer |
|---|---|---|---|---|
| L1 | upgrade populated legacy data and a new v1-provenance invoice; deploy v2 and deactivate v1 | old signed fields, legal snapshot, signatures and retained artifact bytes unchanged; legacy provenance stays unknown and v1 facts stay v1 | compare named immutable fields/bytes, not whole-row JSON that gains columns | database upgrade plus artifact fixture |
| L2 | deactivate while a transmission is `sent` or becomes uncertain | original attempt completes or remains visibly unresolved; no automatic resend | same attempt/pinned context; no second upload | database transition plus injected-provider handler tests |
| L3 | revoke/repeat through the actual Edge endpoint while inactive | authorised local revocation succeeds; remote `revoked` / `failed` / `not_supported` remains truthful | manageable check, cleared secrets, revoked row and recorded remote outcome; no false remote success | lifecycle handler plus database tests |
| L4 | overlapping local ids in separate installations/workspaces; deactivate country A using a shared provider | no context leak; country B's capability remains usable | correct scoped records; B succeeds while new work in A refuses | database and handler scope fixtures |
| L5 | pinned previous supported client, compatible command, forged version selector and incompatible capability | compatible calls/readers work; server selects authoritative context; scoped refusal inside supported schema; existing global gate preserved | old-client fixture and explicit refusal keys, including unchanged behind/ahead schema behaviour | handler/client compatibility tests |
| L6 | read issued documents and receipts under `servicing` and `retired` | readable under the existing authority | the select succeeds for the permitted member and fails for others, as before | pgTAP |
| L7 | a late outcome recorded under `servicing` for an operation admitted under `active` | recorded on the original attempt | same attempt id; envelope unchanged | pgTAP |
| L8 | retire with unresolved work; resolve it and retry | first refuses with the operation named and servicing intact; second may retire | state and outstanding-operation set under the atomic guard | pgTAP |
| L9 | closed period/retention hold, later shorter rule, then deactivate | no permission to reopen, rewrite or erase follows from state | existing period and retention refusals remain; authorised reads still work | existing core tests extended to lifecycle states |
| L10 | new admission races deactivation; authorised receipted command replays afterward | ordered commit-before-deactivate or refusal; replay returns original result without new admission | controlled competing transactions; one existing business identity/provenance | two-session database test plus real entrypoint replay |
| L11 | every producer in the inventory creates a new durable result; positive QRR and credit/zero cases | truthful applicable context at each boundary; final QRR snapshot digest; no invented renderer identity | all named issuance paths, preparation/export records and retained artifacts | database hooks plus producer/handler fixtures |
| L12 | forged authoritative metadata or later mutation of provenance | derive/refuse forged authority; immutable facts cannot change | original fields/digests read back; declared client metadata never promoted to proof | database and receiving-handler tests |
| L13 | native authorised control vs ordinary/inactive/foreign-workspace/delegated actors across inventory; inactive new work and linked correction | existing access refusals persist; new connection/mapping/dispatch refuses; only the explicitly authorised linked correction route works | no forbidden history/artifact/credential/provider access or mutation; positive control succeeds | caller-role database tests and actual Edge entrypoints |
| L14 | revoke during unresolved work, then request recovery | history/uncertainty retained; recovery refuses revoked access | no provider call initiated by that recovery; no false completion | lifecycle and recovery handler tests |
| L15 | legacy export/file-delivery calls, repeated same digest and changed file | old no-log result, unchanged no-op and changed generation history retained | `logged: false` where applicable; original generation/artifact unchanged; no fabricated renderer proof | database and existing consumer tests |

## Open decisions

| # | decision | who |
|---|---|---|
| D1 | **resolved:** installation owns installed code/resolver availability; workspace/issuer/capability operation scope owns admission state | delegated design review: preserve workspace choices and avoid disabling another country using a shared provider |
| D2 | **resolved:** refuse retirement while admitted work is unresolved; leave servicing available; no force-retire path | delegated design review: bounded safe behaviour without stranded operations or a second servicing mechanism |
| D3 | the storage of the envelope: columns on each durable table, or one envelope table keyed by the durable result | the implementer, with the generated dictionary and the SQL contract in view |
| D4 | **resolved:** admission (`capability_admits`, shared advisory lock) guards a NEW accounting delivery identity and the connection actor's new-work checks; reading, managing, revoking, the outcome of admitted work and replay of an existing identity keep their own authority (0691, 0692; pgTAP 367, 368, 371, `capability_state_race.sh`, `receipted_replay_race.sh`). **The linked-document correction route (0695):** while the capability is `servicing` (not retired, feature on), `record_accounting_delivery` admits ONE new delivery: an invoice whose `replaces_invoice_id` (same workspace, enforced by key) points to an invoice with an `acknowledged` delivery on the SAME connection. Only the direct link counts (a chain needs each step acknowledged); the link is read from the invoice row, never from the request, so no label makes new issuance a correction; everything else keeps the unchanged `0A000`; the delivery's envelope records `linked_correction` and the replaced invoice (pgTAP 372). Invoice issuance itself is not gated by this capability | implementer/reviewer |
| D5 | exact capability selection/uniqueness key across kind, issuer, target, destination and environment, coordinated with #3331 | implementer under delegated design review; resolve before enforcing uniqueness, with government/customer and shared-provider cases |

## Stop condition

#3336 closes when L1–L15 and the linked review requirements are verified
through the inventoried entrypoints, D3–D5 are recorded, and new results
carry truthful provenance while legacy absence remains unknown. Its
e-invoice portion depends on #3335; the bounded accounting guard split can land earlier. Country-package extraction (#3332, #3333), the provider
adapters behind gateways (#3337) and the removability suite (#3338)
stay in their own issues.
