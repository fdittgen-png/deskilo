// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 (G21) -- the structured invoice (CII, UBL) tells the lot and the pieces a goods line took as item attributes
// (BG-32: BT-160 the name, BT-161 the value), one per track ID, in the order the line froze them. A line without
// tracks, a legacy line, and an invoice whose tracks name another line carry none.
import 'package:deskilo/core/jurisdiction/installed_invoice_rules.dart';
import 'package:deskilo/core/jurisdiction/installed_payment_slips.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'COWORKONTI',
  street: '4 avenue de Castelnau',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '10825191900016',
);
const _buyer = InvoiceParty(
  name: 'SASU KaloA',
  company: 'SASU KaloA',
  street: '209 rue Jean Bart',
  city: 'Labège',
  postalCode: '31670',
  country: 'FR',
);

Map<String, Object?> _facts({
  String quantity = '0.75',
  String unitCode = 'KGM',
  String basis = 'net',
  String baseQuantity = '1',
  Map<String, Object?> extra = const {},
}) => <String, Object?>{
  'version': 1,
  'line_id': 'L-1',
  'quantity': quantity,
  'unit': <String, Object?>{'code': 'kg', 'un_ece_code': unitCode, 'label': 'kg'},
  'unit_price': <String, Object?>{
    'amount': '12',
    'currency': 'EUR',
    'basis': basis,
    'base_quantity': baseQuantity,
  },
  'supply': 'goods',
  'tax_facts': <String, Object?>{},
  'amounts': <String, Object?>{
    'currency': 'EUR',
    'net_minor': '900',
    'tax_minor': '180',
    'gross_minor': '1080',
  },
  ...extra,
};

InvoiceLine _line([Map<String, Object?>? facts]) => invoiceLineFromSnapshot(<String, Object?>{
  'kind': 'service',
  'label': 'Beans',
  'quantity': 1,
  'amount_cents': 1080,
  'vat_percent': 20,
  'commercial': facts ?? _facts(),
});

Invoice _invoice(List<InvoiceLine> lines, {int total = 1080, Map<String, List<LineTrack>> tracks = const {}}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'F-2026-0001',
  issuedAt: DateTime(2026, 9, 6),
  title: 'T',
  lines: lines,
  totalCents: total,
  currency: 'EUR',
  memberName: 'SASU KaloA',
  memberAddress: '',
  workspaceName: 'COWORKONTI',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
  sellerParty: _seller,
  lineTracks: tracks,
);

EInvoiceInput _input(Invoice invoice) => EInvoiceInput(
  paymentReferenceRules: installedPaymentReferenceRules,
  nationalRules: installedNationalInvoiceRules,
  invoice: invoice,
  seller: _seller,
  buyer: _buyer,
  lineText: (l) => l.label,
  reference: ActiveTaxReference.current,
);


const _tracks = {
  'L-1': [
    LineTrack(kind: LineTrackKind.lot, code: 'EARLY', quantity: '3'),
    LineTrack(kind: LineTrackKind.lot, code: 'LATE', quantity: '1'),
    LineTrack(kind: LineTrackKind.piece, code: 'E28068940000401561D68F01'),
  ],
};

/// The (name, value) pairs of the item attributes of the first line.
List<(String, String)> _attributes(XmlDocument d, {required bool cii}) => [
  for (final e in d.findAllElements(cii ? 'ApplicableProductCharacteristic' : 'AdditionalItemProperty', namespace: '*'))
    (
      e.findElements(cii ? 'Description' : 'Name', namespace: '*').single.innerText,
      e.findElements('Value', namespace: '*').single.innerText,
    ),
];

