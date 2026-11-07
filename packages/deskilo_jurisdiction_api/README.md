# deskilo_jurisdiction_api

The contract between the host (`lib/`) and a jurisdiction add-on for VAT
filing (#3331 of #3328). Pure Dart; it imports no application type, no
Flutter, no Supabase, no Riverpod (`test/lint/jurisdiction_api_boundary_test`).

* `CapabilityDescriptor` -- who implements what, at which versions.
* `FilingContext` -- everything one filing needs, immutable, with the moment
  of generation passed in: an implementation reads no clock, network or
  repository.
* `VatFilingContribution.validate` -> `ValidationResult` (stable issue codes,
  no user-facing text) and `.build` -> `GeneratedArtifact` (bytes, media type,
  file name, SHA-256 and provenance).

The host keeps source loading, authorization, dialogs, file saving, tracing
and export logging. The resolver (`lib/core/jurisdiction/`) chooses the
contribution; this package knows nothing of it.
