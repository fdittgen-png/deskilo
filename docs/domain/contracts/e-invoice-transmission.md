<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# E-invoice transmission — a document that may have left is worse than one that failed

## Baseline

- Refs: #3335 (prepare before send, idempotent retry, uncertain outcome), #3336 (provenance and capability lifecycle, which hangs on this transmission's identity), #2358 (the national channels), #3328 (the modular epic)
- Canonical sources: `docs/decisions/0010-e-invoice-transmission.md` (the app produces the document, a provider transmits it), `supabase/migrations/0071_einvoice_transmission.sql` (the transmission log), `supabase/migrations/0414_einvoice_channels.sql` (format, receipt), `supabase/migrations/0689_einvoice_prepare_before_send.sql` (the durable record, the claim, the outcome and manual-resolution functions, the stored artifact), `supabase/migrations/0694_transmission_envelope.sql` (the current `prepare_einvoice_v1`, with its provenance envelope), `supabase/functions/send-e-invoice/handler.ts` (the decisions), `supabase/functions/send-e-invoice/store.ts` (the database calls), `supabase/functions/send-e-invoice/connectors.ts` (the installed providers and the classification of their answers)
- Design review: [#3335 implementation review](https://github.com/fdittgen-png/deskilo/issues/3335#issuecomment-6659675069). Its case table is the Evidence section below, O1 to O14.

The decisions live in `handler.ts`; `index.ts` is only the Deno entrypoint.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| issued invoice | the immutable, signed document the workspace issued | `invoices.id`, inside its workspace |
| destination | who the mandate points at: the government platform, or the customer's own delivery service | `government` / `customer`: separate credentials, never a fallback for each other; the customer leg always uses the generic upload |
| environment | which platform instance: production, the provider's test instance, a developer one | `prod` / `uat` / `dev`: endpoint and secret strictly per environment |
| provider | the channel adapter: generic upload, Peppol access point, French PA, SdI, KSeF, ANAF | the workspace's configured provider, among the installed connectors; a provider with no installed connector sends nothing |
| artifact | the exact bytes that may leave, with their SHA-256, file name, media type and receiver | one row of `invoice_transmission_artifacts`, linked by the transmission id and the same-workspace foreign key; written with the transmission, never readable by a client |
| **logical transmission** | one business submission of one invoice to one destination in one environment through one provider | one non-legacy `invoice_transmissions` row per `workspace_id\|invoice_id\|provider\|destination\|environment`, its `business_key`, enforced by the unique index `invoice_transmissions_business_key_uq`. A request id and the document digest are not part of the identity |
| binding | what the first preparation pinned | `binding_hash`: the digest of the document digest, format, receiver scheme and receiver id. A replay with another binding conflicts; it never opens a second submission |
| legacy row | a transmission written before preparation existed | a null `business_key`; preparation returns a matching accepted legacy row as the original instead of transmitting again |
| dispatch generation | one claimed attempt to post the stored artifact | `owner_id`, `generation` and `deadline` on the same row; each claim advances `generation` |
| upload receipt | what the provider said about the upload: Peppol evidence, PA lifecycle, SdI notification, KSeF number and UPO, ANAF state | `receipt`, `receipt_at`, `external_id` |
| document verdict | what the authority later decided about the document | `verdict`, a fact beside the receipt |
| status-query failure | a later status question that could not be answered | `query_error`, a fact beside the receipt |

The stable row is not a request: the same row is dispatched again, with a
new generation, when its earlier failure proved nothing was accepted. A
fresh HTTP request is one dispatch generation; the durable row is the
transmission. Upload acceptance, the document verdict and a failed status
query are different facts: the first is evidence that bytes left, the
other two are not evidence that they did not.

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one transmission, how many issued invoices? | exactly one | the composite key keeps it inside the invoice's workspace (`supabase/migrations/0242_tenant_reference_integrity.sql`) |
| For one issued invoice, how many transmission rows? | none or more, one per distinct provider, destination and environment | rows written before preparation have no business key and stay a plain log |
| For one transmission, how many dispatches in flight? | at most one | the claim moves the row to `sent` with a new owner and generation; a second claim finds it claimed |
| For one transmission, how many artifacts? | exactly one | pinned by the binding; the same-workspace foreign key keeps it with its transmission |
| For one transmission, how many receipts? | one upload receipt, with the verdict and the status-query failure kept beside it | a later fact never erases the upload receipt |
| For one workspace, how many provider configurations? | one, with per-destination and per-environment secrets | `einvoice_credentials`, read only by the service role |

## States and transitions

Declared states: `prepared`, `sent`, `accepted`, `rejected`, `failed`, `uncertain`.

The column is `phase`. The legacy column `status` is a three-value
projection of it (see Processing). `sent` means a dispatch was claimed;
`accepted` records that the provider took the upload; `rejected` records an
affirmative refusal of the upload; a document verdict is a separate fact.
There is no stored transition from `failed` back to `prepared`: a failed
transmission is claimed again directly, on the same row and artifact.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | prepare | the invoice exists in the workspace; no row with this business key and no accepted legacy row | `prepared` | `prepare_einvoice_v1` inserts the row and its artifact in one function call and writes the transmission envelope; nothing has left |
| (none) | prepare, matching replay | the business key exists and the binding matches | *(that row's phase)* | the existing row is returned; no second row, artifact or upload |
| (none) | prepare, changed binding | the business key exists and the binding differs | *(that row's phase)* | answer `binding_changed`; nothing changes, whatever the request id |
| `prepared` | claim | the handler verified the stored artifact; `claim_einvoice_dispatch_v1` wins | `sent` | `owner_id`, `generation + 1` and `deadline` are committed before the post |
| `failed` | claim | the same atomic claim | `sent` | the same row and stored artifact; `generation + 1` |
| `sent` | provider accepted the upload | the outcome is recorded by the current owner and generation (`record_einvoice_outcome_v1`) | `accepted` | `external_id`, `receipt`, `receipt_at` |
| `sent` | provider refused the upload | an explicit refusal: a 4xx other than 401, 403, 404, 408, 409 and 429, or a document answer the connector read | `rejected` | the sanitised detail; the provider's own words stay in the server log |
| `sent` | nothing can have been accepted | the request that carries the document never left, or the credential or endpoint was refused (401, 403, 404, the destination guard, an unsupported format, a missing connector) | `failed` | the sanitised detail; the row may be claimed again |
| `sent` | the answer cannot be trusted | after dispatch: a thrown error, a 5xx, 408, 409, 429 or an unreadable answer; or the outcome write was lost | `uncertain` | nothing is resent; a lost outcome write leaves the row `sent` until its deadline expires |
| `sent` | the deadline passes | `expire_einvoice_dispatches_v1`, also run by the claim, finds `deadline < now()` | `uncertain` | nothing is resent; `DISPATCH_WINDOW_SECONDS` in `handler.ts` is 150, a fixed constant and not a per-workspace setting |
| `uncertain` | a late outcome arrives | the same owner and generation as the last claim | `accepted` | the outcome function admits `sent` or `uncertain` rows; a stale owner or generation changes nothing |
| `uncertain` | a late outcome arrives | the same owner and generation | `rejected` | as above |
| `uncertain` | a late outcome arrives | the same owner and generation | `failed` | as above |
| `uncertain` | status query answers | an external id was retained and the connector read a document answer from a successful reply (`record_einvoice_lookup_v1`) | `accepted` | the receipt and a separate verdict are stored; a document rejection is a rejected verdict beside accepted transport |
| `uncertain` | status query cannot resolve | no retained external id, an unsupported lookup, or a failed query | `uncertain` | no external id: the answer is `lookup: unavailable` and nothing is written; a failed query writes only `query_error`; no resend |
| `uncertain` | manual resolution | `resolve_einvoice_manually_v1`: an active native member with the send authority, a nonblank reason and evidence, still `uncertain` | `accepted` | `resolved_by`, `resolved_reason`, `resolved_evidence`, `resolved_at`; an optional verdict beside it |
| `uncertain` | manual resolution | the same authority and compare-and-set | `rejected` | the same attribution; a transport refusal |
| `uncertain` | manual resolution | the same authority and compare-and-set | `failed` | the same attribution; only a claim can dispatch it again |
| `accepted` | status query answers | the connector read a document answer | `accepted` | the verdict is stored; the upload receipt is kept; `query_error` is cleared |
| `accepted` | status query fails | network, authorisation or timeout | `accepted` | the failure is written to `query_error`, never over the receipt |

A second manual resolution finds the row no longer `uncertain` and
changes nothing. A lookup never moves a row to `rejected`: the SQL function
would admit that argument, and the status branch of `handle` does not send
it.

## Invariants

| invariant | enforcement |
|---|---|
| a transmission never points into another workspace | the tenant foreign key on `invoice_id` (`supabase/migrations/0242_tenant_reference_integrity.sql`) and `invoice_transmission_artifacts_same_workspace` (0689) |
| a client cannot claim an invoice was sent or read its bytes | `invoice_transmissions` has a select policy only; the artifacts table has no client policy and no client grant; the prepare, claim, outcome, lookup and resolve functions are granted to the service role only (0689, 0694) |
| a development workspace sends nothing to anyone | the handler refuses a non-production workspace before any credential is used (#917) |
| a delegated token never transmits an invoice | `refuseDelegated` at the top of `handle` (#1614) |
| the customer leg never falls back to the government credentials, nor a sandbox key to the production one | `configForDestination` and `configFor` in `handler.ts`; destination and environment are part of the business key |
| every dispatch has a durable record before it leaves | the handler order: `prepare_einvoice_v1` (row and artifact in one call), artifact read and digest check, then the claim, then the post |
| one logical transmission has at most one record | the unique index `invoice_transmissions_business_key_uq` with `on conflict do nothing` in `prepare_einvoice_v1` |
| a changed document, format or receiver cannot bypass an existing submission | `binding_hash` compared in `prepare_einvoice_v1`; answer `binding_changed` |
| at most one dispatch owner at a time | the single update in `claim_einvoice_dispatch_v1`, which moves only `prepared` or `failed` rows to `sent` |
| an `uncertain` row is never resent automatically | the claim admits only `prepared` and `failed`; the handler answers any other existing phase as it stands |
| a late or stale writer changes nothing | `record_einvoice_outcome_v1` matches `generation` and `owner_id` |
| an upload receipt is never erased by a status answer or a failed query | `record_einvoice_lookup_v1` keeps a non-empty receipt of an accepted row; `query_error` and `verdict` are separate columns |
| an older client cannot trigger an unsafe resend | the server deduplicates on the business key whatever the request shape; `invoice_transmissions_sync_phase` and `legacyStatus` give an older reader an honest `status` |
| a manual resolution is attributable and cannot repeat | `resolve_einvoice_manually_v1`: authority check, reason and evidence, compare-and-set on `uncertain`, recorded actor |

## Processing

- **Trigger and actor:** an owner, an admin, or a member holding `issueInvoices` through a role presses *Send* on an issued invoice. The client builds the bytes and posts them to `send-e-invoice`.
- **Sequence:** authorize (a signed-in active member with that authority; not a delegated token; a production workspace) · prepare and deduplicate · read and verify the stored artifact · claim · HTTP post of the stored artifact · record against the claim's owner and generation. The HTTP effect is outside the database transaction.
- **Outcomes to the client:** `status` and `phase`, with a sanitised detail. A replay receives the existing row. A request that loses the claim, or that finds the row in flight or uncertain, receives the unresolved answer, never a blind retry. The provider's own words never reach the client (#3090).
- **External effect:** one HTTP upload to the provider per claimed dispatch generation.
- **Recovery:** a dispatch that may have landed is `uncertain` and is never resent. Only a row that never dispatched (`prepared`) or whose failure proved no acceptance (`failed`) may be claimed again. Recovery uses the stored provider, destination, environment and artifact, never the request's defaults. A status query is possible only for a row in `accepted` or `uncertain` that retained an `external_id`. A transmission with no retained external id, or on a provider with no lookup, stays `uncertain` until the verified manual resolution settles it; no connector finds a submission by a key recorded before the upload.
- **Classification:** `classify` in `connectors.ts` decides what an answer proves, using the connector's dispatch marker (`onDispatch`): before the document request left, nothing was accepted; after it, only an explicit refusal is a rejection.
- **Compatibility:** `phase` carries the six states. `status` stays a three-value projection: accepted and rejected stay themselves; prepared, sent and uncertain read as failed with the detail "In progress or unresolved - do not resend". An older decoder therefore cannot tell uncertainty from failure; the server's deduplication prevents its retry from causing another upload. The current client reads `phase` first (`lib/features/money/domain/einvoice_gateway.dart`).

## Evidence

A path below is source-level test coverage, not a record that a run passed. Where the obligation is broader than the assertions, the covered part is stated.

| # | rule | executed by |
|---|---|---|
| O1 | a failed prepare or an artifact whose digest does not match uploads nothing and leaves no `sent` row | `supabase/functions/send-e-invoice/handler_test.ts` (failed prepare; artifact digest mismatch; no upload) |
| O2 | two simultaneous requests for one business key post once | the same handler test, simultaneous requests; `scripts/einvoice_claim_race.sh` for two SQL sessions; `supabase/tests/database/365_einvoice_prepare_before_send.sql` for identity and claim assertions |
| O3 | a record prepared and never dispatched is claimed by the next request | `handler_test.ts` (prepared before dispatch); the claim assertions of pgTAP 365 |
| O4 | a lost answer, a failed outcome write, a 5xx or an expired dispatch is uncertain and is not resent | `handler_test.ts` (lost response, failed outcome write, 5xx, expired dispatch); the expiry and stale-owner checks of pgTAP 365 |
| O5 | lookup by a key recorded before the upload: none, unsupported by the installed connectors. Recovery by a retained external id is a different, narrower shipped path and is not evidence for this obligation; that path is executed by `handler_test.ts` (R1–R7 retained-ID recovery: settles accepted, a separate document verdict, a failed query leaves it uncertain, no id means lookup unavailable, no second upload) and pgTAP 365 (R8–R10) | none |
| O6 | the generic adapter stays uncertain over any number of status calls | `handler_test.ts` (generic adapter stays uncertain) |
| O7 | a replay of an accepted transmission returns its receipt and uploads nothing | `handler_test.ts` (accepted replay; no second upload) |
| O8 | changed bytes, format or receiver conflict; a stale owner records nothing | `handler_test.ts` (changed binding); the changed-binding, stale-generation and owner assertions of pgTAP 365 |
| O9 | a failed status query leaves the upload receipt | `handler_test.ts` (failed status query preserves the receipt); the lookup assertions of pgTAP 365 |
| O10 | an upload refusal and a later document rejection are different facts | `handler_test.ts` (a later SdI document rejection); the manual verdict and transport assertions of pgTAP 365; `supabase/functions/send-e-invoice/connectors_test.ts` for the classification |
| O11 | government and customer legs, and environments, are separate transmissions with separate credentials | `handler_test.ts` (government and customer separation); the destination and environment identity assertions of pgTAP 365. Recovery of a stored UAT row with an omitted or a contradicting environment asks the stored environment's endpoint and credential only: `handler_test.ts` (R2, R3 retained-ID recovery) |
| O12 | unauthorised, delegated and other-workspace callers reach neither the provider nor the record | the authorization tests of `handler_test.ts`; the service-role-only claim and artifact privilege assertions of pgTAP 365; `supabase/tests/database/42_tenant_reference_integrity.sql` for same-workspace integrity. This is not a full artifact-access matrix |
| O13 | an older client's request and read of an unresolved row stay honest and cannot cause a second upload | `handler_test.ts` (the O13 test and the legacy-request replay tests); `test/features/money/einvoice_unresolved_test.dart`. The legacy projection is limited as stated in Processing; these are not an execution of a historical client build |
| O14 | manual resolution needs the authority, a reason and evidence, and cannot repeat | the manual-resolution assertions of pgTAP 365; the authority, reason, evidence and repeat tests of `handler_test.ts` |

Ancillary client evidence: `test/features/money/einvoice_send_test.dart` (the client sends through the gateway when a platform is configured and offers no button otherwise) and `test/features/money/einvoice_receipts_test.dart` (receipts land on the transmission they answer).
