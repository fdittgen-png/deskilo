# Pilot journey evidence — #1974

Candidate: master `9c76375e0` plus `test/features/workspace/pilot_exclusions_test.dart`.
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
| Privacy / rights / contact / security responsibility review | BLOCKED | — | Florian is the sole reviewer (confirmed 9 October); the concrete review remains pending |
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
and Florian's review of COWORKONTI development remain outstanding.

## Remaining release gate

* The pilot exclusion set is now a named, tested list; widening it is a reviewed change.
* The local restore and named browser journey passed. Final release and operator
  review remain open; their missing evidence must be supplied before the
  pilot is called ready.
