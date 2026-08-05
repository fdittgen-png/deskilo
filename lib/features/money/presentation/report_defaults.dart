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
> {{ payment_terms }} — {{ escompte }}
> {{ late_penalty }} {{ recovery_indemnity }}
{% if insurance != "" %}> {{ insurance }}{% endif %}
{% if special_mentions != "" %}> {{ special_mentions }}{% endif %}''';

/// The per-rate VAT recap + totals, or the exemption reason when no VAT
/// is charged — one of the two must appear on a compliant document.
String _vatRecap(AppLocalizations? l10n) =>
    '{% if has_vat %}{% for v in vat %}> ${l10n?.vatPdfNet ?? 'Net'} {{ v.net }} · ${l10n?.vatPdfVat ?? 'VAT'} {{ v.rate }} : {{ v.amount }}\n'
    '{% endfor %}> ${l10n?.vatPdfNet ?? 'Net'} {{ net_total }} · ${l10n?.vatPdfVat ?? 'VAT'} {{ vat_total }}\n'
    '{% endif %}{% if exemption_reason != "" %}> {{ exemption_reason }}\n{% endif %}';

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
      '{% if proforma %}${l10n?.invoicePdfProforma ?? 'Proforma'}{% else %}${l10n?.invoicePdfTitle ?? 'Invoice'} {{ number }}{% endif %}';
  final billedTo = '''
## ${l10n?.invoicePdfBilledTo ?? 'Billed to'}
{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}
> {{ period }}''';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }}
---''',
        body: '''
$billedTo

{% for line in lines %}{{ line.label }}{% if line.vat_rate != "" %} · ${l10n?.vatPdfVat ?? 'VAT'} {{ line.vat_rate }}{% endif %} | {{ line.amount }}
{% endfor %}---
${_vatRecap(l10n)}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: _legalFooter(l10n),
      );
    case 'verbose':
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} · ${l10n?.invoicePdfIssuedBy ?? 'Issued by'} {{ issued_by }}
{% if replaces != "" %}> ${l10n?.invoicePdfReplaces ?? 'Replaces'} {{ replaces }}{% endif %}
---''',
        body: '''
$billedTo

## ${l10n?.invoicePdfDescription ?? 'Description'}
{% for line in lines %}{{ line.label }}
> {{ line.qty }} × {{ line.unit_price }}{% if line.vat_rate != "" %} · ${l10n?.vatPdfNet ?? 'Net'} {{ line.net }} · ${l10n?.vatPdfVat ?? 'VAT'} {{ line.vat_rate }}{% endif %} | {{ line.amount }}
{% endfor %}---
## ${l10n?.vatPdfVat ?? 'VAT'}
${_vatRecap(l10n)}
## ${l10n?.invoiceBalance ?? 'Balance due'}
${l10n?.invoicePdfCharges ?? 'Charges'} | {{ charges }}
{% if payments != "" %}${l10n?.invoicePdfPayments ?? 'Payments'} | {{ payments }}
{% endif %}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: _legalFooter(l10n),
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}

> {{ issued }}''',
        body: '''
## ${l10n?.reportSubject ?? 'Subject'}: $title — {{ period }}

{{ member }},

{% for line in lines %}{{ line.label }}{% if line.vat_rate != "" %} · ${l10n?.vatPdfVat ?? 'VAT'} {{ line.vat_rate }}{% endif %} | {{ line.amount }}
{% endfor %}---
${_vatRecap(l10n)}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
        footer: '''
${_legalFooter(l10n)}

${l10n?.reportRegards ?? 'Kind regards'},
{{ issued_by }}''',
      );
    default: // classic — the built-in default.
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} · ${l10n?.invoicePdfIssuedBy ?? 'Issued by'} {{ issued_by }}
{% if replaces != "" %}> ${l10n?.invoicePdfReplaces ?? 'Replaces'} {{ replaces }}{% endif %}
---''',
        body: '''
$billedTo

## ${l10n?.invoicePdfDescription ?? 'Description'}
{% for line in lines %}{{ line.label }}{% if line.qty != "1" %} — {{ line.qty }} × {{ line.unit_price }}{% endif %}{% if line.vat_rate != "" %} · ${l10n?.vatPdfVat ?? 'VAT'} {{ line.vat_rate }}{% endif %} | {{ line.amount }}
{% endfor %}---
${_vatRecap(l10n)}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''',
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
  const clauses = '> {{ late_penalty }} {{ recovery_indemnity }}';
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

/// Simulated-execution data (#474): a plausible invoice with lines and
/// VAT, plus the reminder and legal-mention fields (#480) — the quick
/// preview runs on it when no real invoice exists yet. Everything is
/// sample text, no live data.
Map<String, Object?> sampleReportData(AppLocalizations? l10n) => {
      'workspace': 'Coworking Demo',
      'workspace_address': '1 Example Street, 12345 Demo City',
      'member': 'Alex Sample',
      'number': 'INV-2026-0042',
      'period': 'July 2026',
      'issued': '2026-07-31',
      'issued_by': 'Demo Owner',
      'replaces': '',
      'total': '145,00 €',
      'charges': '165,00 €',
      'payments': '-20,00 €',
      'net_total': '120,83 €',
      'vat_total': '24,17 €',
      'voided': false,
      'proforma': false,
      'copy': false,
      'has_vat': true,
      'lines': [
        {
          'label': l10n?.invoicePdfDescription ?? 'Subscription',
          'amount': '120,00 €',
          'negative': false,
          'qty': '1',
          'unit_price': '120,00 €',
          'vat_rate': '20 %',
          'net': '100,00 €',
        },
        {
          'label': 'Extra day',
          'amount': '25,00 €',
          'negative': false,
          'qty': '1',
          'unit_price': '25,00 €',
          'vat_rate': '20 %',
          'net': '20,83 €',
        },
        {
          'label': 'Credit',
          'amount': '-20,00 €',
          'negative': true,
          'qty': '1',
          'unit_price': '-20,00 €',
          'vat_rate': '',
          'net': '-20,00 €',
        },
      ],
      'vat': [
        {'rate': '20 %', 'net': '120,83 €', 'amount': '24,17 €'},
      ],
      'reminder_level': 1,
      'reminder_date': '2026-08-15',
      'days_open': 15,
      // #480 — the legal mention variables, filled like a French SARL.
      'seller_legal_form': 'SARL au capital de 7 500 €',
      'seller_registration': 'RCS Demo City 123 456 789',
      'seller_vat_id': 'FR 39 680 357 910',
      'seller_legal_id': '680 357 910',
      'exemption_reason': '',
      'client_address': '3 Avenue de la Liberté, 35000 Rennes',
      'payment_terms':
          l10n?.invoiceLegalPaymentTermsDefault ?? 'Payment on receipt.',
      'late_penalty': l10n?.invoiceLegalLatePenaltyDefault ??
          'Late-payment penalty: three times the statutory interest rate.',
      'recovery_indemnity': l10n?.invoiceLegalRecoveryDefault ??
          'Fixed recovery indemnity for collection costs: €40.',
      'escompte': l10n?.invoiceLegalEscompteDefault ??
          'No discount for early payment.',
      'insurance': '',
      'special_mentions': '',
    };

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
  return defaultReminderBands(int.tryParse(docId.substring(1)) ?? 1, l10n);
}
