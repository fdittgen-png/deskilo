<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# E-invoice transmission — a document that may have left is worse than one that failed

## Baseline

- Source commit: 010b6dfea01b1e15609c7d057d018a3eb7455fc2
- Refs: #3335 (prepare before send, idempotent retry, uncertain outcome), #3336 (provenance and capability lifecycle, which hangs on this attempt identity), #2358 (the national channels), #3328 (the modular epic)
- Canonical sources: `docs/decisions/0010-e-invoice-transmission.md` (the app produces the document, a provider transmits it), `supabase/migrations/0071_einvoice_transmission.sql` (the attempt log), `supabase/migrations/0414_einvoice_channels.sql` (format, receipt), `supabase/functions/send-e-invoice/index.ts` (the handler), `supabase/functions/_shared/accounting_delivery.ts` (the delivery state machine whose words this page reuses)
- Existing review: the implementation review on #3335. This page consolidates it into one contract and one evidence map; it adds no requirement that review did not state.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| issued invoice | the immutable, signed document the workspace issued | `invoices.id`, inside its workspace |
| destination | who the mandate points at: the government platform, or the customer's own delivery service | `government` / `customer` — separate credentials, never a fallback for each other |
| environment | which platform instance: production, the provider's test instance, a developer one | `prod` / `uat` / `dev` — endpoint and secret strictly per environment |
| provider | the channel adapter: generic upload, Peppol access point, French PA, SdI, KSeF, ANAF | the workspace's configured provider; the customer leg is always the generic upload |
| artifact | the bytes the client built with the same builder as the download, and their SHA-256 | the digest; the bytes themselves are not stored today |
| **logical transmission** | *this invoice, to this destination, in this environment, through this provider, as these bytes* | **proposed:** the tuple above — the scope of every "at most once" rule on this page. Today no row carries it; each HTTP request is its own attempt |
| attempt | one try to make the logical transmission happen | one `invoice_transmissions` row; **proposed:** a stable attempt id, created before dispatch, reused by every retry |
| receipt | what the provider said about the document — Peppol evidence, PA lifecycle, SdI notification, KSeF number and UPO, ANAF state | `receipt`, `receipt_at`, `external_id` on the attempt |
| transport progress | whether the upload reached the provider | the attempt's state |
| document verdict | what the authority eventually decided about the document | **proposed:** a separate fact on the attempt; today a later rejection overwrites the state |

Transport progress and document verdict are different facts. An upload
receipt, a failed status query and a final rejection must stay
distinguishable: the first is evidence that bytes left, the other two
are not evidence that they did not.

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one attempt, how many issued invoices? | exactly one | the composite key keeps it inside the invoice's workspace (`supabase/migrations/0242_tenant_reference_integrity.sql`) |
| For one issued invoice, how many attempts? | none or more | it is a log: a platform outage or a rejection is followed by another attempt |
| For one logical transmission, how many attempts *in flight or uncertain*? | **proposed:** at most one | today: unbounded — two concurrent requests each send |
| For one attempt, how many receipts? | at most one, revised by later status queries | today a later answer overwrites the receipt; the proposed rule keeps an upload receipt when a later query fails |
| For one attempt, how many artifacts? | exactly one, pinned by digest | a retry with other bytes is another logical transmission, never the same attempt |
| For one workspace, how many provider configurations? | one, with per-destination and per-environment secrets | `einvoice_credentials`, read only by the service role |

## States and transitions

Declared states: `prepared`, `sent`, `accepted`, `rejected`, `failed`, `uncertain`.

