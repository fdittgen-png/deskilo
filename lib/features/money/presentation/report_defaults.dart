// SPDX-License-Identifier: 0BSD
//
// The SHIPPED report templates (#470/#472/#480) — every document in the
// template language, localized, and LEGALLY COMPLETE: the invoice
// presets print the seller's statutory identity (legal form, register,
// VAT number), the client's address, per-line quantity/unit price/VAT
// rate, the per-rate VAT table with total HT/TVA/TTC, and the four
// mandatory payment clauses (terms, escompte, late penalty, recovery
// indemnity). Nobody starts from scratch: the editor's Reset inserts
// these, and a document the owner never customized renders with them.
// Every document ships the same four presets: Simple · Classic ·
// Verbose · Formal (#480).
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
// The three #671 documents (CoA preview, badge sheet, space codes) live
// in their own file; they are re-exported so every caller keeps
// resolving document defaults from one import.
import 'report_defaults_batch.dart';
export 'report_defaults_batch.dart';
// The preview fixture is a different concern from the shipped templates
// — sample text, never live data — and lives on its own.
export 'report_sample_data.dart';

/// The seller's statutory identity block, shared by every preset's
/// header: name, legal form & capital, address, trade register and VAT
/// number — each line only when the workspace declared it.
String _sellerBlock(AppLocalizations? l10n) => '''
{{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
> {{ workspace_address }}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}
{% if seller_vat_id != "" %}> ${l10n?.legalIdentityVatId ?? 'VAT number'}: {{ seller_vat_id }}{% endif %}''';

/// The statutory payment-clause footer every invoice-like document must
/// carry: payment terms + escompte, penalty + recovery indemnity, then
/// the optional insurance and special-regime mentions.
String _legalFooter(AppLocalizations? l10n) => '''
> {{ payment_terms }}{% if escompte != "" %} — {{ escompte }}{% endif %}
{% if late_penalty != "" %}> {{ late_penalty }}{% endif %}
{% if recovery_indemnity != "" %}> {{ recovery_indemnity }}{% endif %}
{% if insurance != "" %}> {{ insurance }}{% endif %}
{% if special_mentions != "" %}> {{ special_mentions }}{% endif %}''';

/// The built-in invoice layout as editable bands — the CLASSIC preset,
/// legally complete (#480).
InvoicePdfTemplate defaultInvoiceTemplate(AppLocalizations? l10n) {
  final classic = _invoicePresetBands(l10n, 'classic');
  return InvoicePdfTemplate(
    header: classic.header,
    body: classic.body,
    footer: classic.footer,
  );
}

