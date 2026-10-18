# ADR 0043 — A feature can be available in only some countries

**Status:** accepted · **Date:** 2026-10-18 · **Refs:** #2454, #2519, #2476

## Context
Country already gates the data of legal features (rate catalogues, return
forms, e-invoicing routes, export formats) but never the features themselves:
an owner in a country a legal feature does not serve still sees the switch,
and the server answers the same for every country.

## Decision
1. **Which country: the workspace's.** The legal features are really
   issuer-scoped (the seller country can differ from the workspace country,
   #2356); the workspace country is a proxy, and the only one every space has.
   Issuer and customer country are not modelled here.
2. **Derived, never stored.** `FeatureManifestEntry.availableIn` (null =
   every country) is a third layer beside the `requires` chain:
   `effectiveFeatures(raw, country: …)` drops a feature whose set excludes the
   country. The stored flag in `workspaces.feature_flags` is untouched, so the
   feature returns exactly as configured if the country ever matches.
3. **One list, not two.** A member of `availableIn` is an ISO code or
   `@eu`, which stands for the `eu_member` rows of the tax reference store
   (ADR 0041); the Dart resolver (`featureAvailableIn`) and its SQL twin
   (`feature_available_in`) both read those rows. The SQL registry
   (`feature_registry()`, generated from the manifest) carries `countries`.
4. **The server refuses too.** `feature_effective(workspace, key)` is the
   stored switch over the registry chain AND the availability of the
   workspace country; every gated RPC already calls it. A feature with no
   `countries` entry answers exactly as before.
5. **Disabled with the reason, not hidden** (the client surface follows in
   its own checkpoint). No per-server restriction: that is another axis.

## The pilot
Only `recapitulativeStatement` is gated, to the EU: the EC Sales List is an
obligation of sellers in the Union (`place_of_supply.dart`, 0405). Candidates
dropped because their gate would be a guess: `viesVerification` (a seller
outside the Union verifies EU buyers' numbers), `vatDeclarations` (a country
without a form still gets the generic return), `holidayImport` (the source
covers every catalogue country), `einvoiceCustomerDelivery` (a generic
Peppol path exists), `accountingBook` (any chart works).

## Consequences
A British space that stored the statement ON keeps the stored switch but does
not have the feature; French and German spaces see no change. The generator
and its drift lint carry `countries`; a country list typed twice is the drift
this rule exists to forbid.
