# Reviewed test cleanup

<!-- dated: 2026-10-03 — #2164, audit of master fae7f8f33 -->

The project-wide inventory contains 952 test files across the registered
Dart/Flutter, pgTAP and Edge runner families. A syntax-tree scan inspected
819 Dart files and 5,461 test callbacks. Five exact-body groups and 26
near-duplicate pairs were reviewed; similarity alone did not authorize
removal. Whole-file checks found no identical pgTAP or Edge test files.
This is a targeted redundancy audit, not a claim that every remaining
assertion has received a complete behavioral review.

## Removed and surviving proof

48 tests were removed from 33 files. No application code, database schema,
CI gate, coverage threshold or test-runner scope changes.

Three exact duplicate callbacks used the same fixtures and setup:

| File | Removed duplicate | Retained test |
| --- | --- | --- |
| `test/core/instance/instance_doctor_test.dart` | `#1314 — no migrations table and no tables is still the empty project` | `an empty project is an ALARM and says which command fixes it` |
| `test/features/profile/personal_info_test.dart` | repeated person/street/postal-city block | `#912 — the person moves INTO the block, under the company` |
| `test/features/money/accounting_formats_test.dart` | `the file still calls itself a subset, not a filing` | `the generic SAF-T calls itself a subset, not a filing` |

The other 45 callbacks asserted fixed substrings or shapes of historical
SQL files. Each referenced migration was independently checked against its
entry in `supabase/APPLIED.sha256` before removal. The surviving
`test/lint/applied_migrations_immutable_test.dart` protects every byte of
those files and tests edited, deleted and inserted historical migrations.
These text checks never executed SQL or proved current database behavior;
no pgTAP, role-isolation, concurrency or browser test was removed. The CI
migration replay and pgTAP suite remain in place. Hash validation is proof
of unchanged migration history, not a replacement claim of runtime SQL
correctness.

| Test file (under `test/`) | Removed SQL checks | Frozen migrations covered by the surviving hash gate |
| --- | ---: | --- |
| `core/i18n/app_format_test.dart` | 1 | `0132_globalization.sql` |
| `features/auth/badge_sign_in_test.dart` | 1 | `0124_badge_signin_flag_gate.sql` |
| `features/money/audit_followups_test.dart` | 3 | `0172_line_vat_normalised.sql`, `0173_orphan_vat_drafts.sql`, `0174_invoice_integrity.sql` |
| `features/money/billing_screen_test.dart` | 1 | `0109_configurable_tariff_accessory_vat.sql` |
| `features/money/credit_note_test.dart` | 1 | `0102_credit_note_refunds.sql` |
| `features/money/dunning_test.dart` | 1 | `0093_dunning_rules.sql` |
| `features/money/expense_repartition_test.dart` | 1 | `0147_expense_repartition.sql` |
| `features/money/invoice_settlement_fold_test.dart` | 1 | `0148_settlement_fold.sql` |
| `features/money/invoice_writeoff_test.dart` | 1 | `0100_invoice_writeoff.sql` |
| `features/money/legal_invoice_test.dart` | 2 | `0094_invoice_legal.sql`, `0095_vat_regime_gate.sql` |
| `features/money/number_sequences_test.dart` | 1 | `0217_number_series_never_repeat.sql` |
| `features/money/partial_rematch_test.dart` | 1 | `0101_partial_rematch.sql` |
| `features/money/payment_process_test.dart` | 1 | `0103_account_reality.sql` |
| `features/money/reminder_level_lock_test.dart` | 6 | `0162_reminder_level_lock.sql` |
| `features/money/report_language_test.dart` | 1 | `0098_member_preferred_locale.sql` |
| `features/money/reverse_charge_test.dart` | 1 | `0157_reverse_charge.sql` |
| `features/money/site_documents_test.dart` | 1 | `0169_site_documents.sql` |
| `features/money/vat_declarations_test.dart` | 1 | `0107_vat_declarations.sql` |
| `features/money/vat_groups_test.dart` | 1 | `0170_vat_groups.sql` |
| `features/money/vat_test.dart` | 1 | `0072_vat_management.sql`, `0156_credit_note_vat.sql` |
| `features/money/workspace_status_test.dart` | 1 | `0167_workspace_status.sql` |
| `features/profile/whatsapp_presence_migration_test.dart` | 5 | `0028_profile_whatsapp_presence.sql` |
| `features/reservations/reservation_delete_request_test.dart` | 2 | `0097_reservation_delete_requests.sql`, `0111_delete_request_supersede.sql` |
| `features/workspace/booking_granularity_test.dart` | 1 | `0087_working_hours.sql` |
| `features/workspace/conversations_test.dart` | 2 | `0127_conversations_last_at.sql` |
| `features/workspace/documents_test.dart` | 1 | `0099_workspace_documents.sql` |
| `features/workspace/inbox_test.dart` | 1 | `0130_backfill_conversations.sql` |
| `features/workspace/member_notes_test.dart` | 1 | `0105_member_note_read_receipts.sql` |
| `features/workspace/messages_hub_test.dart` | 1 | `0146_conversation_prefs.sql` |
| `features/workspace/sites_test.dart` | 2 | `0168_sites.sql`, `0171_site_registrations.sql` |

## Deliberately retained

- Identical-looking `sql` assertions that read different migrations are
  not duplicate execution contexts; live client/SQL constant cross-checks
  remain, including booking wire values, calendar kinds and VAT treatment.
- The two PDF smoke callbacks call different local builders. The similar
  invoice-logo cases use different report headers. Both pairs remain.
- Near matches for zero versus excessive amounts, old versus newer schema,
  account versus installation scope, and opposite time boundaries remain.
- Tests skipped unless a disposable backend/device fixture is supplied
  remain; absence of an everyday runner does not make them obsolete.
- Meaningful registry, permission, route, serialization and accessibility
  contracts remain. No test was deleted because it failed.

The deleted standalone files were `whatsapp_presence_migration_test.dart`
and `reminder_level_lock_test.dart`; both contained only the frozen SQL
text checks listed above. Affected headers and unused imports were cleaned
up. The generated inventory is produced by CI and is not committed.
