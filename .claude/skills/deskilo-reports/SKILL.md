---
name: deskilo-reports
description: Everything printed in DesKilo — report kinds, the placeholder registry and its pins, banded defaults vs positioned layouts, owner texts, the letter standard, the report CLI (check/render/sample/describe/default), data-map builders and their call sites. Trigger for any change to invoices, letters, reports, templates, placeholders or the designer.
---
# Reports in DesKilo

## Registries (all move together)
- Kind: `domain/report_kind.dart` (`ReportKind(id, slot)`), label in
  `presentation/report_kind_labels.dart`, default bands in
  `report_defaults.dart` (`defaultXBands`, the preset chain in
  `presetsForDoc`, `defaultBandsForDoc`), lint `report_kind_registry_test`.
- Placeholders: `InvoicePdfTemplate.placeholders` (+ `_listPlaceholders`
  for loops, `_flagPlaceholders` for bools) → pin in
  `invoice_template_test` ("pins the data fields", ORDER matters) →
  `report_sample_data.dart` → `report_field_picker.dart` group + markup.
  `placeholderDefaults` seeds every key EMPTY (#875) — a nil placeholder
  passes `{% if x != "" %}`; nested maps need a defaulting map
  (`OwnerTexts`, `text.<key>`).
- Data maps: `invoiceReportData`, `statementReportData`,
  `agreementReportData`, `paymentsReportData`, `usageReportData`,
  `vatReportData`, `reminderReportData`, all spreading
  `legalMentionData` (bank block, mentions, client identity, effective
  payment conditions, statutory exemption mention). New per-document
  facts go into the builder, then `withOwnerTexts(data, template.texts)`
  at the render site.

## Rendering paths
- Bands: `renderReportBands(bands, data)` → `InvoiceReport`.
- Positioned: `renderLayoutDocument(xml, data)` → `buildLayoutPdf` — the
  layout WINS when `template.layoutFor(kind)` is set; with the
  `letterStandard` flag a person-facing kind without a design renders
  `defaultLetterLayoutXml` (domain `report_letter_layouts.dart`, pure
  Dart with `LetterStrings`; the app adapter `resolveLayoutXmlFor`
  counts customised BANDS as a design). `tryLayoutPdf` must never throw:
  any failure logs and falls back to bands.
- Window-envelope contract (AGENT_RULES): sender 20/20, recipient
  110/45 in 85×40, body from 90 mm, footer every page, continuation p2+.
  Prove on the PDF with `textPositions(bytes)` (InkAt xMm/yMm/page).

## CLI (pure Dart — never import Flutter/l10n from what it uses)
```
dart run tool/report.dart check <layout.xml> [--data d.json]
dart run tool/report.dart render|sample --kind usage|describe|default --kind r1
```
`test/tool/report_cli_test.dart` breaks the moment a domain file pulls
`AppLocalizations`.

## Designer
Language chips → base + overlays (`forLocale` merges documents, layouts,
texts); panels mount LAST in the column; anything that adds height
must be collapsed by default (tests tap the Markup/Visual toggle).
