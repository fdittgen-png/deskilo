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
