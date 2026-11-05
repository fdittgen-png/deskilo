# Pilot journey evidence — #1974

Candidate: master `9c76375e0` plus `test/features/workspace/pilot_exclusions_test.dart`.
Rule: this document names roles (the pilot operator), never people (#2605).
Scope: the existing-community pilot (manual payment recording, external
accountant). Status words are PASS, PARTIAL, FAIL, NOT RUN or BLOCKED; nothing
here is a universal compliance assertion, and a status is only as strong as the
named command.

Command run for the Dart evidence (exit 0, `All tests passed!`, 2279 tests):

```
flutter test test/ux test/a11y test/app test/core/cache test/core/realtime \
  test/features/money test/features/reservations test/core/instance \
  test/features/workspace/invitation_journey_test.dart \
  test/features/workspace/member_join_validation_test.dart \
  test/features/workspace/feature_lifecycle_test.dart \
  test/features/workspace/feature_promotion_test.dart
```

| Acceptance bullet | Status | Evidence (named tests) | What is missing |
|---|---|---|---|
| Owner/admin/member journey: sign in → join/approve → plan → reserve → readback → conflicting second member refused → cancel/check-in/out → reload | PASS (database and local app) / PARTIAL (release) | `test/ux/demo_journeys_test.dart` (book a desk, book as a member); `invitation_journey_test.dart`, `member_join_validation_test.dart`; `supabase/tests/database/24_booking_idempotency.sql` (a different key over the same hours is refused), `107`, `111`, `112`, `149` (transitions); `test/features/reservations/check_in_presence_test.dart`, `auto_check_in_out_test.dart` | 2026-10-08: NEW pgTAP `161_pilot_journey.sql` chains the whole journey on the real schema with the authenticated role active — join by code → pending → owner admits → book → read back → same seat refused (23P01) → check in → check out → cancel → the freed seat booked by the other member → an ordinary member and a stranger refused administration, the stranger reads nothing → the persisted states read afresh. Rehearsed first as a rolled-back harness on the dev project (all steps as expected). 9 October: the local browser steps and full-page reload are recorded below; final release and operator review remain |
| Subscription/usage + approved expense → manual payment → statement → handoff agree; payment is not a second charge | PASS | `test/features/money/statement_test.dart`, `accountant_handoff_test.dart`, `accountant_handoff_flow_test.dart`, `export_reads_test.dart` (#1885 reads); pgTAP `22_reconciliation`, `40_payment_ledger_association`, `91_account_financial_activity` ("settled payments are shown once") | 2026-10-08: NEW pgTAP `160_pilot_reconciliation.sql` (#1917): one association member's month — subscription, overage, an approved expense share, a manual payment — gives the same 47.00 through `member_statement`, `invoice_lines_for` and the issued invoice; the payment is one credit line and never in the VAT base. The issued invoices then reach the accountant file whole: `accountant_handoff_flow_test` (#1885) parses the saved archive independently and finds every invoice once and each currency's gross equal to what was issued |
| Ordinary member / foreign workspace / revoked role refused; sign-out clears the cached scope; second-client changes and reconnect refresh the view | PASS | `test/lint/sign_out_test.dart`; `test/core/cache/cache_scope_test.dart`, `cache_store_barrier_test.dart` (#1849); `test/app/route_access_test.dart`; `test/core/realtime/channel_supervisor_test.dart`; pgTAP `10`, `11`, `12`, `157` | 2026-10-08: NEW `test/features/reservations/second_client_refresh_test.dart` — a booking made on another device turns the open plan's seat from free to reserved with no action on this device, and a booking committed while the channel was down lands through the reconnect resync; `test/core/realtime_sync_test.dart` covers a member change the same way. and a role given then taken on another device shows then hides this device's editor entry, through the same channel |
| Pilot feature list; excluded features and their dependencies; unqualified local legal issuance blocked | PASS (pinned) / PARTIAL | NEW `pilot_exclusions_test.dart`: onlinePayments, mcpAccess, accountingBook, guestParticipation, publicListings are off by default, stay off whatever the other flags are, and take their dependents with them. Issuance: migration 0385 (#1917, PR #2226) refuses an unreviewed seller country and an unresolved VAT rate at `create_invoice`; pgTAP `150` | 2026-10-08: automatic collection and tax filing are refused at the server and asserted — `open_payment_intent` refuses a new payment while `onlinePayments` is off (0393), a not-VAT-registered space cannot save a VAT return (0107), both in pgTAP `160`; silent VAT defaults refuse issuing (0393, pgTAP `150`). Still missing: the operator's reviewed feature/route/command list (see BLOCKED) |
| Backend compatible; restore rehearsal (database and objects) read back | PASS (disposable local) | `scripts/restore_check.sh --application`; [9 October report](evidence/pilot-recovery-2026-10-09.json) | Real local Auth sign-in, native export, database and private-object restore, exact financial readback, isolated installation identity and retained target MCP configuration passed. Deliberately damaged files were detected; owned stacks were removed. Schema 394 with the report’s pinned recovery-script hashes. Hosted recovery and email delivery were not exercised. |
| Privacy / rights / contact / security responsibility review | BLOCKED | — | The pilot operator is the sole reviewer (confirmed 9 October); the concrete review remains pending |
| Critical journey at narrow width, large text, keyboard, screen reader | PARTIAL | `test/a11y/responsive_matrix_test.dart` (360 dp, 2× text, keyboard, motion off), `screen_guidelines_test.dart`, `matrix_coverage_test.dart`; the new unavailable states (#1848) are covered by `unavailable_availability_test.dart` | Confirmation that every critical-journey screen is a matrix row, and a semantic-order walk of the journey |

## Accessibility follow-up — 9 October 2026 (#1974)

The matrix now measures Members, personal Settings, workspace administration,
Workspace settings and Workspace reports at narrow/wide widths, twice-normal
text, keyboard entry, labelled touch targets/contrast and reduced motion.
`flutter test test/a11y` passes 107 tests. Missed navigation taps now fail the
matrix instead of leaving it on the previous screen. The workspace-type switch
was missing its spoken label; merging its label and switch semantics fixes the
observed guideline failure. This improves the named screen coverage; it does
not substitute for the operator review or physical screen-reader qualification.

## Database follow-up — 9 October 2026 (#1917)

The reconciliation fixture now uses authenticated `record_payment` and a
separate operator's `respond_to_event`, instead of inserting a ledger credit.
Its 19 assertions pass: pending payment leaves the balance unchanged, approval
posts once, retrying approval is refused, and statement/invoice totals agree.
`163_unreviewed_invoice_treatment.sql` passes 11 assertions: unreviewed
cross-border, reverse-charge, export and exempt issuance is refused through
both readiness and the issuing command; ordinary domestic invoices and
statements remain available, and existing invoice snapshots remain identical.
These are rolled-back synthetic database proofs, not accountant approval of a
real workspace. The operator review and application journey remain outstanding.

## Browser rehearsal — 9 October 2026 (#1974, #2307)

PASS for the named local browser steps, using separate Edge owner and InPrivate
member sessions against a disposable local installation, never customer data.
Initial candidate `83402914f` (schema 394): native sign-in, join by code, pending
admission, owner approval from the blue alert badge, member entry, and a confirmed
A1 reservation. The owner explicitly enabled ordinary booking/calendar rights in
the fixture; membership alone did not grant these rights. The owner saw the other
member's reservation and management actions, with no double-booking action.

This uncovered a stale accessible seat handler after check-in and internal IDs
in first-steps copy. The corrections are in PR #2308. Repeating on browser build
`54c889506` passed booking → check-in → reopen → check-out without reloading;
the card showed “A1” and the actual state. A future reservation was cancelled,
then the owner booked its exact freed period. The ordinary member's seat sheet
showed the owner's reservation without an action to replace or double-book it.
Full-page reload preserved sign-in, membership and persisted reservation states.
Independent database readback found two completed bookings, one cancelled, and
one reserved by the second account. The original browser failure is also a
red-before/green-after semantic-action regression test.

Limits: this records two pinned local builds, not a production release or a
hosted-service rehearsal. A full OS/browser process termination and a physical
screen-reader session were not exercised. Database conflict/refusal and scoped
read proofs remain the named pgTAP tests above. Final merged-candidate release
and the pilot operator's review of COWORKONTI development remain outstanding.

## Remaining release gate

* The pilot exclusion set is now a named, tested list; widening it is a reviewed change.
* The local restore and named browser journey passed. Final release and operator
  review remain open; their missing evidence must be supplied before the
  pilot is called ready.

## Candidate re-run — 3 November 2026 (#1974)

Roles, not people. **Not one tree:** the results below ran on different trees, and
each row says which. This branch is based on master `351af01a6` (plus the new pilot
profile test and helper); master later moved to `a6c9aa7d8` (#3276: the strict
preview decoder and the pgTAP pins for #1917). Schema 664 is the latest migration on
both, and the dev project is at 664.

- The pgTAP bundles ran against the dev project's schema 664 (the same on both trees).
- The Dart run (207 tests), the lint suite (699) and the lint and workspace run
  (2,582) ran on this branch (`351af01a6` plus its changes). They do NOT include the
  strict preview decoder.
- The preview decoder's test ran in #3276, on `a6c9aa7d8` (the money and ux folders,
  2,808 passed; CI green).
- The restore rehearsal ran on `a6c9aa7d8`.

Database, as rolled-back real-pgTAP bundles on the dev project (each ends in
PGTAP_PASS; nothing persists): `161_pilot_journey` 14, `160_pilot_reconciliation`
19, `163_unreviewed_invoice_treatment` 11, `164_invoice_feature_guards` 14,
`191_credit_note_refund_not_reinvoiced` 7, `14_feature_gates` 16 — all PASS.

Dart, one run (exit 0, `All tests passed!`, 207 tests), through the guarded runner:

```
test/a11y test/ux/demo_journeys_test.dart
test/features/reservations/second_client_refresh_test.dart
test/features/reservations/check_in_presence_test.dart
test/features/money/accountant_handoff_flow_test.dart
test/core/cache test/core/realtime_sync_test.dart test/lint/sign_out_test.dart
test/app/route_access_test.dart
test/features/workspace/pilot_exclusions_test.dart
test/features/workspace/pilot_profile_test.dart
```

| Amendment item (2026-10-14) | Status | Evidence | What is not claimed |
|---|---|---|---|
| The effective pilot profile | PARTIAL: pinned as a golden list, not operator-reviewed | `test/helpers/pilot_profile.dart`, `pilot_profile_test.dart` and the golden `test/helpers/pilot_effective_features.txt` (52 features): the five excluded features explicitly OFF with every dependent; ON with their requirement chain: `invoicing` and `expenseRepartition` (the flags the pilot fixtures 160 and 164 enable; the test reads those files and fails if one is not named), `supplyClassification` and `configurableSettings` (named by the amendment); the exact effective set must equal the golden list, so a core default or an unlisted platform feature cannot change it unnoticed; a stored profile that leaves a required key out loses it (#2566: an absent platform flag is off) | The golden list is maintainer-derived from the current manifest, not an operator-reviewed inventory of the real workspace (#1285, where the feature profile was deliberately left unchanged); a feature the journey needs and no fixture names would be added by a reviewed change |
| Refund action (#2570) | PASS for the invoice lines and the ledger (fixed, not excluded) | `191_credit_note_refund_not_reinvoiced.sql` asserts the refund and adjustment lines of `invoice_lines_for` and the ledger/VAT; the spare-credit and bill-section assertions are in a separate Dart regression that was NOT in this run | `accountingBook` off is not what removes refunds; the refund is a supported command whose re-invoicing defect is fixed |
| Preview/result fields (#2585), invoices of zero category | PASS on this candidate (database); decoder: run in #3276 | `169_invoice_zero_category_series.sql` (29 assertions, rolled back on dev, this candidate). The preview decoder now refuses a line without its VAT rate (#1917): its test ran in #3276 (the money and ux folders, 2,808 passed, CI green at `a6c9aa7d8`), not in the runs listed above | |
| Small-server-cap traversal (#2587) | NOT RUN on this candidate | `scripts/snapshot_concurrency_check.sh` needs a local stack; no run was made today | #2586 (a denied image versus an optional absence) has no test that I found |
| Statement equals handoff | PARTIAL | `160` asserts the statement, `invoice_lines_for` and the issued invoice all total 4700. `accountant_handoff_flow_test` uses its own fake invoices and compares the archive's CSV to them; it asserts no 4700 | the two ends are not checked on one fixture: NOT RUN |

Run after the Dart and database runs, on 3 November, with the owner (the pilot
operator) present:

| Item | Status | Evidence | What is not claimed |
|---|---|---|---|
| Restore rehearsal (database and objects) | PASS (disposable local) on master `a6c9aa7d8`, schema 664 | `scripts/restore_check.sh --application`: source and target stacks, 38 database assertions (`12`, `20`, `22`, `23`, `28`), registered users, the native export, the existing-database drill, database backup and restore, storage restore, the target's native auth and reads, and storage damage detected; status `ready`, 100 s; report [3 November](evidence/pilot-recovery-2026-11-03.json) | hosted restore and email delivery are not exercised (the report says so); the report has no candidate-SHA field, so the SHA is recorded here |
| Screen reader on the pilot journey | PASS (one device) | The owner ran TalkBack on a Samsung Galaxy S23 Ultra, Android 16: open the plan, book a seat, the refused conflict, check in and out, cancel, My finances. All six steps OK. The app version was not recorded. | iPhone and VoiceOver; other Android versions |
| Two clients: live update, conflicting booking refused, reload, reconnect | PASS with one account | The owner ran two Edge windows (one InPrivate) both signed in with the same Google account | an owner and a separate ordinary member (a role change seen live, a member refused) was NOT RUN; it is covered by `second_client_refresh_test`, `realtime_sync_test`, pgTAP 10, 11, 12, 157 and 161. A run by the maintainer with two frames of one session booked a past period and proved nothing. |
| Privacy, rights, contact and security responsibility review | RECORDED | The operator's answers are on #1974 (2026-11-03): responsibility, data held, rights requests, owner/admin access, incident contact | the product does not yet implement the Personal Data Admin role, the birthday field, the workspace choice on rights requests or the incident-contact setting: #3278 |

Not re-run on this candidate: `scripts/snapshot_concurrency_check.sh` (#2587) and
the services/functions Deno tests; the two-account browser journey with a
separate member (above).
