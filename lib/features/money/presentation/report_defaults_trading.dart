// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307, #4166 — the built-in bands of the documents a business sends in
// trading: the purchase order to a supplier and the quote to a customer. The
// purchase order's: the space's letterhead, the
// supplier, the order's number and dates, its lines and totals. With the
// letter standard on, the positioned letter layout wins
// (report_letter_layouts.dart).
import 'package:meta/meta.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import 'report_defaults_stock_expiry.dart';

@visibleForTesting
ReportBands purchaseOrderBands(AppLocalizations l10n) {
  final title = l10n.reportDocPurchaseOrder;
  final issuedLine = l10n.invoicePdfIssuedOnDate('{{ issued }}');
  return ReportBands(
    header:
        '# {{ workspace }}\n> {{ workspace_address }}\n---\n'
        '{{ client_name }}\n> {{ client_address }}\n---\n'
        '# $title {{ number }}\n> $issuedLine'
        '{% if expected_on != "" %} · '
        "${l10n.reportExpectedDeliveryDate('{{ expected_on }}')}{% endif %}",
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

/// #4166 — a quote's bands: the letterhead, the customer, the reference
/// (never an invoice number), its date and validity, its lines and totals.
ReportBands _quoteBands(AppLocalizations l10n) {
  final title = l10n.reportDocQuote;
  final issuedLine = l10n.invoicePdfIssuedOnDate('{{ issued }}');
  return ReportBands(
    header:
        '# {{ workspace }}\n> {{ workspace_address }}\n---\n'
        '{{ client_name }}\n> {{ client_address }}\n---\n'
        '# $title {{ number }}\n> $issuedLine · '
        "${l10n.quoteValidUntil('{{ valid_until }}')}",
    continuation: '{{ workspace }} — $title {{ number }}\n---',
    body:
        '{% for line in lines %}{{ line.label }} · {{ line.qty }} × '
        '{{ line.unit_price }} | {{ line.amount }}\n{% endfor %}'
        '---\n${l10n.vatPdfNet} | {{ net_total }}\n'
        '{% if has_vat %}{% for v in vat %}${l10n.vatPdfVat} {{ v.rate }} | '
        '{{ v.amount }}\n{% endfor %}{% endif %}'
        '**${l10n.reportColTotal}** | **{{ total }}**\n'
        '{% if note != "" %}\n{{ note }}\n{% endif %}',
    footer: '> {{ workspace }} · {{ issued_by }}',
  );
}

/// The bands of the trading document [docId].
ReportBands tradingDocumentBands(String docId, AppLocalizations l10n) => switch (docId) {
  'quote' => _quoteBands(l10n),
  'stock_expiry' => stockExpiryBands(l10n),
  _ => purchaseOrderBands(l10n),
};
