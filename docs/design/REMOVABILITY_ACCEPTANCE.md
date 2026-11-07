# Removability acceptance (#3338, of epic #3328)

"Removable" is a claim until CI can say no. This map ties each acceptance row of
#3338 (and the three rows #3337 doubted) to the automated tests that prove it.
`test/lint/removability_matrix_test.dart` pins it: every cited path exists, a
covered row cites at least one test, every other row names what remains, and
the number below is the count of rows that are not covered (it only falls).

Open rows: 0

Row 7 is pinned to the client of `010b6df` (the request fields it sent, the
keys its readers decoded); a new client against an old server is the global
schema gate (`schema_compatibility_test`), unchanged. Row 8 runs in the
`quality · database` job: `instance_lifecycle_check` installs the bundle the
builder produces (round-tripped through its encoding) on empty projects,
resumes and upgrades it; `populated_upgrade_check` upgrades a supported
populated baseline over every migration file, which the bundle is built from
and pinned to by `instance_bundle_test`.

Honest limits. Local mocks and schema validation are local evidence; nothing
here claims a live exchange with a government platform (SdI, KSeF, ANAF, a
Peppol access point) -- external acceptance is a separate evidence level. A
row that needs a disposable database or the packaged installer names the job
that runs it. Packaging never raises a qualification level.

| # | scenario | owner | tests | state | remaining |
|---|---|---|---|---|---|
| 1 | A test-only country is added without editing core business decisions | #3331 #3333 #3337 | `test/core/jurisdiction/vat_filing_save_rows_test.dart`, `test/core/jurisdiction/invoice_profile_resolver_test.dart`, `supabase/functions/send-e-invoice/connectors_registry_test.ts` | covered | |
| 2 | Existing fixtures and refusals are unchanged after each extraction | #3330 #3332 #3333 #3334 #3337 | `test/parity/vat_filing_parity_test.dart`, `test/parity/export_registry_parity_test.dart`, `test/parity/fatturapa_parity_test.dart`, `test/parity/vat_forms_availability_parity_test.dart` | covered | |
| 3 | Disabling one capability leaves other countries and unrelated workflows working | #3336 | `supabase/tests/database/367_accounting_servicing_guard.sql`, `supabase/tests/database/368_capability_states.sql`, `supabase/tests/database/371_lifecycle_evidence.sql`, `test/core/jurisdiction/retired_italy_test.dart`, `supabase/functions/send-e-invoice/connectors_retired_test.ts` | covered | |
| 4 | A v1-issued invoice is unchanged after v2 deploy and deactivation | #3336 | `supabase/tests/database/369_provenance_envelopes.sql`, `supabase/tests/database/371_lifecycle_evidence.sql` | covered | |
| 5 | Deactivation during a submission preserves its receipt or an explicit unresolved outcome | #3335 #3336 | `supabase/tests/database/370_transmission_envelope.sql`, `supabase/tests/database/324_accounting_delivery_in_flight.sql`, `supabase/functions/send-e-invoice/handler_test.ts`, `scripts/einvoice_claim_race.sh` | covered | |
| 6 | Credential revocation works after deactivation | #3336 | `supabase/tests/database/367_accounting_servicing_guard.sql`, `supabase/functions/accounting-connect/lifecycle_test.ts`, `supabase/functions/accounting-connect/deliver_test.ts` | covered | |
| 7 | The previous supported client works against the upgraded backend | #3335 #3336 #3338 | `supabase/functions/send-e-invoice/handler_test.ts`, `test/features/money/einvoice_unresolved_test.dart`, `test/features/money/capability_lifecycle_compat_test.dart`, `test/core/instance/schema_compatibility_test.dart` | covered | |
| 8 | Fresh install and populated upgrade both include the required implementations, from the produced bundle | #3329 #3336 #3338 | `test/lint/instance_bundle_test.dart`, `scripts/instance_lifecycle_check.sh`, `scripts/populated_upgrade_check.sh` | covered | |
| 9 | Missing or conflicting jurisdiction support is an explicit refusal, never France | #3331 #3337 | `test/core/jurisdiction/jurisdiction_resolver_test.dart`, `test/core/jurisdiction/contribution_hardening_test.dart`, `test/core/jurisdiction/invoice_profile_resolver_test.dart`, `test/core/jurisdiction/retired_italy_test.dart` | covered | |
| 10 | Moving code into a package keeps its tests, static checks and schema validation in CI | #3329 #3337 | `test/lint/package_quality_test.dart`, `test/lint/test_inventory_test.dart`, `test/lint/dead_code_test.dart`, `test/lint/coverage_gate_test.dart`, `test/lint/jurisdiction_api_boundary_test.dart` | covered | |
| 11 | Removing a module reports the real work that still needs it, in EVERY space of the installation, by id, not a count; a one-space answer is never a proof | #3337 | `supabase/tests/database/373_jurisdiction_removal_facts.sql`, `test/lint/jurisdiction_removal_check_test.dart` | covered | |
| 12 | A shared serializer or provider stays usable after one country is retired | #3337 | `test/core/jurisdiction/retired_italy_test.dart`, `supabase/functions/send-e-invoice/connectors_retired_test.ts`, `supabase/functions/send-e-invoice/connectors_removal_test.ts` | covered | |
| 13 | Historical transmissions, artifacts and envelopes stay readable with the profile omitted | #3337 | `test/core/jurisdiction/retired_italy_test.dart`, `supabase/tests/database/369_provenance_envelopes.sql`, `supabase/tests/database/371_lifecycle_evidence.sql` | covered | |
