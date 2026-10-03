---
name: deskilo-reports
description: Everything DesKilo prints — report kinds, the placeholder registry and its order pin, data-map builders and ReportStrings, banded defaults vs positioned layouts and the letter standard, the report CLI (check/render/sample/describe/default), the byte-identical goldens, where each document concern lives after the #1061 split, the designer. Trigger for any change to invoices, letters, statements, reports, templates, placeholders, the report designer or tool/report.dart. The window-envelope millimetres themselves are in AGENT_RULES.
---
# Reports in DesKilo

Binding rules: AGENT_RULES "Printed reports: the window-envelope contract",
"Positioned report layouts" (the CLI workflow) and "The identity form is ONE form".

**Essentials**
1. Kind, label, default bands and the kind lint move together; a placeholder moves registry → order pin → sample data → field picker.
2. Builders are pure `domain/` functions taking `ReportStrings` and `*Facts` — never a `BuildContext` or `AppLocalizations`.
3. A positioned layout wins over bands; `tryLayoutPdf` never throws (falls back to bands, traced).
4. Prove geometry on the PDF (`textPositions`, `invoice_geometry_test`), never on the widget tree.
5. Goldens are byte-identical; regenerate only when a document is MEANT to change, and say so.

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
- Window-envelope contract: the millimetres live in AGENT_RULES and once in
  code (`domain/report_conformance.dart`, `domain/address_window.dart`).
  Prove on the PDF with `textPositions(bytes)` (InkAt xMm/yMm/page).

## CLI (pure Dart — never import Flutter/l10n from what it uses)
`dart run tool/report.dart check|render <layout.xml> [--data d.json] [--out x.pdf]`,
`sample [--kind k] [--out d.json]`, `describe`, `default --kind k` — the check
workflow is in AGENT_RULES "Positioned report layouts".
`test/tool/report_cli_test.dart` breaks the moment a domain file pulls
`AppLocalizations`.

## Words reach a builder as DATA — `ReportStrings` (#1061 / #1048 3.1)
`domain/report_strings.dart` is the twin of `LetterStrings`: a value
object with the English ARB as defaults. `reportStringsOf(l10n)` in
`presentation/report_strings_l10n.dart` is the ONE place a document's
words are read out of the ARB; `reportStringsFor(context)` is the
widget boundary. `invoiceReportData`, `legalMentionData`,
`invoiceLineText`, `annexEntryText`, `subscriptionLabel` take
`ReportStrings`, never a `BuildContext` or an `AppLocalizations`.
- A new word a document needs: one field on `ReportStrings` (English
  default = the en ARB, pinned by `report_strings_test`), one line in
  `reportStringsOf`. Never `l10n?.x ?? '…'` inside a builder again.
- The goldens under `test/features/money/goldens/` were written by the
  PRE-seam builders; `report_data_golden_test` asserts every document
  is byte-identical. Regenerate with `--dart-define=WRITE_GOLDEN=true`
  ONLY when a document is MEANT to change, and say so in the PR.
- Not a second localization mechanism: per-language templates and
  reader-language resolution are untouched; only how the resolved words
  reach a builder changed.

### Where the document code lives after the #1061 split
| File | Concern |
|---|---|
| `domain/report_data.dart` | `legalMentionData`, `invoiceReportData`, `clientAddressOf`, `siteNameOf`… — pure |
| `domain/report_data_letters.dart` | statement / agreement / payments / workspace / reminder builders — pure, take a `*Facts` |
| `domain/report_facts.dart` | the facts values; `presentation/report_facts_of.dart` fills them from the ref (the ONLY provider reads) |
| `presentation/invoice_documents.dart` | document GENERATION: `buildInvoicePdfFile`, `buildFacturXFile`, `buildReminderPdfFile`, `letterDocPdf`, `renderLetterDoc`, `invoicePdfTemplateFor`, `memberTermsFor`, `l10nForLanguage` |
| `presentation/invoice_actions.dart` | the dialogs and the actions the buttons run — nothing else |
| `presentation/widgets/template_live_data.dart` | what the designer previews a design against |
A new builder is a pure function in `domain/`, with its facts gatherer
in `report_facts_of.dart`; a new render path is `invoice_documents.dart`;
a new button is `invoice_actions.dart`. The length lint pins each.

## Designer
Language chips → base + overlays (`forLocale` merges documents, layouts,
texts); panels mount LAST in the column; anything that adds height
must be collapsed by default (tests tap the Markup/Visual toggle).

## Month on the recurring position (#1000/#1002)
`subscriptionLabel(strings, pct, association:, month:)` names the month
when given one; every surface passes `period:` to `invoiceLineText`
(PDF, CII/UBL, detail sheet, form preview, bill). Placeholders
`period_month`, `period_year`; each `lines` row carries `kind`, `pct`,
`month` — the picker's `lines` scaffold shows the wording
`{% if line.kind == "subscription" %}{{ line.month }} {{ line.pct }} %{% else %}{{ line.label }}{% endif %}`.
`monthNameOf(locale, period)` is pure (no BuildContext) — the CLI's
`sample` and `describe` carry every placeholder, or `report_cli_test`
fails. The FEC/SAF-T builders still receive the line without its
invoice: their labels keep the old wording until the signature changes.
