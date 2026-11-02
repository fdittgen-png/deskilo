# JPK_KR_PD(1) schema fixture

The Ministry of Finance publishes `JPK_KR_PD(1)` schema version 1-1 at
https://www.gov.pl/web/kas/struktury-jpk-w-podatkach-dochodowych (attachment
`4ec8f106-032c-42f2-9fb5-15b5ec5ca670`). The XSD and its four dependency
schemas are preserved verbatim; `catalog.xml` resolves their original import
URLs to the local files for offline validation.

`jpk_kr_pl` is the application's historical profile identifier; this
checkpoint targets **JPK_KR_PD(1) v1-1**, the income-tax accounting-books
structure selected in DECISION2379-PL-1. It does not implement the separate
on-demand **JPK_KR** structure. The Ministry lists JPK_KR on its
[on-demand page](https://podatki.gov.pl/podatki-firmowe/jednolity-plik-kontrolny/jpk-na-zadanie)
and explains JPK_KR_PD's phased applicability from 2025, 2026 or 2027 by
taxpayer category on its [income-tax structures page](https://www.gov.pl/web/kas/struktury-jpk-w-podatkach-dochodowych).
Neither the identifier nor this fixture determines a particular entity's
filing obligation. JPK_ST_KR and other Polish filings are outside this profile.

The supported schema shape includes Naglowek and Podmiot1, ZOiS7 for the
explicitly selected other-entity category, Dziennik with KontoZapis, Ctrl,
and RPD. Counterparty and KSeF fields are supplied where applicable. Other
ZOiS categories are refused. The existing source supplies postings, chart
names and some document-party identities, but it does not establish a single
complete frozen source with the necessary journal sequence and responsible
person, Polish account markers and debit/credit balances, tax office,
KSeF association and K_1–K_8 income-tax reconciliation. Those facts are
required explicitly or the writer refuses by name. Production does not yet
have a verified producer for them; synthetic facts do not prove coverage.

`schema_probe.xml` is synthetic structural test data. A passing XSD check
proves only schema conformance, not complete books, correct accounting or
acceptance by the Polish tax authority. It must never be submitted.
