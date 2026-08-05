// SPDX-License-Identifier: 0BSD
//
// The SHIPPED report templates (#470/#472) — the invoice document and
// one letter per reminder level, expressed in the template language and
// localized. Nobody starts from scratch: the editor's Reset inserts
// these, and a level the owner never customized renders with them.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';

/// The built-in invoice layout as editable bands.
InvoicePdfTemplate defaultInvoiceTemplate(AppLocalizations? l10n) {
  final header = '''
# {% if proforma %}${l10n?.invoicePdfProforma ?? 'Proforma'}{% else %}${l10n?.invoicePdfTitle ?? 'Invoice'} {{ number }}{% endif %}
{{ workspace }}
> {{ workspace_address }}
> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} · ${l10n?.invoicePdfIssuedBy ?? 'Issued by'} {{ issued_by }}
{% if replaces != "" %}> ${l10n?.invoicePdfReplaces ?? 'Replaces'} {{ replaces }}{% endif %}
---''';
  final body = '''
## ${l10n?.invoicePdfBilledTo ?? 'Billed to'}
{{ member }}
> {{ period }}

## ${l10n?.invoicePdfDescription ?? 'Description'}
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}---
{% if has_vat %}{% for v in vat %}> ${l10n?.vatPdfNet ?? 'Net'} {{ v.net }} · ${l10n?.vatPdfVat ?? 'VAT'} {{ v.rate }} : {{ v.amount }}
{% endfor %}{% endif %}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''';
  return InvoicePdfTemplate(header: header, body: body, footer: '');
}

/// The shipped letter for reminder [level] (1-based): level 1 is the
/// friendly Zahlungserinnerung, higher levels read firmer and carry the
/// level number. All content is template language over the reminder
/// data — the owner edits any level independently in the report editor.
ReportBands defaultReminderBands(int level, AppLocalizations? l10n) {
  final title = level <= 1
      ? (l10n?.reminderPdfTitleFriendly ?? 'Payment reminder')
      : '${l10n?.reminderPdfTitleFirm ?? 'Reminder'} $level';
  final opening = level <= 1
      ? (l10n?.reminderPdfOpeningFriendly ??
          'this is a friendly reminder that the invoice below is still '
              'open. Perhaps it simply slipped through — no worries.')
      : (l10n?.reminderPdfOpeningFirm ??
          'despite our previous reminder, the invoice below remains '
              'unpaid. Please settle the amount without delay.');
  final header = '''
# $title
{{ workspace }}
> {{ workspace_address }}
> {{ reminder_date }}
---''';
  final body = '''
{{ member }},

$opening

## ${l10n?.invoicePdfTitle ?? 'Invoice'}
{{ number }} · ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} | {{ total }}
> ${l10n?.reminderPdfDaysOpen ?? 'Open for'} {{ days_open }} ${l10n?.reminderPdfDays ?? 'days'} · ${l10n?.reminderPdfLevelLabel ?? 'Reminder level'} {{ reminder_level }}
---
= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''';
  final footer =
      '> ${l10n?.reminderPdfClosing ?? 'If you have already paid, please disregard this letter.'}';
  return ReportBands(header: header, body: body, footer: footer);
}

/// Simulated-execution data (#474): a plausible invoice with lines and
/// VAT, plus the reminder fields — the quick preview runs on it when no
/// real invoice exists yet. Everything is sample text, no live data.
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
      'voided': false,
      'proforma': false,
      'copy': false,
      'has_vat': true,
      'lines': [
        {
          'label': l10n?.invoicePdfDescription ?? 'Subscription',
          'amount': '120,00 €',
          'negative': false,
        },
        {'label': 'Extra day', 'amount': '25,00 €', 'negative': false},
        {'label': 'Credit', 'amount': '-20,00 €', 'negative': true},
      ],
      'vat': [
        {'rate': '20 %', 'net': '120,83 €', 'amount': '24,17 €'},
      ],
      'reminder_level': 1,
      'reminder_date': '2026-08-15',
      'days_open': 15,
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

