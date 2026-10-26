// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Italian register of issued invoices (registro delle fatture emesse,
// art. 23 DPR 633/1972) as a CSV: for each document in the order of its
// number, the date, the customer and their partita IVA or codice fiscale,
// and per rate the taxable amount, the rate and the tax; a 0 % line names
// its Natura, the same code the FatturaPA carries (`invoice_fatturapa.dart`).
import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'invoice.dart';
import 'invoice_fatturapa.dart';
import 'vat_register_es.dart' show buyerNameOf, registerDocuments;

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
  for (final invoice in registerDocuments(invoices, from: from, to: to)) {
    final buyer = invoice.buyerParty;
    final id = (buyer?.vatId ?? '').isNotEmpty
        ? buyer!.vatId
        : (buyer?.legalId ?? '');
    for (final t in invoice.vatTotals) {
      rows.add(
        [
          csvCell(invoice.number, quoteEmpty: true),
          isoDay(invoice.issuedAt),
          csvCell(buyerNameOf(invoice), quoteEmpty: true),
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
