// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish annual statement of operations with third parties (modelo
// 347) as a list from the register of issued invoices: every Spanish
// customer, by NIF, whose operations of the year (VAT included) pass the
// line of the `threshold` row `modelo347`, with the four quarters apart and
// the province of their postal code. Clave B: supplies and services the
// space made. What the modelo 349 lists (intra-EU), exports and operations
// not subject here are left out, as the order says.
import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'invoice.dart';
import 'vat_register_es.dart';

/// One customer of the list.
typedef Modelo347Line = ({
  String nif,
  String name,
  String province,
  List<int> quarters,
});

/// Exempt causes the 347 leaves out: exports (E2) and intra-EU supplies of
/// goods (E5), which other returns carry.
const _elsewhere = {'E2', 'E5'};

/// The customers of [year] above the line, by NIF; empty where [reference]
/// (the workspace's tax reference) has no `modelo347` row in [currency] for
/// that year.
List<Modelo347Line> modelo347Lines(
  Iterable<Invoice> invoices, {
  required int year,
  required String currency,
  required TaxReferenceSet reference,
}) {
  final row = reference
      .resolved('$year-12-31')
      .lookup(TaxDomain.threshold, 'ES', 'modelo347');
  final line = row?.value;
  if (line is! ThresholdValue || line.currency != currency) return const [];
  final byNif = <String, Modelo347Line>{};
  for (final invoice in registerDocuments(
    invoices,
    from: DateTime(year),
    to: DateTime(year + 1),
  )) {
    final buyer = esBuyerIdOf(invoice);
    if (buyer.id.isEmpty || buyer.type.isNotEmpty) continue;
    final country = invoice.buyerParty?.country ?? '';
    final cents = invoice.vatTotals
        .where((t) {
          final op = esOperationOf(t.category, country);
          return op.qualification != 'N2' && !_elsewhere.contains(op.exemption);
        })
        .fold(0, (sum, t) => sum + t.grossCents);
    if (cents == 0) continue;
    final kept = byNif[buyer.id];
    final quarters = [...(kept?.quarters ?? List.filled(4, 0))];
    quarters[(invoice.issuedAt.month - 1) ~/ 3] += cents;
    final postal = invoice.buyerParty?.postalCode.trim() ?? '';
    byNif[buyer.id] = (
      nif: buyer.id,
      name: kept?.name ?? buyerNameOf(invoice),
      province:
          kept?.province ??
          (RegExp(r'^\d{5}$').hasMatch(postal) ? postal.substring(0, 2) : ''),
      quarters: quarters,
    );
  }
  return [
    for (final l in byNif.values)
      if (l.quarters.fold(0, (a, b) => a + b) > line.cents) l,
  ]..sort((a, b) => a.nif.compareTo(b.nif));
}

/// The list as a CSV: NIF, name, province, clave, the year and its quarters.
String modelo347Csv(List<Modelo347Line> lines, {required String currency}) {
  final rows = [
    'nif;nombre;provincia;clave;importe_anual;importe_1T;importe_2T;importe_3T;importe_4T',
    for (final l in lines)
      [
        csvCell(l.nif, quoteEmpty: true),
        csvCell(l.name, quoteEmpty: true),
        csvCell(l.province, quoteEmpty: true),
        'B',
        minorToText(l.quarters.fold(0, (a, b) => a + b), currency),
        for (final q in l.quarters) minorToText(q, currency),
      ].join(';'),
  ];
  return '${rows.join('\r\n')}\r\n';
}
