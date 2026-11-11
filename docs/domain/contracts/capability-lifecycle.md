<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Capability lifecycle — stopping new work for a capability without losing the work already admitted

## Baseline

- Refs: #3336 (provenance envelope, capability lifecycle, the connector guard split), #3335 (the transmission identity the provenance envelope hangs on), #3328 (the modular epic), #3331 (the capability resolver with explicit refusal)
- Canonical sources: `supabase/migrations/0691_accounting_servicing_guard.sql` (admission of new work split from reading, managing and revoking), `supabase/migrations/0692_capability_states.sql` (the stored operational state, the admission test, the transitions), `supabase/migrations/0693_provenance_envelopes.sql` (the envelope table, its registry and writer, the producer hooks), `supabase/migrations/0694_transmission_envelope.sql` (the transmission envelope, the clipped declaration, the local rule day), `supabase/migrations/0695_linked_correction.sql` (the linked-document correction route), `docs/decisions/0043-features-can-be-available-by-country.md` (features by country), `docs/decisions/0045-a-closed-book-period-refuses-after-the-fact-changes.md` (closed periods), `supabase/migrations/0604_retention_disposition.sql` (retention holds), `supabase/migrations/0595_accounting_connections.sql` (the connector feature guard that 0691 and 0692 refine), `e-invoice-transmission.md` (the transmission identity)
- Design review: [#3336 implementation review](https://github.com/fdittgen-png/deskilo/issues/3336#issuecomment-6659781059). Its inventory and case table are the Writers and readers and Evidence sections below, L1 to L15.

The lifecycle described here is the accounting connectors' lifecycle. It is
not a universal lifecycle of every jurisdiction module: the state table
accepts the capability key `accountingConnectors` and no other.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| installed | the capability's code and registry entry are present on this installation | a fact about the deployment, not a state anyone switches |
| operational state | whether the accounting connectors admit **new** work: `active`, `servicing`, `retired` | one `capability_states` row per workspace and capability key, primary key `(workspace_id, capability_key)`. The state is per workspace and capability, not per issuer, country, provider, destination or environment: the workspace's separate connections share it |
| default state | the state when no row exists | derived: feature on reads `active`, feature off reads `servicing`. The first row is optional, and installing is not a stored transition |
| qualification | the evidence that a capability was proven against its authority or provider | a separate dimension: the state table does not consult or grant it |
| durable result | an issued invoice, a book export, a file delivery, an accounting delivery, a transmission | the existing business identity of each |
| provenance envelope | how a durable result was produced: module, version, input schema, rule revision, issuer context, declared client metadata, artifact digests | one `provenance_envelopes` row keyed `(result_kind, result_id)`, written at the result's production boundary. Kinds: invoice, book_export, file_delivery, accounting_delivery, transmission |
| admitted operation | a delivery whose identity was created while the capability admitted new work | the delivery's `identity_key`; a replay finds it and creates nothing |

Installed, operational state and qualification are three dimensions. The
state decides only whether **new** work is admitted; authority, reading,
revocation and the outcome of admitted work keep their own checks.

Provenance has two sources. `provenance_modules()` is the registry of what
produces what, and `record_provenance` resolves the authoritative module,
version and input schema from it. What a client says about its renderer is
kept apart in `declared`: only the keys `renderer`, `renderer_version`,
`app_version` and `format` survive, only as strings clipped to 120
characters (0694), and a declaration larger than 4096 bytes is refused. A
declaration is not evidence that a renderer ran or that an artifact
exists. A result with no envelope reads `legacy_unknown`; nothing is
reconstructed or backfilled. The server-side source of provenance is the
SQL registry and its producer hooks.

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one durable result, how many provenance envelopes? | one for a new result, none for a legacy one | written once with the result; `legacy_unknown` when absent |
| For one workspace and capability, how many operational states? | at most one stored row, and exactly one effective state | the table key is `(workspace_id, capability_key)`; there is no further one-active-per-country or per-provider constraint |
| For one workspace, how many connections share the state? | all of them | each connection keeps its own issuer site, target and credentials; a delivery identity names them |
| For one e-invoice transmission, how many envelopes? | one | written by `prepare_einvoice_v1` on the insert only; its destination and environment identity is the transmission's own (`e-invoice-transmission.md`) |
| For one workspace with several countries' work, how is a country stopped? | each country is its own workspace | the shared-provider case is two workspaces on one provider: stopping one leaves the other working |

## States and transitions

Declared states: `active`, `servicing`, `retired`.

Unknown keys and unknown states are refused (SQLSTATE 22023), and so is a
direct change between `active` and `retired`. Every transition is made by
`set_capability_state_v1`, which takes the exclusive capability lock.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | read | no stored row; `capability_states_v1` | *(derived: `active` with the feature on, `servicing` with it off)* | nothing is stored; a derived default, not an install-and-activate step |
| `active` | deactivate | a signed-in native-token active member holding `manageBilling` (`accounting_connector_member`) | `servicing` | the row stores the state, the reason, the member and the time; new work is refused |
| `servicing` | reactivate | the same authority, and the feature is on; with it off the answer is SQLSTATE 0A000 | `active` | new work is admitted again; nothing historical is rewritten |
| `servicing` | retire | the owner, a nonblank reason, and no generated or sent delivery on a nonrevoked connection | `retired` | a failure leaves the state unchanged and names the count |
| `retired` | reopen | the owner and a nonblank reason | `servicing` | new work stays refused until the separate, permitted reactivation |
| *(current state)* | repeat | the requested state equals the effective one | *(unchanged)* | answer `changed: false`; attribution and history are not rewritten |

The retirement count is the deliveries in status `generated` or `sent` whose
connection has no `revoked_at`. Deliveries in `failed` or `conflict`, and any
delivery on a revoked connection, do not block it: in servicing none of them
can be relinked, sent again or settled.

Admission and state change use the same lock key (`capability_lock_key`):
`capability_admits` takes the shared transaction advisory lock and
`set_capability_state_v1` the exclusive one. An admission therefore commits
before a deactivation, or waits for it and observes the changed state and
refuses. This is stated for these two named functions; every other way to
change the feature choice is outside this guarantee.

## Invariants

| invariant | enforcement |
|---|---|
| a feature that is off admits nothing, whatever the stored row says | `capability_admits` tests `feature_effective` and the stored state together |
| only new work depends on the state; authority is never relaxed | `accounting_connector_member` checks identity, active membership, native token and the purpose permission without the state; `accounting_connector_actor` and `capability_admits` guard new work; read, manage and revoke keep their own authority |
| admitted work completes under servicing | `record_accounting_delivery` asks for admission only when no delivery of that identity exists; an existing identity records its outcome and replays whatever the state says |
| a revoked credential never becomes usable again | a revoked or not connected connection cannot create a delivery (SQLSTATE 23514); the revocation check runs with purpose `revoke` |
| a closed book period refuses after-the-fact changes, whatever the capability's state | ADR 0045, core; a state grants no exception |
| a retention hold is honoured, whatever the capability's state | `supabase/migrations/0604_retention_disposition.sql`, core; a state grants no exception |
| provenance is written once and never changed | `provenance_envelopes_immutable` refuses update and delete, except the delete that follows the deletion of its workspace; `record_provenance` inserts once (`on conflict do nothing`) |
| a state change never restamps a historical envelope | no transition touches `provenance_envelopes` |
| a client cannot select the module or version that produced a result | `record_provenance` reads them from `provenance_modules()`; the client's declaration stays in `declared` |
| invoice provenance is stamped after the legal snapshot and the quick-response reference are frozen | `invoice_provenance_stamp` is an after-insert trigger on `invoices`; issuance and the later rendering or transmission are different boundaries |
| an issued invoice is immutable | `invoices_no_mutation` (`supabase/migrations/0060_invoices.sql`) |
| schema compatibility stays global | `lib/core/instance/schema_compatibility.dart` blocks a newer client on an older database; a capability refusal is the existing 0A000 within a supported schema |

## Processing

- **Trigger and actor:** a manager with `manageBilling` deactivates, reactivates and reads the state; only the owner retires or reopens. Retirement and reopening need a nonblank reason, stored up to 300 characters.
- **Admission:** a new accounting delivery identity, and the connection actor's new-work checks, ask `capability_admits`. It refuses with the unchanged 0A000. An authorised replay returns the existing delivery and does not ask again.
- **Atomic effects:** the state change and the admission test serialize on the capability lock; the actor and the time are recorded with the state. A late outcome only updates its admitted record.
- **Outcomes:** the new state, or a refusal naming what blocks it (an unresolved delivery count, a missing authority, the feature being off).
- **External effects:** none from the state change itself. An admitted operation's external effect completes or resolves by its own contract.
- **Provenance boundaries:** the invoice envelope is stamped by the trigger after the frozen snapshot and uses the workspace's local issue day (`book_local_day`) for its rule provenance. Book exports, file deliveries and accounting deliveries write theirs at their first durable boundary; a transmission writes its at preparation. Later outcomes and state changes add facts elsewhere and never replace an envelope.
- **Linked correction:** While stored state is servicing and the feature is on, one new accounting delivery may carry an invoice whose direct replaces_invoice_id names an invoice acknowledged on that same connection in the same workspace. The link comes from the invoice row, never the request. Retired or feature-off refuses it; replay returns the existing identity. (`capability_linked_correction` called by `record_accounting_delivery`, 0695.)
- **Chains and issuance:** a chain needs each preceding invoice acknowledged. Invoice issuance itself is not governed by this accounting-connector switch. The delivery's envelope records `linked_correction` and the replaced invoice.
- **Recovery:** servicing completes only previously admitted work under current authority. Unresolved work blocks retirement. History stays readable after revocation, but recovery cannot use revoked access. Historical provenance is never reconstructed.

### Writers and readers

The existing writers and readers of the lifecycle and of provenance.

| boundary | existing writers and readers | evidence |
|---|---|---|
| Invoice issuance | the after-insert `invoice_provenance_stamp` on `invoices`, reached through `create_invoice_receipted_v1`, `create_invoice_replacement_v1`, `settle_invoices_v1` and the guest-pass `create_invoice` | L1, L10 to L13 |
| Export and file delivery | `record_book_export_v1`, `record_file_deliveries_v1`; a space that keeps neither periods nor transfers logs nothing | L11, L12, L15 |
| Accounting preparation and outcome | `record_accounting_delivery` through `databaseStore` and `deliverPeriod` in the Edge function | L7, L10 to L14 |
| Read, manage and admission | `accounting_connector_actor`, `accounting_connections_v1`, `accounting_transfers_v1`, `accounting_connection_manageable_v1`, `capability_states_v1`, `provenance_envelope_v1` | L4, L6, L10, L13 |
| Revocation | `supabase/functions/accounting-connect/lifecycle.ts`: manageable check, revoke, `record_accounting_revocation` | L3, L13, L14 |
| E-invoice preparation and status | `prepare_einvoice_v1` and the existing send and status gateway | L2, L7, L11 to L14 |

## Evidence

A path below is source-level test coverage, not a record that a run passed. Where an obligation is broader than the assertions, the covered part is stated.

| # | rule | executed by |
|---|---|---|
| L1 | a legacy invoice and a new envelope keep their signed fields, snapshot and retained bytes when a later version is deployed | `supabase/tests/database/371_lifecycle_evidence.sql`: legacy invoice, v1 envelope against v2, signed fields, snapshot and retained bytes unchanged. A populated fixture, not a replay of the full historical migration chain |
| L2 | a late e-invoice outcome under servicing completes the admitted transmission and nothing is resent | `supabase/tests/database/370_transmission_envelope.sql`: a late outcome after an accounting servicing state is inserted; the envelope is unchanged. Uncertain and no-resend behaviour: `supabase/functions/send-e-invoice/handler_test.ts`. There is no separate e-invoice-channel deactivation state |
| L3 | revocation and its repeat succeed locally while the feature is off, and the remote result stays truthful | `supabase/tests/database/367_accounting_servicing_guard.sql`: revoke and repeat with the feature off; `supabase/functions/accounting-connect/lifecycle_test.ts`: the revoke handler's purpose check, the local and remote result distinction, denied actors |
| L4 | one workspace's state does not leak into another that shares a provider or a document id | pgTAP 371: two workspaces sharing a provider and document id; `supabase/tests/database/368_capability_states.sql`: separate workspace state. This is workspace isolation, not proof of two physical installations |
| L5 | the current reader falls back honestly, the schema gate is unchanged, and a forged declaration cannot select the authoritative version | `test/features/money/capability_lifecycle_compat_test.dart`: the current reader's fallback, the unchanged schema gate and the 0A000 refusal; pgTAP 371: a forged declaration. A current-class unit test is not an execution of a pinned historical build |
| L6 | history and transfers stay readable under servicing and retired, and refused to others | pgTAP 367: history and transfer reads with denied actors while the feature is off; pgTAP 368: history under retired; `supabase/tests/database/369_provenance_envelopes.sql`: the envelope reader and a foreign-workspace control. These cover what they read, not a full state-by-role matrix over every invoice and receipt reader |
| L7 | a late outcome and a replay land on the admitted record | pgTAP 367 and 368: an admitted accounting outcome and replay; pgTAP 369: the envelope fixed across outcome and replay; pgTAP 370: a late e-invoice outcome under servicing |
| L8 | retirement is refused while a delivery is unresolved, and succeeds after | pgTAP 368: the refusal, the resolution and the retirement, failed and revoked rows not blocking, illegal transitions, the owner and reason requirements |
| L9 | a retired state cannot bypass a closed book period or a retention hold | pgTAP 371: the closed-period and retention-hold refusals under a retired state |
| L10 | admission racing deactivation is ordered, and a replay returns the original | `scripts/capability_state_race.sh`: competing admission and state transactions; `scripts/receipted_replay_race.sh`: a real receipted command race and replay; pgTAP 371: a replay keeps one invoice and one envelope |
| L11 | every producer writes its envelope at its boundary | pgTAP 369: invoice, quick-response reference, zero amount, and the export, file-delivery and accounting producer hooks; pgTAP 370: the transmission and the local-day provenance; pgTAP 371: the receipted invoice path. The replacement, settlement and guest-pass entrypoints are not each executed by these envelope tests |
| L12 | provenance is insert-only and forged authoritative fields are refused or ignored | pgTAP 369: insert-only, no second write, forged authoritative fields; pgTAP 370: the declared allow-list and immutability; pgTAP 371: a forged selector; the send handler tests for the clipping of declared values |
| L13 | authority persists under servicing, and the linked correction is the only new-work exception | pgTAP 367 and 368: caller authority and stopped admission; `supabase/tests/database/372_linked_correction.sql`: the permitted direct correction, and the refusals for a wrong connection, an unacknowledged original, no link, the feature off and retired; the existing Edge lifecycle and delivery tests for denied actors. The claim is scoped to those cases |
| L14 | recovery on a revoked connection makes no provider call | `supabase/functions/accounting-connect/deliver_test.ts`: a revoked recovery makes no provider call, no refresh and no delivery write; pgTAP 367: an old connection's replay and relink distinctions |
| L15 | legacy export and file-delivery calls keep their results | pgTAP 369: an old export signature, and an unchanged and a changed digest generation; `supabase/tests/database/234_book_periods.sql`: the existing `logged: false` behaviour; `supabase/tests/database/299_accounting_connections.sql`: legacy file-delivery outcomes. No renderer is proven |

pgTAP 367, 368, 369, 370, 371 and 372 are the files `367_accounting_servicing_guard.sql` through `372_linked_correction.sql` under `supabase/tests/database/`.