ReportBands _invoicePresetBands(AppLocalizations? l10n, String id) {
  final title =
      '{% if credit_note %}${l10n?.invoicePdfCreditNote ?? 'Credit note'}{% elsif proforma %}${l10n?.invoicePdfProforma ?? 'Proforma'}{% else %}${l10n?.invoicePdfTitle ?? 'Invoice'}{% endif %}';
  // Row 1 of the facture layout (#482): brand left, document title +
  // reference/date block right.
  final brandRow = '''
:::
# {{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
|||
## $title
{{ number }}
> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} · {{ issued_by }}
{% if replaces != "" %}> ${l10n?.invoicePdfReplaces ?? 'Replaces'} {{ replaces }}{% endif %}
:::''';
  // Row 2: seller coordinates left, client box right.
  final addressRow = '''
:::
{{ workspace }}
> {{ workspace_address }}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}
{% if seller_vat_id != "" %}> ${l10n?.legalIdentityVatId ?? 'VAT number'}: {{ seller_vat_id }}{% endif %}
|||
${l10n?.invoicePdfBilledTo ?? 'Billed to'}
{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}
{% if client_legal_id != "" %}> {{ client_legal_id }}{% endif %}
{% if client_vat_id != "" %}> ${l10n?.legalIdentityVatId ?? 'VAT number'}: {{ client_vat_id }}{% endif %}
> {{ period }}
:::''';
  // The line table with its column headers, then the right-aligned
  // totals block (empty first column pushes it right, like the model).
  final lineTable =
      '= ${l10n?.invoicePdfDescription ?? 'Description'} | ${l10n?.reportColUnitPrice ?? 'Unit price'} | ${l10n?.reportColQty ?? 'Qty'} | ${l10n?.reportColTotal ?? 'Total'}\n'
      '{% for line in lines %}{{ line.label }} | {{ line.unit_price }} | {{ line.qty }} | {{ line.amount }}\n'
      '{% endfor %}';
  final totalsBlock = '''
:::
|||
${l10n?.vatPdfNet ?? 'Net'} | {{ net_total }}
{% if has_vat %}{% for v in vat %}${l10n?.vatPdfVat ?? 'VAT'} {{ v.rate }} | {{ v.amount }}
{% endfor %}{% endif %}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}
:::''';
  const mentions = '''
{% if exemption_reason != "" %}> {{ exemption_reason }}
{% endif %}> {{ payment_terms }}{% if escompte != "" %} — {{ escompte }}{% endif %}''';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '''
$brandRow
---
$addressRow''',
        body: '''
{% for line in lines %}{{ line.label }}{% if line.vat_rate != "" %} · ${l10n?.vatPdfVat ?? 'VAT'} {{ line.vat_rate }}{% endif %} | {{ line.amount }}
{% endfor %}---
$totalsBlock
$mentions''',
        footer: _legalFooter(l10n),
      );
    case 'verbose':
      return ReportBands(
        header: '''
$brandRow
---
$addressRow''',
        body: '''
= ${l10n?.invoicePdfDescription ?? 'Description'} | ${l10n?.reportColUnitPrice ?? 'Unit price'} | ${l10n?.reportColQty ?? 'Qty'} | ${l10n?.vatPdfNet ?? 'Net'} | ${l10n?.vatPdfVat ?? 'VAT'} | ${l10n?.reportColTotal ?? 'Total'}
{% for line in lines %}{{ line.label }} | {{ line.unit_price }} | {{ line.qty }} | {{ line.net }} | {{ line.vat_rate }} | {{ line.amount }}
{% endfor %}---
:::
|||
${l10n?.invoicePdfCharges ?? 'Charges'} | {{ charges }}
${l10n?.invoicePdfPayments ?? 'Payments'} | {{ payments }}
${l10n?.vatPdfNet ?? 'Net'} | {{ net_total }}
{% if has_vat %}{% for v in vat %}${l10n?.vatPdfVat ?? 'VAT'} {{ v.rate }} | {{ v.amount }}
{% endfor %}${l10n?.vatPdfVat ?? 'VAT'} | {{ vat_total }}
{% endif %}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}
:::
$mentions''',
        footer: _legalFooter(l10n),
      );
    case 'formal':
      return ReportBands(
        header: '''
:::
{{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
> {{ workspace_address }}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}
{% if seller_vat_id != "" %}> ${l10n?.legalIdentityVatId ?? 'VAT number'}: {{ seller_vat_id }}{% endif %}
|||
{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}
{% if client_vat_id != "" %}> ${l10n?.legalIdentityVatId ?? 'VAT number'}: {{ client_vat_id }}{% endif %}

> {{ issued }}
:::''',
        body: '''
## ${l10n?.reportSubject ?? 'Subject'}: $title {{ number }} — {{ period }}

{{ member }},

$lineTable---
$totalsBlock
$mentions''',
        footer: '''
${_legalFooter(l10n)}

${l10n?.reportRegards ?? 'Kind regards'},
{{ issued_by }}''',
      );
    default: // classic — the built-in default, the facture layout.
      return ReportBands(
        header: '''
$brandRow
---
$addressRow''',
        body: '''
$lineTable---
$totalsBlock
$mentions''',
        footer: _legalFooter(l10n),
      );
  }
}

/// The shipped letter for reminder [level] (1-based) — the CLASSIC
/// preset: level 1 is the friendly Zahlungserinnerung, higher levels
/// read firmer and carry the level number. All content is template
/// language over the reminder data — the owner edits any level
/// independently in the report editor.
ReportBands defaultReminderBands(int level, AppLocalizations? l10n) =>
    _reminderPresetBands(level, l10n, 'classic');

String _reminderTitle(int level, AppLocalizations? l10n) => level <= 1
    ? (l10n?.reminderPdfTitleFriendly ?? 'Payment reminder')
    : '${l10n?.reminderPdfTitleFirm ?? 'Reminder'} $level';

String _reminderOpening(int level, AppLocalizations? l10n) => level <= 1
    ? (l10n?.reminderPdfOpeningFriendly ??
        'this is a friendly reminder that the invoice below is still '
            'open. Perhaps it simply slipped through — no worries.')
    : (l10n?.reminderPdfOpeningFirm ??
        'despite our previous reminder, the invoice below remains '
            'unpaid. Please settle the amount without delay.');