void main() {
  const expected = [('Lot', 'EARLY'), ('Lot', 'LATE'), ('Serial number', 'E28068940000401561D68F01')];

  test('CII: each track ID is an item attribute of its line, after the name', () {
    final doc = XmlDocument.parse(buildInvoiceCii(_input(_invoice([_line()], tracks: _tracks))));
    expect(_attributes(doc, cii: true), expected);
    final product = doc.findAllElements('SpecifiedTradeProduct', namespace: '*').single;
    expect(product.childElements.map((e) => e.name.local), [
      'Name',
      'ApplicableProductCharacteristic',
      'ApplicableProductCharacteristic',
      'ApplicableProductCharacteristic',
    ]);
  });

  test('UBL: each track ID is an item attribute of its line, after the tax category', () {
    final doc = XmlDocument.parse(buildInvoiceUbl(_input(_invoice([_line()], tracks: _tracks))));
    expect(_attributes(doc, cii: false), expected);
    final item = doc.findAllElements('Item', namespace: '*').single;
    expect(item.childElements.map((e) => e.name.local).toList(), [
      'Name',
      'ClassifiedTaxCategory',
      'AdditionalItemProperty',
      'AdditionalItemProperty',
      'AdditionalItemProperty',
    ]);
  });

  test('a line without tracks, or tracks of another line, carries no attribute', () {
    for (final tracks in [const <String, List<LineTrack>>{}, const {'L-2': [LineTrack(kind: LineTrackKind.lot, code: 'X')]}]) {
      expect(_attributes(XmlDocument.parse(buildInvoiceCii(_input(_invoice([_line()], tracks: tracks)))), cii: true), isEmpty);
      expect(_attributes(XmlDocument.parse(buildInvoiceUbl(_input(_invoice([_line()], tracks: tracks)))), cii: false), isEmpty);
    }
  });

  test('a legacy line (no line id) carries none even when tracks are given', () {
    final legacy = invoiceLineFromSnapshot(<String, Object?>{'kind': 'service', 'label': 'Rent', 'quantity': 1, 'amount_cents': 1080, 'vat_percent': 20});
    final doc = XmlDocument.parse(buildInvoiceCii(_input(_invoice([legacy], tracks: _tracks))));
    expect(_attributes(doc, cii: true), isEmpty);
  });

  test('the invoice register embeds the frozen tracks of each line, and an invoice without any has none', () {
    Map<String, dynamic> row(Object? embedded) => {
      'id': 'i1', 'workspace_id': 'ws-1', 'member_id': 'm1', 'number': 'F-1', 'issued_at': '2026-09-01T10:00:00Z',
      'period': '2026-09', 'title': 'T', 'lines': const <dynamic>[], 'total_cents': 0, 'currency': 'EUR',
      'member_name': 'M', 'member_address': '', 'workspace_name': 'W', 'workspace_address': '', 'issuer_name': 'O',
      'signature': 'abc', 'invoice_line_tracks': embedded,
    };
    final invoice = Invoice.fromRow(row([
      {
        'line_id': 'L-1',
        'tracks': [
          {'kind': 'lot', 'code': 'EARLY', 'quantity': '3'},
          {'kind': 'piece', 'code': 'SN-1'},
        ],
      },
      {'line_id': '', 'tracks': <dynamic>[]},
    ]));
    expect(invoice.lineTracks.keys, ['L-1']);
    expect(invoice.lineTracks['L-1']!.map((t) => t.text), ['EARLY ×3', 'SN-1']);
    expect(Invoice.fromRow(row(null)).lineTracks, isEmpty);
    expect(Invoice.fromRow(row(<dynamic>[])).lineTracks, isEmpty);
    expect(Invoice.fromRow(row([{'line_id': 'L-1', 'tracks': <dynamic>[]}])), isNot(equals(invoice)),
        reason: 'the tracks are part of what an invoice is');
  });

  test('the snapshot reads the kinds it knows and leaves out the rest', () {
    final read = lineTracksByLineId([
      {
        'line_id': 'L-1',
        'tracks': [
          {'kind': 'lot', 'code': 'EARLY', 'quantity': '3', 'expires_on': '2026-12-01'},
          {'kind': 'piece', 'code': 'SN-1'},
          {'kind': 'pallet', 'code': 'P-1'},
          {'kind': 'lot', 'code': ''},
          'not a map',
        ],
      },
    ])['L-1']!;
    expect(read.map((t) => t.text), ['EARLY ×3', 'SN-1']);
    expect(read.first.expiresOn, '2026-12-01');
    expect(lineTracksByLineId(null), isEmpty);
    expect(lineTracksByLineId([{'line_id': 'L-1', 'tracks': {'kind': 'lot'}}])['L-1'], isEmpty);
  });
}
