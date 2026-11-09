// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Italian register of issued invoices (registro delle fatture emesse,
// art. 23 DPR 633/1972) as a CSV: for each document in the order of its
// number, the date, the customer and their partita IVA or codice fiscale,
// and per rate the taxable amount, the rate and the tax; a 0 % line names
// its Natura, the same code the FatturaPA carries (`fatturapa_profile.dart`).
// (#3475 demo: a comment-only change outside the database job's import closure.)
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart' show fatturaPaNatura;
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/text/csv.dart';

/// The register's columns, in the words of the art. 23 register.
const _header = [
  'numero',
  'data',
  'cliente',
  'partita_iva_codice_fiscale',
  'imponibile',
  'aliquota',
  'imposta',
  'natura',
  'totale_documento',
  'valuta',
];

/// The register of the documents issued in `[from, to)`: one line per
/// rate of each, `;`-separated, amounts in the document's currency.
String registroFattureEmesseCsv(
  Iterable<Invoice> invoices, {
  required DateTime from,
  required DateTime to,
}) {
  final rows = <String>[_header.join(';')];
  for (final invoice in registeredInvoices(invoices, from: from, to: to)) {
    final buyer = invoice.buyerParty;
    final id = (buyer?.vatId ?? '').isNotEmpty
        ? buyer!.vatId
        : (buyer?.legalId ?? '');
    for (final t in invoice.vatTotals) {
      rows.add(
        [
          csvCell(invoice.number, quoteEmpty: true),
          isoDay(invoice.issuedAt),
          csvCell(_buyerName(invoice), quoteEmpty: true),
          csvCell(id, quoteEmpty: true),
          minorToText(t.netCents, invoice.currency),
          t.percent.toStringAsFixed(2),
          minorToText(t.vatCents, invoice.currency),
          if (t.percent == 0)
            fatturaPaNatura(t.category, buyerCountry: buyer?.country ?? '') ??
                ''
          else
            '',
          minorToText(invoice.totalCents, invoice.currency),
          invoice.currency,
        ].join(';'),
      );
    }
  }
  return '${rows.join('\r\n')}\r\n';
}

/// The documents a register lists for `[from, to)`: issued, not voided (an
/// erroneous document is replaced, and the return counts the replacement), in
/// issue order.
List<Invoice> registeredInvoices(
  Iterable<Invoice> invoices, {
  required DateTime from,
  required DateTime to,
}) => [
  for (final i in invoices)
    if (!i.isVoided && !i.issuedAt.isBefore(from) && i.issuedAt.isBefore(to)) i,
]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));

String _buyerName(Invoice invoice) {
  final buyer = invoice.buyerParty;
  if (buyer == null) return invoice.memberName;
  return buyer.company.isNotEmpty ? buyer.company : buyer.name;
}