ReportBands _reminderPresetBands(
    int level, AppLocalizations? l10n, String id) {
  final title = _reminderTitle(level, l10n);
  final opening = _reminderOpening(level, l10n);
  final invoiceRecap = '''
## ${l10n?.invoicePdfTitle ?? 'Invoice'}
{{ number }} · ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} | {{ total }}
> ${l10n?.reminderPdfDaysOpen ?? 'Open for'} {{ days_open }} ${l10n?.reminderPdfDays ?? 'days'} · ${l10n?.reminderPdfLevelLabel ?? 'Reminder level'} {{ reminder_level }}''';
  final closing =
      '> ${l10n?.reminderPdfClosing ?? 'If you have already paid, please disregard this letter.'}';
  // A reminder cites the statutory late-payment clauses (#480) — on the
  // firm levels they are the point of the letter.
  // Guarded (#484): an association prints none of these by default.
  const clauses =
      '{% if late_penalty != "" %}> {{ late_penalty }}\n{% endif %}'
      '{% if recovery_indemnity != "" %}> {{ recovery_indemnity }}\n{% endif %}';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '# $title',
        body: '''
{{ member }} — {{ number }} ({{ issued }})
> ${l10n?.reminderPdfDaysOpen ?? 'Open for'} {{ days_open }} ${l10n?.reminderPdfDays ?? 'days'}
= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: '$clauses\n$closing',
      );
    case 'verbose':
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> {{ reminder_date }}
---''',
        body: '''
{{ member }},
{% if client_address != "" %}> {{ client_address }}{% endif %}

$opening

$invoiceRecap
---
> {{ payment_terms }}
$clauses
= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: closing,
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}

> {{ reminder_date }}''',
        body: '''
## ${l10n?.reportSubject ?? 'Subject'}: $title — ${l10n?.invoicePdfTitle ?? 'Invoice'} {{ number }}

{{ member }},

$opening

{{ number }} · {{ issued }} | {{ total }}
---
$clauses
= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: '''
$closing

${l10n?.reportRegards ?? 'Kind regards'},
{{ workspace }}''',
      );
    default: // classic
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> {{ reminder_date }}
---''',
        body: '''
{{ member }},

$opening

$invoiceRecap
---
$clauses
= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: closing,
      );
  }
}

/// The built-in member-statement document (#476) as editable bands —
/// the CLASSIC preset.
ReportBands defaultStatementBands(AppLocalizations? l10n) =>
    _statementPresetBands(l10n, 'classic');

ReportBands _statementPresetBands(AppLocalizations? l10n, String id) {
  const lines = '{% for line in lines %}'
      '{{ line.label }} | {{ line.amount }}\n{% endfor %}';
  final balance = '= ${l10n?.billBalance ?? 'Balance'} | {{ total }}';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '# {{ member }} — {{ period }}',
        body: '$lines$balance',
      );
    case 'verbose':
      return ReportBands(
        header: '''
# ${l10n?.billPdfTitle ?? 'Statement'} — {{ period }}
${_sellerBlock(l10n)}
> {{ member }}
---''',
        body: '''
## ${l10n?.invoicePdfDescription ?? 'Description'}
$lines---
${l10n?.invoicePdfCharges ?? 'Charges'} | {{ charges }}
${l10n?.invoicePdfPayments ?? 'Payments'} | {{ payments }}
$balance''',
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}

> {{ period }}''',
        body: '''
## ${l10n?.reportSubject ?? 'Subject'}: ${l10n?.billPdfTitle ?? 'Statement'} — {{ period }}

{{ member }},

$lines---
$balance''',
        footer: '''
${l10n?.reportRegards ?? 'Kind regards'},
{{ workspace }}''',
      );
    default: // classic
      return ReportBands(
        header: '''
# ${l10n?.billPdfTitle ?? 'Statement'} — {{ period }}
{{ workspace }}
> {{ member }}
---''',
        body: '$lines---\n$balance',
      );
  }
}

/// The FINANCIAL AGREEMENT document (#494) as editable bands.
ReportBands defaultAgreementBands(AppLocalizations? l10n) =>
    _simpleDocPresetBands(
        l10n, 'classic', l10n?.reportDocAgreement ?? 'Financial agreement',
        subtitle: '{{ member }}');

