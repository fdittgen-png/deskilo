# Removability acceptance (#3338, of epic #3328)

"Removable" is a claim until CI can say no. This map ties each acceptance row of
#3338 (and the three rows #3337 doubted) to the automated tests that prove it.
`test/lint/removability_matrix_test.dart` pins it: every cited path exists, a
covered row cites at least one test, every other row names what remains, and
the number below is the count of rows that are not covered (it only falls).

Open rows: 4

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
| 6 | Credential revocation works after deactivation | #3336 | `supabase/tests/database/367_accounting_servicing_guard.sql`, `supabase/functions/accounting-connect/lifecycle_test.ts` | partial | a recovery request on a revoked connection makes no provider call (Deno, accounting-connect) |
| 7 | The previous supported client works against the upgraded backend | #3335 #3336 | `test/features/money/einvoice_unresolved_test.dart`, `test/features/money/capability_lifecycle_compat_test.dart` | partial | new-client against old-server handling under the current global schema gate; the old retry cannot bypass server fencing is shown for the transmission only |
| 8 | Fresh install and populated upgrade both include the required implementations | #3329 #3336 | `test/lint/instance_bundle_test.dart` | partial | apply the produced bundle to a disposable local instance, fresh and populated, in the database job |
| 9 | Missing or conflicting jurisdiction support is an explicit refusal, never France | #3331 #3337 | `test/core/jurisdiction/jurisdiction_resolver_test.dart`, `test/core/jurisdiction/contribution_hardening_test.dart`, `test/core/jurisdiction/invoice_profile_resolver_test.dart`, `test/core/jurisdiction/retired_italy_test.dart` | covered | |
| 10 | Moving code into a package keeps its tests, static checks and schema validation in CI | #3329 #3337 | `test/lint/package_quality_test.dart`, `test/lint/test_inventory_test.dart`, `test/lint/dead_code_test.dart`, `test/lint/coverage_gate_test.dart`, `test/lint/jurisdiction_api_boundary_test.dart` | covered | |
| 11 | Removing a module reports the real work that still needs it, by id, not a count | #3337 | `test/lint/jurisdiction_removal_check_test.dart` | open | the read-only reader of unsettled transmissions, enabled capabilities and open correction routes, and the removal check consuming its output |
| 12 | A shared serializer or provider stays usable after one country is retired | #3337 | `test/core/jurisdiction/retired_italy_test.dart`, `supabase/functions/send-e-invoice/connectors_retired_test.ts`, `supabase/functions/send-e-invoice/connectors_removal_test.ts` | covered | |
| 13 | Historical transmissions, artifacts and envelopes stay readable with the profile omitted | #3337 | `test/core/jurisdiction/retired_italy_test.dart`, `supabase/tests/database/369_provenance_envelopes.sql`, `supabase/tests/database/371_lifecycle_evidence.sql` | covered | |