Today the attempt row is written **after** the provider answered and
knows only `accepted`, `rejected`, `failed` (the check constraint of
0071). The states `prepared`, `sent` and `uncertain` are the proposal of
#3335; they follow the vocabulary of the accounting deliveries
(`generated` → `sent` → `acknowledged` / `conflict` / `failed`, with an
`in_flight` answer to a concurrent prepare) so that there is one state
machine to understand, not two.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | prepare | caller is an active member who may issue invoices; workspace is `prod`; provider configured for the destination and environment; no attempt of the same logical transmission is `sent` or `uncertain` | `prepared` | the attempt row with its id, digest, artifact reference, provider, destination, environment, format; nothing has left |
| (none) | prepare (replay) | an attempt with the same logical identity exists | *(that attempt's state)* | the existing attempt is answered; no second row |
| `prepared` | claim dispatch | the caller atomically takes the in-flight ownership (owner, generation, deadline); a prepared attempt whose owner expired may be claimed again | `sent` | the bytes are posted with the attempt id as the idempotency key where the channel has one |
| `sent` | provider took the upload | the connector returned the platform's acknowledgement | `accepted` | `external_id`, receipt, `receipt_at`; the answer to the client |
| `sent` | provider refused the document | the connector returned the platform's refusal | `rejected` | the sanitised detail (the provider's words stay in the server log, #3090) |
| `sent` | provider unreachable | the connector certifies that no byte can have been accepted | `failed` | the sanitised detail; the attempt may be dispatched again |
| `sent` | answer lost | the process died, the response timed out after the upload could have landed, or the outcome write failed; or the in-flight deadline passed with no outcome recorded | `uncertain` | nothing is resent; the attempt keeps its pre-dispatch facts |
| `uncertain` | lookup finds the document | the provider supports lookup by the pre-recorded key or by the attempt id | `accepted` | receipt attached to the original attempt; no create |
| `uncertain` | lookup finds a refusal | same | `rejected` | the refusal attached to the original attempt |
| `uncertain` | lookup unavailable, or no lookup exists for this provider | the generic adapter has no read-back | `uncertain` | the attempt stays visible as unresolved; a person resolves it |
| `uncertain` | manual resolution | the resolver holds the permission; actor, reason and evidence are recorded; the attempt is still `uncertain` | `accepted` | or `rejected` or `failed` as the evidence says; attributable; a second resolution is refused |
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
| every attempt is logged, accepted or not | held — with a gap | the insert follows the `submit` call: a crash between them loses the attempt. **This is the defect #3335 corrects** |
| one logical transmission has at most one attempt in flight | proposed | an atomic claim with owner and generation, as `record_accounting_delivery` answers `in_flight` (`supabase/tests/database/324_accounting_delivery_in_flight.sql`) |
| a replay with the same attempt id and the same digest returns the original attempt; a replay with another digest or recipient under the same id is refused by name | proposed | the digest pinned on the attempt before dispatch, as the booking claim pins its payload (`supabase/migrations/0353_booking_intent_recovery.sql`) |
| an `uncertain` attempt is never resent automatically | proposed | the state machine admits no `uncertain` → `sent` transition |
| an upload receipt is never erased by a failed status query | proposed | the verdict is a second fact on the row |
| an older client cannot trigger an unsafe resend | proposed | the server deduplicates on the logical identity regardless of the request shape; the client's decoder (`lib/features/money/domain/einvoice_gateway.dart` maps an unknown state to `failed`) must not be the only guard |
| the manual resolution is attributable and repeat-safe | proposed | permission check, recorded actor and evidence, refusal of a second resolution |

## Processing

- **Trigger and actor:** the person who may issue invoices presses *Send* on an issued invoice; the client builds the bytes and posts them to `send-e-invoice`. An owner, an admin, or a member holding `issueInvoices` through a role.
- **Prerequisites:** the invoice exists in the caller's workspace; the workspace is production; the provider is configured for the chosen destination and environment.
- **Atomic effects (proposed order):** write the `prepared` attempt (or answer the existing one) · claim dispatch · post · record the outcome on the same row. Each step is durable before the next starts; the identity exists before any byte leaves.
- **Outcomes to the client:** the attempt's state and its sanitised detail. A replay receives the existing attempt. A concurrent request receives *in flight*. An `uncertain` attempt is shown as unresolved with the actions the provider supports (look up, or record a verified outcome), never a blind *retry*.
- **External effect:** one HTTP upload to the provider per dispatch claim. The provider's own words never reach the client (#3090).
- **Recovery:** from `uncertain`, lookup where the provider supports it, otherwise a person; from an expired in-flight claim, a fresh claim of the same attempt with the same bytes; from `failed`, a new dispatch of the same attempt. Recovery reads provider, destination, environment and digest **from the attempt**, never from the request's defaults.

## Evidence

Executed today, to keep:

| rule | executed by |
|---|---|
| each connector's exact request and how each answer becomes an outcome; the KSeF cryptography end to end | `supabase/functions/send-e-invoice/connectors_test.ts` |
| the client sends through the gateway when a platform is configured and offers no button otherwise | `test/features/money/einvoice_send_test.dart` |
| receipts land on the transmission they answer | `test/features/money/einvoice_receipts_test.dart` |
| the delivery state machine answers `in_flight` to a truly concurrent prepare and reads back before it creates | `supabase/functions/_shared/accounting_delivery_test.ts`, `supabase/tests/database/324_accounting_delivery_in_flight.sql` |
| a transmission row stays inside its workspace | `supabase/tests/database/42_tenant_reference_integrity.sql` |

Obligations the proposed rules derive. Each names its oracle — the
state and the effects to inspect, not the returned label: two
concurrent requests can each answer *success* and still violate the
one-in-flight rule.

| # | given / action | expected | oracle | layer |
|---|---|---|---|---|
| O1 | artifact storage or the prepare write fails | no upload; no `sent` or `accepted` row | the mocked provider saw no request; the table holds no row or a `prepared` one | handler test with an injected store failure |
| O2 | two concurrent requests, same logical transmission, different request ids | one attempt, at most one upload; the second caller is told *in flight* | one row; the mocked provider counted one request | pgTAP on the claim, as 324 proves it for deliveries |
| O3 | the process dies after `prepared`, before the claim | the attempt can be claimed and dispatched later; nothing is lost | the same attempt id reaches `sent`, then an outcome | pgTAP: expired owner, then claim |
| O4 | provider accepts; the response or the outcome write is lost | after the in-flight deadline the attempt reads `uncertain`; nothing was resent | one upload counted; state `uncertain` | handler test with a response dropped after the upload |
| O5 | from `uncertain`, the provider supports lookup by the pre-recorded key | the found result attaches to the original attempt | same attempt id; receipt present; no second upload | connector test with a mocked lookup |
| O6 | from `uncertain`, the generic adapter | the attempt stays `uncertain`, visible, with no automatic repeat | zero uploads over any number of status calls | handler test |
| O7 | a successful transmission is replayed | the existing receipt is returned | no new row; no upload | handler test |
| O8 | a replay changes the bytes or the recipient under the same attempt id; or a stale owner records late | refused by name; the original artifact and the newer outcome stay | digest unchanged; state unchanged | pgTAP |
| O9 | a status poll times out or loses authorisation after an accepted upload | the receipt stays; the failure is recorded beside it | `receipt` unchanged; state still `accepted` | handler test |
| O10 | the provider rejects the document | `rejected` with its sanitised detail on the original attempt | the detail is the fixed key, not the provider's words | connector test (exists for the connectors; to extend to the attempt row) |
| O11 | the government and customer legs, or UAT and production, of one invoice | distinct logical transmissions and credentials; recovery uses the stored destination and environment | two rows with different identity; the recovery request carried no environment and still hit the right endpoint | handler test |
| O12 | an anonymous, inactive, delegated or other-workspace caller | refused before any provider access and before any attempt is readable | no row; no upload; 401/403 | handler test (exists for the refusals; to extend to attempt reads) |
| O13 | an older client omits the new fields, or reads an `uncertain` attempt | the server still deduplicates; the client shows no blind resend | one row; the decoder yields a state the sheet renders as unresolved | gateway decoder test and handler test |
| O14 | a manual resolution without the permission or the evidence, or a second resolution | refused; a valid one is attributable | actor and reason on the row; the second call changes nothing | pgTAP |

The pgTAP files take their number at push time (the migration rule);
this page names them by what they prove, not by a number that does not
exist yet.

## Open decisions

| # | decision | who |
|---|---|---|
| D1 | whether `uncertain` is one state with a *resolvable by lookup / by a person* attribute, or two states; this page uses one state | the implementer of #3335, in the pull request, with the reviewer |
| D2 | the exact logical identity: whether the format is part of it (a Factur-X and a UBL of the same invoice to the same platform are two transmissions, or one retry with other bytes) | owner — a business rule, not a technical one |
| D3 | whether the document verdict becomes a column beside the state or a row in a verdict log; today the status action overwrites the state with `rejected` and that behaviour has readers | the implementer, with the readers of `test/features/money/einvoice_receipts_test.dart` in view |
| D4 | the in-flight deadline: the edge function's wall-clock budget, as the deliveries use | the implementer; a configured value with a UI point if it is to vary per workspace (the no-hardcoded-value rule) |
| D5 | who may record a manual resolution: the issuing permission, or the owner only | owner |

## Stop condition

#3335 closes when the obligations O1–O14 are executed through the
existing gateway, the current client contract remains safe (an older
client can neither resend blindly nor misread an unresolved attempt as
failed), and the connector tests still pass. No country-package
extraction, no universal delivery framework and no live-provider
qualification belong to it. #3336's provenance envelope hangs its
attempt identity on the `prepared` row this page introduces.
