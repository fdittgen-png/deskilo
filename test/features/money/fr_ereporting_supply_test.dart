// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 checkpoint 2 -- the transaction category is the supply and the rate
// together: a goods line and a service line at the same rate stay two lines
// of the report; a mixed document with a payment is refused until the split
// of the payment is authoritative; nothing is guessed from a rate alone.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/fr_ereporting.dart';
import 'package:deskilo/features/money/domain/fr_ereporting_capacity.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceLine _line(
  String supply,
  int net,
  int tax, {
  double vat = 20,
  int? gross,
}) => InvoiceLine(
  label: supply,
  amountCents: gross ?? net + tax,
  vatPercent: vat,
  commercial: commercialLineFromSnapshot({
    'version': 1,
    'line_id': 'l-$supply-$net',
    'quantity': '1',
    'unit': {'code': 'piece', 'un_ece_code': 'C62', 'label': 'pc'},
    'unit_price': {
      'amount': '${net / 100}',
      'currency': 'EUR',
      'basis': 'net',
      'base_quantity': '1',
    },
    'supply': supply,
    'tax_facts': <String, Object?>{},
    'amounts': {
      'currency': 'EUR',
      'net_minor': '$net',
      'tax_minor': '$tax',
      'gross_minor': '${gross ?? net + tax}',
    },
  }),
);

final _person = {
  'schema': 1,
  'buyer_capacity': 'consumer',
  'capacity_source': 'member',
  'buyer_country': 'FR',
};
final _businessBe = {
  'schema': 1,
  'buyer_capacity': 'business',
  'capacity_source': 'member',
  'buyer_country': 'BE',
};

Invoice _invoice(
  String id,
  List<InvoiceLine> lines, {
  Map<String, Object?>? frozen,
  InvoiceParty buyer = const InvoiceParty(name: 'Ada', country: 'FR'),
}) => Invoice(
  id: id,
  workspaceId: 'ws',
  memberId: 'm',
  number: 'F-$id',
  issuedAt: WorkspaceTime.at(2026, 9, 10, 12).toUtc(),
  title: id,
  lines: lines,
  totalCents: lines.fold(0, (s, l) => s + l.amountCents),
  currency: 'EUR',
  memberName: 'Ada',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  buyerParty: buyer,
  legalSnapshot: frozen ?? _person,
);

FrEReport _run(List<Invoice> docs, {Map<String, InvoiceMatch> paid = const {}}) =>
    frEReport(
      docs,
      start: DateTime(2026, 9),
      end: DateTime(2026, 9, 30),
      matches: paid,
      basis: EReportingBasis(homeCountry: eReportingCountry),
      dayOf: WorkspaceTime.dateOf,
      reference: ActiveTaxReference.current,
    );

InvoiceMatch _paid(String id, int cents) => InvoiceMatch(
  invoiceId: id,
  paidCents: cents,
  resolution: 'paid',
  matchedAt: WorkspaceTime.at(2026, 9, 12, 12).toUtc(),
);

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  test('goods and a service at the same rate stay two categories, from the frozen amounts', () {
    final r = _run([
      _invoice('1', [_line('goods', 10000, 2000), _line('general', 5000, 1000)]),
    ]);
    expect(
      r.b2cTransactions.map((t) => (t.category, t.percent, t.netCents, t.vatCents)).toSet(),
      {('TLB1', 20.0, 10000, 2000), ('TPS1', 20.0, 5000, 1000)},
    );
    expect(r.isComplete, isTrue);
  });

  test('the frozen tax is consumed as written, not recomputed from the rate', () {
    // 100.01 net at 20 % would recompute to 20.00 / 20.01; the document froze 20.02.
    final r = _run([
      _invoice('2', [_line('goods', 10001, 2002)]),
    ]);
    expect(r.b2cTransactions.single.vatCents, 2002);
  });

  test('a mixed document with a payment in the period is refused: no proportional split', () {
    final doc = _invoice('3', [_line('goods', 10000, 2000), _line('property', 5000, 1000)]);
    final r = _run([doc], paid: {'3': _paid('3', 6000)});
    expect(r.unresolved.single.reasons, [FrUnresolvedReason.missingReceiptAllocation]);
    expect(r.isComplete, isFalse);
    expect(r.toXml, throwsStateError);
    // without the payment the same document reports its sales
    expect(_run([doc]).isComplete, isTrue);
  });

  test('a pure goods sale owes no payment data', () {
    final doc = _invoice('4', [_line('goods', 10000, 2000)]);
    final r = _run([doc], paid: {'4': _paid('4', 12000)});
    expect(r.isComplete, isTrue);
    expect(r.b2cPayments, isEmpty);
    expect(r.b2cTransactions.single.category, 'TLB1');
  });

  test('a goods line at a zero rate gets no category from the rate alone', () {
    final r = _run([_invoice('5', [_line('goods', 10000, 0, vat: 0)])]);
    expect(r.unresolved.single.reasons, [FrUnresolvedReason.goodsZeroRateUnsupported]);
  });

  test('goods delivered to a business abroad are refused', () {
    final r = _run([
      _invoice(
        '6',
        [_line('goods', 10000, 2000)],
        frozen: _businessBe,
        buyer: const InvoiceParty(name: 'B', country: 'BE', vatId: 'BE0123456789'),
      ),
    ]);
    expect(r.unresolved.single.reasons, [FrUnresolvedReason.goodsAbroadUnsupported]);
  });

  test('a commercial line this reader cannot interpret is refused, not dropped', () {
    final unreadable = InvoiceLine(
      label: 'x',
      amountCents: 1200,
      vatPercent: 20,
      commercial: commercialLineFromSnapshot({'version': 9, 'line_id': 'z'}),
    );
    final r = _run([_invoice('7', [unreadable])]);
    expect(r.unresolved.single.reasons, [FrUnresolvedReason.unsupportedCommercialLine]);
  });

  test('a legacy service document still reads as before (TPS1 from the ledger)', () {
    final r = _run([
      _invoice('8', const [InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20)]),
    ]);
    expect(r.b2cTransactions.single.category, 'TPS1');
    expect((r.b2cTransactions.single.netCents, r.b2cTransactions.single.vatCents), (10000, 2000));
  });

  test('a pure service commercial document with a payment follows the rate when its frozen tax agrees', () {
    final doc = _invoice('9', [_line('property', 10000, 2000)]);
    final r = _run([doc], paid: {'9': _paid('9', 12000)});
    expect(r.isComplete, isTrue);
    expect(r.b2cPayments.single.grossCents, 12000);
  });
}
