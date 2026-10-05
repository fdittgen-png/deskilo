// SPDX-License-Identifier: AGPL-3.0-or-later
// Professional variants keep the kind's full data sections. Presentation
// never manufactures tax, settlement or contractual facts.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';
import 'report_kind_labels.dart';

ReportBands professionalReportBands({
  required ReportKind kind,
  required ReportBands content,
  required AppLocalizations? l10n,
}) {
  // Invoices already have their own identity/date/tax sections; preserve
  // them rather than replacing them with a generic management header.
  if (kind.slot is ReportRootSlot ||
      kind.slot is ReportProformaSlot ||
      kind.isReminder || kind.id == 'vat_declaration') {
    return content;
  }
  final title = reportKindLabel(l10n, kind);
  return ReportBands(
    header:
        '''
## {{ workspace }}
> {{ workspace_address }}
---
# $title
{% if member != "" %}{{ member }}{% endif %}
{% if client_address != "" %}> {{ client_address }}{% endif %}
{% if period != "" %}> {{ period }}{% endif %}
{% if issued != "" %}> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }}{% endif %}
{% if vat_period != "" %}> {{ vat_period }}{% endif %}
{% if vat_basis_note != "" %}> {{ vat_basis_note }}{% endif %}
{% if status_from != "" %}> {{ status_from }} → {{ status_to }}{% endif %}
{% if coa_chart_name != "" %}> {{ coa_chart_name }} ({{ coa_chart_code }}) · {{ country }}{% endif %}''',
    body: content.body,
    // Operational summaries and badge sheets must not request payment
    // or claim statutory late-payment penalties merely by sharing a style.
    footer:
        kind.id == 'agreement' ||
            kind.id == 'coa' ||
            kind.id == 'badges' ||
            kind.id == 'space_codes'
        ? content.footer
        : '> {{ workspace }}\n> {{ workspace_address }}',
  );
}