/// The MONTHLY PAYMENTS document (#494) as editable bands.
ReportBands defaultPaymentsBands(AppLocalizations? l10n) =>
    _simpleDocPresetBands(
        l10n, 'classic', l10n?.reportDocPayments ?? 'Payments report',
        subtitle: '{{ member }} — {{ period }}',
        totalsLine:
            '= {{ payments }} | {% if pending_total != "" %}{{ pending_total }}{% endif %}');

/// The CONSUMPTION REPORT (#873): what the month's participation paid
/// for, what was actually consumed, what is left or exceeded — and the
/// records behind the numbers. Sent to the member at month end.
ReportBands defaultUsageBands(AppLocalizations? l10n) => ReportBands(
      header: '''
# {{ workspace }}
> {{ workspace_address }}
> {{ issued }}
---
# ${l10n?.reportDocUsage ?? 'Consumption report'}
> {{ member }} — {{ period }}''',
      body: '''
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}
{% if usage_overage != "" %}> ${l10n?.usageReportOverage ?? 'Overage carried to the next invoice'} : {{ usage_overage }}{% endif %}

## ${l10n?.usageReportRecordsHeading ?? 'What was consumed'}
{% for r in usage_records %}{{ r.date }} | {{ r.space }} | {{ r.counted }}
{% endfor %}''',
      footer: _legalFooter(l10n),
    );

/// The VAT REPORT (#878): every position of the period by rate, the
/// subtotals per rate and category, the period totals — what the
/// accountant reconciles against the declaration boxes.
ReportBands defaultVatBands(AppLocalizations? l10n) => ReportBands(
      header: '''
# {{ workspace }}
> {{ workspace_address }}
> {{ issued }}
---
# ${l10n?.reportDocVat ?? 'VAT report'}
> {{ vat_period }}
> {{ vat_basis_note }}''',
      body: '''
## ${l10n?.vatReportPositions ?? 'Positions'}
{% for p in vat_positions %}{{ p.number }} · {{ p.date }} · {{ p.customer }}{% if p.reverses != "" %} ⟲ {{ p.reverses }}{% endif %} | {{ p.rate }} {{ p.category }} | {{ p.net }} | {{ p.vat }} | {{ p.gross }}
{% endfor %}
## ${l10n?.vatReportByRate ?? 'Totals per rate'}
{% for t in vat_rate_totals %}{{ t.rate }} {{ t.category }} · {{ t.count }} | {{ t.net }} | {{ t.vat }} | {{ t.gross }}
{% endfor %}---
= ${l10n?.vatReportTotals ?? 'Period totals'} | {{ vat_period_net }} | {{ vat_period_vat }} | {{ vat_period_gross }}''',
      footer: _legalFooter(l10n),
    );

/// The WORKSPACE REPORT document (#494) as editable bands.
ReportBands defaultWorkspaceBands(AppLocalizations? l10n) => ReportBands(
      header: '''
# {{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
> {{ workspace_address }}
> {{ issued }}
---''',
      body: '''
{{ country }} · {{ currency }} · {{ timezone }}
> {{ members_count }} · {{ levels_count }} / {{ offices_count }} / {{ desks_count }} / {{ seats_count }}
> {{ open_days }} · {{ work_hours }}

## ${l10n?.reportSectionFeatures ?? 'Features'}
{% for f in features %}{{ f.label }}
{% endfor %}
## ${l10n?.reportSectionPrices ?? 'Prices'}
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}''',
      footer: _legalFooter(l10n),
    );

/// The shared letter shape of the simple per-member documents (#494):
/// title + recipient, the lines, an optional totals row, the legal
/// footer. [totalsLine] defaults to the plain balance row.
ReportBands _simpleDocPresetBands(
  AppLocalizations? l10n,
  String id,
  String title, {
  required String subtitle,
  String? totalsLine,
}) {
  final totals =
      totalsLine ?? '= ${l10n?.billBalance ?? 'Balance'} | {{ total }}';
  const lines = '{% for line in lines %}'
      '{{ line.label }} | {{ line.amount }}\n{% endfor %}';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '# $title\n$subtitle',
        body: '$lines$totals',
      );
    case 'verbose':
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> $subtitle · {{ issued }}
---''',
        body: '$lines---\n$totals',
        footer: _legalFooter(l10n),
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}

> {{ issued }}''',
        body: '''
## ${l10n?.reportSubject ?? 'Subject'}: $title

{{ member }},

$lines---
$totals''',
        footer: '''
${l10n?.reportRegards ?? 'Kind regards'},
{{ workspace }}''',
      );
    default: // classic
      return ReportBands(
        header: '''
# $title
{{ workspace }}
> $subtitle
> {{ issued }}
---''',
        body: '$lines---\n$totals',
        footer: _legalFooter(l10n),
      );
  }
}

