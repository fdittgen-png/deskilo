// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3380 — the lengths and precision of the pinned JPK_KR_PD(1) v1-1 schema,
// each named after the XSD type or element that fixes it. They are legal
// constants of the published schema, not business values: no setting, no UI
// point. `jpk_kr_pd_limits_test` reads every one from the schema fixture under
// `test/fixtures/saft/jpk_kr_pl` and fails when a constant differs, so a
// schema revision cannot diverge silently.

/// `Podmiot1/…/PelnaNazwa` (inline token, maxLength).
const int jpkKrPdLegalNameLength = 240;

/// `etd:TJednAdmin` — voivodeship, county and municipality.
const int jpkKrPdAdminUnitLength = 36;

/// `etd:TUlica`.
const int jpkKrPdStreetLength = 65;

/// `etd:TNrBudynku`.
const int jpkKrPdBuildingNumberLength = 9;

/// `etd:TMiejscowosc`.
const int jpkKrPdCityLength = 56;

/// `etd:TKodPocztowy`.
const int jpkKrPdPostalCodeLength = 8;

/// `TZnakowyJPK` — account identifiers and names, journal identifiers,
/// document and person fields, counterparty codes.
const int jpkKrPdTextLength = 256;

/// `TZnakowy512` — journal and line descriptions.
const int jpkKrPdLongTextLength = 512;

/// `etd:TNrIdentyfikacjiPodatkowej` — a counterparty's tax identifier.
const int jpkKrPdTaxIdLength = 50;

/// `TKwotowy` totalDigits: the largest amount in minor units the schema
/// type holds (eighteen digits).
const int jpkKrPdAmountDigits = 18;
