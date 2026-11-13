// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3616 — the documents behind each box of a VAT return (the decision on
// #3616): an unfiled return whose documents still say what it says shows no
// difference; a filed return with an invoice issued after it shows both
// figures and the difference. A box fed by purchases is not compared.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/vat_return_documents.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    show VatTaxPointAmount, vatDeclarationLinesOf;
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026);
final _end = DateTime(2026, 3, 31);

VatTaxPointAmount _point(String id, int net, {double percent = 19}) =>
    VatTaxPointAmount(
      invoiceId: id,
      on: DateTime(2026, 2, 10),
      percent: percent,
      grossCents: net + (net * percent / 100).round(),
      netCents: net,
      vatCents: (net * percent / 100).round(),
    );

VatDeclaration _return(
  List<VatDeclarationLine> lines, {
  String status = 'prepared',
}) => VatDeclaration(
  id: 'd1',
  workspaceId: 'ws-1',
  periodStart: _start,
  periodEnd: _end,
  status: status,
  lines: lines,
  totalNetCents: lines.fold(0, (a, l) => a + l.netCents),
  totalVatCents: lines.fold(0, (a, l) => a + l.vatCents),
  currency: 'EUR',
  invoiceCount: 2,
  createdAt: _end,
);

List<VatBoxDocuments> _boxes(VatDeclaration d, List<VatTaxPointAmount> today) =>
    vatBoxDocuments(
      d,
      today,
      country: 'DE',
      reference: ActiveTaxReference.current,
    );

void main() {
  final filed = [_point('a', 100000), _point('b', 24000)];

  test('an unfiled return whose documents still say it: no difference', () {
    final d = _return(vatDeclarationLinesOf(filed, _start, _end));
    final boxes = _boxes(d, filed);
    final compared = boxes.where((b) => b.difference != null).toList();
    expect(compared, isNotEmpty);
    for (final b in compared) {
      expect(b.difference, 0, reason: b.box.code);
      expect(b.documents.map((p) => p.invoiceId).toSet(), {
        'a',
        'b',
      }, reason: 'the invoices at the box\'s rate');
    }
  });

  test('a filed return and an invoice issued after it: both figures and the '
      'difference', () {
    final d = _return(
      vatDeclarationLinesOf(filed, _start, _end),
      status: 'filed',
    );
    final later = [...filed, _point('c', 6000)];
    final boxes = _boxes(d, later);
    final differing = [
      for (final b in boxes)
        if ((b.difference ?? 0) != 0) b,
    ];
    expect(differing, isNotEmpty, reason: 'the later invoice is not hidden');
    for (final b in differing) {
      expect(b.documented! - b.declared, b.difference);
      expect(b.difference, greaterThan(0));
      expect(b.documents.map((p) => p.invoiceId), contains('c'));
    }
  });

  test('a box fed by purchases is not compared', () {
    final d = _return([
      ...vatDeclarationLinesOf(filed, _start, _end),
      const VatDeclarationLine(
        percent: 19,
        grossCents: 11900,
        netCents: 10000,
        vatCents: 1900,
        invoiceCount: 1,
        direction: 'input',
      ),
    ]);
    final boxes = _boxes(d, filed);
    final inputOnly = boxes.where(
      (b) => b.today == null && b.box.vatCents != 0,
    );
    expect(inputOnly, isNotEmpty, reason: 'the input VAT box says no sum');
  });
}