/// One ready-made report the owner can pick and then extend (#474).
class ReportPreset {
  const ReportPreset({
    required this.id,
    required this.name,
    required this.bands,
  });

  final String id;
  final String name;
  final ReportBands bands;
}

/// The four preset ids every document ships (#480). The FIRST is the
/// built-in default the uncustomized document renders with.
const List<String> reportPresetIds = ['classic', 'simple', 'verbose', 'formal'];

String _presetName(String id, AppLocalizations? l10n) => switch (id) {
      'simple' => l10n?.reportPresetSimple ?? 'Simple',
      'verbose' => l10n?.reportPresetVerbose ?? 'Detailed',
      'formal' => l10n?.reportPresetFormalLetter ?? 'Formal letter',
      _ => l10n?.reportPresetClassic ?? 'Classic',
    };

/// Presets for a STRING document id (#476/#480): 'invoice', 'proforma',
/// 'statement', or 'rN' for reminder level N. Proforma shares the
/// invoice presets (its `{% if proforma %}` branches flip the title).
/// Every document offers the same four: Classic · Simple · Verbose ·
/// Formal.
List<ReportPreset> presetsForDoc(String docId, AppLocalizations? l10n) {
  ReportBands bands(String id) {
    if (docId == 'invoice' || docId == 'proforma') {
      return _invoicePresetBands(l10n, id);
    }
    if (docId == 'statement') return _statementPresetBands(l10n, id);
    // #494 — the further documents share the letter shape.
    if (docId == 'agreement') {
      return _simpleDocPresetBands(
          l10n, id, l10n?.reportDocAgreement ?? 'Financial agreement',
          subtitle: '{{ member }}');
    }
    if (docId == 'payments') {
      return _simpleDocPresetBands(
          l10n, id, l10n?.reportDocPayments ?? 'Payments report',
          subtitle: '{{ member }} — {{ period }}');
    }
    if (docId == 'usage') {
      return id == 'classic'
          ? defaultUsageBands(l10n)
          : _simpleDocPresetBands(
              l10n, id, l10n?.reportDocUsage ?? 'Consumption report',
              subtitle: '{{ member }} — {{ period }}');
    }
    if (docId == 'coa' || docId == 'badges' || docId == 'space_codes') {
      // One shipped layout each. These documents are structural — a
      // chart, a grid of cards — so the presets that make sense for an
      // invoice (Classic / Formal letter) would only offer ways to
      // break them.
      return defaultBandsForDoc(docId, l10n);
    }
    if (docId == 'vat') return defaultVatBands(l10n);
    if (docId == 'workspace') {
      return id == 'classic'
          ? defaultWorkspaceBands(l10n)
          : _simpleDocPresetBands(
              l10n, id, l10n?.reportDocWorkspace ?? 'Workspace report',
              subtitle: '{{ workspace_address }}');
    }
    final level = int.tryParse(docId.substring(1)) ?? 1;
    return _reminderPresetBands(level, l10n, id);
  }

  return [
    for (final id in reportPresetIds)
      ReportPreset(id: id, name: _presetName(id, l10n), bands: bands(id)),
  ];
}

/// The default bands for a STRING document id (#476) — what Reset
/// inserts and what an uncustomized document renders with.
ReportBands defaultBandsForDoc(String docId, AppLocalizations? l10n) {
  if (docId == 'invoice' || docId == 'proforma') {
    return defaultInvoiceTemplate(l10n).invoiceBands;
  }
  if (docId == 'statement') return defaultStatementBands(l10n);
  if (docId == 'agreement') return defaultAgreementBands(l10n);
  if (docId == 'payments') return defaultPaymentsBands(l10n);
  if (docId == 'usage') return defaultUsageBands(l10n);
  if (docId == 'workspace') return defaultWorkspaceBands(l10n);
  if (docId == 'vat') return defaultVatBands(l10n);
  if (docId == 'coa') return defaultCoaBands(l10n);
  if (docId == 'badges') return defaultBadgeSheetBands(l10n);
  if (docId == 'space_codes') return defaultSpaceCodesBands(l10n);
  return defaultReminderBands(int.tryParse(docId.substring(1)) ?? 1, l10n);
}