/// The out-of-the-box presets for document [doc] (0 = invoice, n =
/// reminder level n). The first preset is always the built-in default.
List<ReportPreset> reportPresets(int doc, AppLocalizations? l10n) {
  if (doc == 0) {
    final classic = defaultInvoiceTemplate(l10n);
    return [
      ReportPreset(
        id: 'classic',
        name: l10n?.reportPresetClassic ?? 'Classic',
        bands: classic.invoiceBands,
      ),
      ReportPreset(
        id: 'compact',
        name: l10n?.reportPresetCompact ?? 'Compact',
        bands: ReportBands(
          header: '# {{ workspace }} — {{ number }}\n'
              '> {{ issued }} · {{ member }} · {{ period }}\n'
              '---',
          body: '{% for line in lines %}'
              '{{ line.label }} | {{ line.amount }}\n{% endfor %}'
              '= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}',
        ),
      ),
      ReportPreset(
        id: 'formal',
        name: l10n?.reportPresetFormalLetter ?? 'Formal letter',
        bands: ReportBands(
          header: '> {{ workspace }} · {{ workspace_address }}\n\n'
              '{{ member }}\n\n'
              '> {{ issued }}',
          body: '## ${l10n?.reportSubject ?? 'Subject'}: '
              '${l10n?.invoicePdfTitle ?? 'Invoice'} {{ number }} — '
              '{{ period }}\n\n'
              '{{ member }},\n\n'
              '{% for line in lines %}'
              '{{ line.label }} | {{ line.amount }}\n{% endfor %}'
              '---\n'
              '= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}',
          footer: '${l10n?.reportRegards ?? 'Kind regards'},\n'
              '{{ issued_by }}',
        ),
      ),
      ReportPreset(
        id: 'minimal',
        name: l10n?.reportPresetMinimal ?? 'Minimal',
        bands: const ReportBands(
          header: '# {{ number }}',
          body: '{% for line in lines %}'
              '{{ line.label }} | {{ line.amount }}\n{% endfor %}'
              '---\n'
              '= {{ total }} |',
        ),
      ),
    ];
  }
  final title = doc <= 1
      ? (l10n?.reminderPdfTitleFriendly ?? 'Payment reminder')
      : '${l10n?.reminderPdfTitleFirm ?? 'Reminder'} $doc';
  final opening = doc <= 1
      ? (l10n?.reminderPdfOpeningFriendly ??
          'this is a friendly reminder that the invoice below is still '
              'open.')
      : (l10n?.reminderPdfOpeningFirm ??
          'despite our previous reminder, the invoice below remains '
              'unpaid.');
  return [
    ReportPreset(
      id: 'standard',
      name: l10n?.reportPresetStandard ?? 'Standard',
      bands: defaultReminderBands(doc, l10n),
    ),
    ReportPreset(
      id: 'formal',
      name: l10n?.reportPresetFormalLetter ?? 'Formal letter',
      bands: ReportBands(
        header: '> {{ workspace }} · {{ workspace_address }}\n\n'
            '{{ member }}\n\n'
            '> {{ reminder_date }}',
        body: '## ${l10n?.reportSubject ?? 'Subject'}: $title — '
            '${l10n?.invoicePdfTitle ?? 'Invoice'} {{ number }}\n\n'
            '{{ member }},\n\n'
            '$opening\n\n'
            '{{ number }} · {{ issued }} | {{ total }}\n'
            '---\n'
            '= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}',
        footer:
            '> ${l10n?.reminderPdfClosing ?? 'If you have already paid, please disregard this letter.'}\n\n'
            '${l10n?.reportRegards ?? 'Kind regards'},\n'
            '{{ workspace }}',
      ),
    ),
    ReportPreset(
      id: 'short',
      name: l10n?.reportPresetShort ?? 'Short notice',
      bands: ReportBands(
        header: '# $title',
        body: '{{ member }} — {{ number }} ({{ issued }})\n'
            '> {{ days_open }} ${l10n?.reminderPdfDays ?? 'days'}\n'
            '= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}',
      ),
    ),
  ];
}
