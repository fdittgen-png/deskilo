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
| Owner/admin/member journey: sign in → join/approve → plan → reserve → readback → conflicting second member refused → cancel/check-in/out → reload | PARTIAL | `test/ux/demo_journeys_test.dart` (book a desk, book as a member); `invitation_journey_test.dart`, `member_join_validation_test.dart`; `supabase/tests/database/24_booking_idempotency.sql` (a different key over the same hours is refused), `107`, `111`, `112`, `149` (transitions); `test/features/reservations/check_in_presence_test.dart`, `auto_check_in_out_test.dart` | One chained run on a real backend with a reload in between. The pgTAP files are not re-run here (no local runner) — CI's database job is their evidence |
| Subscription/usage + approved expense → manual payment → statement → handoff agree; payment is not a second charge | PARTIAL | `test/features/money/statement_test.dart`, `accountant_handoff_test.dart`, `accountant_handoff_flow_test.dart`, `export_reads_test.dart` (#1885 reads); pgTAP `22_reconciliation`, `40_payment_ledger_association`, `91_account_financial_activity` ("settled payments are shown once") | One fixture where the statement total equals the handoff total after a manual payment, with an approved expense |
| Ordinary member / foreign workspace / revoked role refused; sign-out clears the cached scope; second-client changes and reconnect refresh the view | PASS for the parts, PARTIAL end-to-end | `test/lint/sign_out_test.dart`; `test/core/cache/cache_scope_test.dart`, `cache_store_barrier_test.dart` (#1849); `test/app/route_access_test.dart`; `test/core/realtime/channel_supervisor_test.dart`; pgTAP `10`, `11`, `12`, `157` | A test where a second client's booking or role change plus a reconnect redraws the first client's view |
| Pilot feature list; excluded features and their dependencies; unqualified local legal issuance blocked | PASS (pinned) / PARTIAL | NEW `pilot_exclusions_test.dart`: onlinePayments, mcpAccess, accountingBook, guestParticipation, publicListings are off by default, stay off whatever the other flags are, and take their dependents with them. Issuance: migration 0385 (#1917, PR #2226) refuses an unreviewed seller country and an unresolved VAT rate at `create_invoice`; pgTAP `150` | A block on automatic collection and tax filing is not asserted by any test; the operator's reviewed feature/route/command list is not available (see BLOCKED) |
| Backend compatible; restore rehearsal (database and objects) read back | NOT RUN | `supabase/restore/*` and `tool/instance_lifecycle_check.dart` exist; `test/tool/psql_management_test.dart` | A rehearsal needs a scratch database and the object store; no such run was performed |
| Privacy / rights / contact / security responsibility review | BLOCKED | — | Needs the operator and the accountant; not fabricated |
| Critical journey at narrow width, large text, keyboard, screen reader | PARTIAL | `test/a11y/responsive_matrix_test.dart` (360 dp, 2× text, keyboard, motion off), `screen_guidelines_test.dart`, `matrix_coverage_test.dart`; the new unavailable states (#1848) are covered by `unavailable_availability_test.dart` | Confirmation that every critical-journey screen is a matrix row, and a semantic-order walk of the journey |

## What this changes

* The pilot exclusion set is now a named, tested list; widening it is a reviewed change.
* No claim is made that the chained journey, the restore rehearsal or the
  operator review passed. They remain open and are the rows to close before
  the pilot is called ready.
