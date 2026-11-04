// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase order's built-in bands: the space's letterhead, the
// supplier, the order's number and dates, its lines and totals. With the
// letter standard on, the positioned letter layout wins
// (report_letter_layouts.dart).
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';

ReportBands purchaseOrderBands(AppLocalizations l10n) {
  final title = l10n.reportDocPurchaseOrder;
  return ReportBands(
    header:
        '# {{ workspace }}\n> {{ workspace_address }}\n---\n'
        '{{ client_name }}\n> {{ client_address }}\n---\n'
        '# $title {{ number }}\n> ${l10n.invoicePdfIssuedOn} {{ issued }}'
        '{% if expected_on != "" %} · ${l10n.reportExpectedDelivery} '
        '{{ expected_on }}{% endif %}',
    continuation: '{{ workspace }} — $title {{ number }}\n---',
    body:
        '{% for line in lines %}{{ line.label }} · {{ line.qty }} × '
        '{{ line.unit_price }} | {{ line.amount }}\n{% endfor %}'
        '---\n${l10n.vatPdfNet} | {{ net_total }}\n'
        '{% if has_vat %}${l10n.vatPdfVat} | {{ vat_total }}\n{% endif %}'
        '**${l10n.reportColTotal}** | **{{ total }}**\n'
        '{% if note != "" %}\n{{ note }}\n{% endif %}',
    footer: '> {{ workspace }} · {{ issued_by }}',
  );
}
