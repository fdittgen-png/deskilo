<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# E-invoice transmission — a document that may have left is worse than one that failed

## Baseline

- Source commit: 0e61749f2f0920a4117735bb416b98ce3919dc7e
- Refs: #3335 (prepare before send, idempotent retry, uncertain outcome), #3336 (provenance and capability lifecycle, which hangs on this attempt identity), #2358 (the national channels), #3328 (the modular epic)
- Canonical sources: `docs/decisions/0010-e-invoice-transmission.md` (the app produces the document, a provider transmits it), `supabase/migrations/0071_einvoice_transmission.sql` (the attempt log), `supabase/migrations/0414_einvoice_channels.sql` (format, receipt), `supabase/functions/send-e-invoice/index.ts` (the handler), `supabase/functions/_shared/accounting_delivery.ts` (the delivery state machine whose words this page reuses)
- Required review: [#3335 implementation review](https://github.com/fdittgen-png/deskilo/issues/3335#issuecomment-6659675069). Its safeguards and case table remain acceptance requirements, mapped to O1–O14 below. Proposed behaviour is not implemented at this baseline.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| issued invoice | the immutable, signed document the workspace issued | `invoices.id`, inside its workspace |
| destination | who the mandate points at: the government platform, or the customer's own delivery service | `government` / `customer` — separate credentials, never a fallback for each other |
| environment | which platform instance: production, the provider's test instance, a developer one | `prod` / `uat` / `dev` — endpoint and secret strictly per environment |
| provider | the channel adapter: generic upload, Peppol access point, French PA, SdI, KSeF, ANAF | the workspace's configured provider; the customer leg is always the generic upload |
| artifact | the bytes the client built with the same builder as the download, and their SHA-256 | the digest; the bytes themselves are not stored today |
| **logical transmission** | one business submission of this invoice, scoped by installation, workspace/issuer, provider target, destination and environment | **proposed:** a stable business key, independent of request ids and payload digest. The first preparation pins bytes, format and recipient; changing them cannot bypass an unresolved or acknowledged submission (D2). Today each HTTP request is its own attempt |
| attempt | today one send-log row; **proposed:** the durable record for one logical transmission | one stable `invoice_transmissions` record per business key, created before dispatch; retries are dispatch generations on that same record |
| receipt | what the provider said about the document — Peppol evidence, PA lifecycle, SdI notification, KSeF number and UPO, ANAF state | `receipt`, `receipt_at`, `external_id` on the attempt |
| transport progress | local dispatch progress and what is known about the upload | the attempt's state; a dispatch claim is not evidence of remote acceptance |
| document verdict | what the authority eventually decided about the document | **proposed:** a separate fact on the attempt; today a later rejection overwrites the state |

Transport progress and document verdict are different facts. An upload
receipt, a failed status query and a final rejection must stay
distinguishable: the first is evidence that bytes left, the other two
are not evidence that they did not.

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one attempt, how many issued invoices? | exactly one | the composite key keeps it inside the invoice's workspace (`supabase/migrations/0242_tenant_reference_integrity.sql`) |
| For one issued invoice, how many attempt records? | none or more, across distinct business transmission keys | today each send adds a log row; proposed retries reuse the record for their key, with a new dispatch generation only when permitted |
| For one logical transmission, how many attempts *in flight or uncertain*? | **proposed:** at most one | today: unbounded — two concurrent requests each send |
| For one attempt, how many receipts? | today one mutable receipt value; proposed: upload evidence and later verdict/query facts kept separately | a failed query never erases evidence of an upload |
| For one attempt, how many artifacts? | **proposed:** one persisted artifact, pinned by digest | different bytes, format or recipient conflict even with a new request id; correction is outside this retry slice (D2) |
| For one workspace, how many provider configurations? | one, with per-destination and per-environment secrets | `einvoice_credentials`, read only by the service role |

## States and transitions

Declared states: `prepared`, `sent`, `accepted`, `rejected`, `failed`, `uncertain`.

Today the row is written **after** the provider answered and knows only
`accepted`, `rejected`, `failed` (0071). The following table is **proposed**
for #3335. `sent` means dispatch was claimed; `accepted` records upload acceptance; `rejected` requires affirmative upload/admission refusal. A document verdict is a separate fact.
Accounting delivery supplies identity/recovery precedents, not an identical protocol.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | prepare | active native member with issuing authority; workspace is `prod`; provider configured; no existing business key | `prepared` | atomically create the unique attempt with persisted artifact and pinned binding; nothing has left |
| (none) | prepare (replay) | caller remains authorised; business key exists; bytes, format and recipient match its binding | *(that attempt's state)* | return the existing attempt; no second row or upload; changed binding is a named conflict regardless of request id |
| `prepared` | claim dispatch | atomic claim of a new dispatch generation; no live owner or unresolved prior dispatch; any prior dispatch proved no acceptance | `sent` | commit owner, generation and deadline before posting; send the attempt key where provider idempotency is supported |
| `failed` | retry | caller remains authorised; original binding; failure proves no possible acceptance | `prepared` | reuse the same attempt and stored bytes; no upload before a new atomic claim |
| `sent` | provider took the upload | the connector returned the platform's acknowledgement | `accepted` | `external_id`, receipt, `receipt_at`; the answer to the client |
| `sent` | provider refused upload/admission | affirmative refusal before acceptance, not an arbitrary non-2xx response | `rejected` | sanitised transport-refusal detail; never overwrite upload evidence with a later document verdict |
| `sent` | provider unreachable | the connector certifies that no byte can have been accepted | `failed` | the sanitised detail; the attempt may be dispatched again |
| `sent` | answer lost | the process died, the response timed out after the upload could have landed, or the outcome write failed; or the in-flight deadline passed with no outcome recorded | `uncertain` | nothing is resent; the attempt keeps its pre-dispatch facts |
| `uncertain` | lookup finds upload evidence or a document verdict | correlated lookup matches the original attempt/binding | `accepted` | retain upload evidence and a separate verdict, including document rejection; no create |
| `uncertain` | lookup proves upload/admission refusal | correlated evidence establishes refusal before acceptance | `rejected` | attach the transport refusal to the original attempt; no create |
| `uncertain` | lookup unsupported or inconclusive | no correlated proof of acceptance/refusal; timeout or temporary not-found is insufficient | `uncertain` | preserve unresolved state; use verified manual evidence where lookup cannot resolve it, including the generic adapter; no resend |
| `uncertain` | manual upload/document-verdict resolution | current issuing authority (D5); correlated upload or document-verdict evidence; compare-and-set still uncertain | `accepted` | record actor/reason/evidence; document rejection is a separate verdict, not transport refusal; repeat cannot change it |
| `uncertain` | manual upload/admission refusal | same authority and atomic guard; affirmative refusal before acceptance | `rejected` | record attributable transport-refusal evidence; no upload |
| `uncertain` | manual no-acceptance | same authority and atomic guard; affirmative evidence proves no acceptance, not timeout or temporary not-found | `failed` | record the evidence; only the guarded retry above can dispatch |
| `accepted` | status query answers | the provider's later verdict about the document | `accepted` | the verdict and receipt are stored as a second fact; the upload receipt is not erased — **proposed**; today the row's state becomes `rejected` |
| `accepted` | status query fails | network, authorisation or timeout | `accepted` | the failure is recorded beside the receipt, never over it |

## Invariants

| invariant | status | enforcement |
|---|---|---|
| a transmission attempt never points into another workspace | held | composite foreign key, 0242 |
| a client cannot claim an invoice was sent | held | `invoice_transmissions` has a select policy only; the service role writes |
| a development workspace sends nothing to anyone | held | the handler refuses before any credential is used (#917) |
| a delegated token never transmits an invoice | held | `refuseDelegated` at the top of the handler (#1614) |
| the customer leg never falls back to the government credentials, nor a sandbox key to the production one | held | `configForDestination`, `configFor` |
| every possible dispatch has a durable attempt before it leaves | not held; proposed correction | the insert currently follows `submit`; a crash can lose the attempt. **This is the defect #3335 corrects** |
| one logical transmission has at most one attempt in flight | proposed | an atomic claim with owner and generation, as `record_accounting_delivery` answers `in_flight` (`supabase/tests/database/324_accounting_delivery_in_flight.sql`) |
| a business-key replay returns the original attempt; changing request id, bytes, format or recipient cannot bypass an unresolved or acknowledged transmission | proposed | unique business identity plus immutable payload binding, as the booking claim pins its payload (`supabase/migrations/0353_booking_intent_recovery.sql`) |
| an `uncertain` attempt is never resent automatically | proposed | the state machine admits no `uncertain` → `sent` transition |
| an upload receipt is never erased by a failed status query | proposed | the verdict is a second fact on the row |
| an older client cannot trigger an unsafe resend | proposed | the server deduplicates on the logical identity regardless of the request shape; the client's decoder (`lib/features/money/domain/einvoice_gateway.dart` maps an unknown state to `failed`) must not be the only guard |
| the manual resolution is attributable and repeat-safe | proposed | permission check, recorded actor and evidence, refusal of a second resolution |

## Processing

- **Trigger and actor:** the person who may issue invoices presses *Send* on an issued invoice; the client builds the bytes and posts them to `send-e-invoice`. An owner, an admin, or a member holding `issueInvoices` through a role.
- **Prerequisites:** the invoice exists in the caller's workspace; the workspace is production; the provider is configured for the chosen destination and environment.
- **Durable boundaries (proposed):** persist and verify the artifact · atomically prepare/deduplicate · atomically claim · post · conditionally record against the current owner/generation. The HTTP effect is outside the database transaction; stale writers cannot replace a newer outcome.
- **Outcomes to the client:** the attempt's state and its sanitised detail. A replay receives the existing attempt. A concurrent request receives *in flight*. An `uncertain` attempt is shown as unresolved with the actions the provider supports (look up, or record a verified outcome), never a blind *retry*.
- **External effect:** one HTTP upload to the provider per dispatch claim. The provider's own words never reach the client (#3090).
- **Recovery:** expiry after possible dispatch means `uncertain`, never permission to resend. Only proven pre-dispatch preparation or a proven no-acceptance failure may be claimed again. Lookup uses a pre-recorded correlation key where supported; otherwise retain unresolved/manual-check state. Recovery uses the stored provider, destination, environment and artifact, never mutable request defaults.
- **Connector classification:** current `Submission` collapses thrown errors into `failed` and non-2xx into `rejected`; neither proves no acceptance. The implementation must distinguish known no-effect, possible dispatch and explicit document verdict. Lost/malformed responses after possible acceptance stay uncertain; failed status queries preserve receipt facts. Map this boundary to O1/O4/O9/O10; retain request/security tests, revise blanket error expectations.
- **Compatibility:** before exposing new states, specify submission-response and history-read representations for a pinned previous supported client and the new client (D6). A new decoder does not update an old one. Server deduplication always applies; legacy projection or capability refusal must be proven through that actual reader without calling uncertainty failure or acceptance.

## Evidence

Existing test sources to retain; this page is not a new execution receipt:

| rule | executed by |
|---|---|
| each connector's exact request and how each answer becomes an outcome; the KSeF cryptography end to end | `supabase/functions/send-e-invoice/connectors_test.ts` |
| the client sends through the gateway when a platform is configured and offers no button otherwise | `test/features/money/einvoice_send_test.dart` |
| receipts land on the transmission they answer | `test/features/money/einvoice_receipts_test.dart` |
| the delivery state machine honours a supplied `in_flight` result and reads back before creating; SQL tests the time window sequentially | `supabase/functions/_shared/accounting_delivery_test.ts`, `supabase/tests/database/324_accounting_delivery_in_flight.sql`; neither is a two-session dispatch proof |
| a transmission row stays inside its workspace | `supabase/tests/database/42_tenant_reference_integrity.sql` |

Obligations the proposed rules derive. Each names its oracle — the
state and the effects to inspect, not the returned label: two
concurrent requests can each answer *success* and still violate the
one-in-flight rule.

| # | given / action | expected | oracle | layer |
|---|---|---|---|---|
| O1 | artifact storage or the prepare write fails | no upload; no `sent` or `accepted` row | the mocked provider saw no request; the table holds no row or a `prepared` one | handler test with an injected store failure |
| O2 | two concurrent requests, same business key, different request ids | one attempt and dispatch owner; loser receives existing/in-flight state | one durable identity; at most one provider upload | controlled two-session database claim test plus injected-provider handler test |
| O3 | process dies after preparation, proven before any dispatch claim | same attempt may be claimed later | original artifact/id; no earlier upload | database claim test plus handler interruption fixture |
| O4 | possible provider acceptance, then lost/malformed response, process death or outcome-write failure; ownership expires | durable uncertainty; no automatic re-dispatch, including through a fresh owner | original attempt; one upload; expiry and retries cause no second upload | handler failure injection plus database expiry test |
| O5 | from `uncertain`, the provider supports lookup by the pre-recorded key | the found result attaches to the original attempt | same attempt id; receipt present; no second upload | connector test with a mocked lookup |
| O6 | from `uncertain`, the generic adapter | the attempt stays `uncertain`, visible, with no automatic repeat | zero uploads over any number of status calls | handler test |
| O7 | a successful transmission is replayed | the existing receipt is returned | no new row; no upload | handler test |
| O8 | changed bytes/format/recipient with the same or a fresh request id while unresolved/acknowledged; stale owner writes late | named conflict/refusal; no duplicate dispatch or replacement of winning facts | pinned artifact/recipient and winning outcome unchanged; no new business attempt/upload | database mutation assertions plus handler provider count |
| O9 | a status poll times out or loses authorisation after an accepted upload | the receipt stays; the failure is recorded beside it | `receipt` unchanged; state still `accepted` | handler test |
| O10 | affirmative upload refusal vs correlated later document rejection, through response/lookup/manual resolution | transport `rejected` only for upload refusal; known uploaded document stays/becomes `accepted` with separate rejected verdict | original attempt, preserved upload evidence, separate verdict and sanitised fixed detail | connector plus handler/database outcome tests |
| O11 | the government and customer legs, or UAT and production, of one invoice | distinct logical transmissions and credentials; recovery uses the stored destination and environment | two rows with different identity; the recovery request carried no environment and still hit the right endpoint | handler test |
| O12 | anonymous, inactive, delegated or other-workspace actor requests send, history or artifact; authorised control | forbidden operation/read refused; permitted control works | existing fixture unchanged; no forbidden data or provider call; explicit refusal | actual handler plus database/storage access tests under caller roles |
| O13 | pinned previous client omits fields and reads/replays unresolved history; new client reads the same attempt | old wire/read path is honest or explicitly compatibility-refused; new UI shows unresolved; no unsafe resend | actual old decoder/request fixture, pinned by commit; no duplicate row/upload after its retry | legacy gateway/history fixture, new decoder/UI and handler tests |
| O14 | a manual resolution without the permission or the evidence, or a second resolution | refused; a valid one is attributable | actor and reason on the row; the second call changes nothing | pgTAP |

The pgTAP files take their number at push time (the migration rule);
this page names them by what they prove, not by a number that does not
exist yet.

## Open decisions

| # | decision | who |
|---|---|---|
| D1 | whether `uncertain` is one state with a *resolvable by lookup / by a person* attribute, or two states; this page uses one state | the implementer of #3335, in the pull request, with the reviewer |
| D2 | **resolved:** bytes, format and recipient are immutable binding, not new-submission identity; changing them conflicts. An explicit correction route is outside this retry slice | delegated design review: prevents a new digest/request id bypassing the same business submission |
| D3 | whether the document verdict becomes a column beside the state or a row in a verdict log; today the status action overwrites the state with `rejected` and that behaviour has readers | the implementer, with the readers of `test/features/money/einvoice_receipts_test.dart` in view |
| D4 | the in-flight deadline: the edge function's wall-clock budget, as the deliveries use | the implementer; a configured value with a UI point if it is to vary per workspace (the no-hardcoded-value rule) |
| D5 | **resolved:** reuse the current send authority: native token, active workspace member, owner/admin or `issueInvoices`; scope to the original attempt and require actor/reason/evidence plus atomic uncertainty guard | delegated design review: existing authority, no new permission machinery; timeout/not-found alone never proves no acceptance |
| D6 | exact submission/history compatibility design and previous supported client commit; demonstrate O13 before exposing new states | implementer and reviewer; server deduplication cannot substitute for honest reads |

## Stop condition

#3335 closes when O1–O14 and the linked review requirements are verified
through the existing gateway, D6 is demonstrated with its pinned client,
and connector tests retain their safety coverage with corrected outcome
classification. A newer decoder alone is not compatibility proof. No country-package
extraction, no universal delivery framework and no live-provider
qualification belong to it. #3336's provenance envelope hangs its
attempt identity on the `prepared` row this page introduces.
