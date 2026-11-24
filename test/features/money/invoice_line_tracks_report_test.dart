// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 (G21) -- the track IDs frozen on a goods line reach the printed invoice: the line row carries them
// (`track_ids`, `tracks`) only when it has some, and the default design prints them after the label; a line without
// tracks is exactly what it was.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _words = ReportStrings(
  participation: (pct) => 'P $pct',
  participationMonth: (month, pct) => 'P $month $pct',
  subscription: (pct) => 'S $pct',
  subscriptionMonth: (month, pct) => 'S $month $pct',
);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Espace',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
);

const _seller = InvoiceParty(
  name: 'Espace',
  street: '4 rue X',
  city: 'Paris',
  postalCode: '75001',
  country: 'FR',
  legalId: '10825191900016',
);

Map<String, Object?> _commercial(String quantity) => <String, Object?>{
  'kind': 'service',
  'label': 'Consulting',
  'quantity': 1,
  'amount_cents': 14520,
  'commercial': {
    'version': 1,
    'line_id': 'L-1',
    'quantity': quantity,
    'unit': {'code': 'hour', 'un_ece_code': 'HUR', 'label': 'h'},
    'unit_price': {
      'amount': '80',
      'currency': 'EUR',
      'basis': 'net',
      'base_quantity': '1',
    },
    'supply': 'general',
    'tax_facts': <String, Object?>{},
    'amounts': {
      'currency': 'EUR',
      'net_minor': '12000',
      'tax_minor': '2520',
      'gross_minor': '14520',
    },
  },
};

Invoice _invoice(List<InvoiceLine> lines, {Map<String, List<LineTrack>> tracks = const {}}) => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'F-2026-0001',
  issuedAt: DateTime(2026, 9),
  title: 'T',
  lines: lines,
  totalCents: 14520,
  currency: 'EUR',
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'Espace',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
  sellerParty: _seller,
  lineTracks: tracks,
);

Map<String, Object?> _data(Invoice invoice) => invoiceReportData(
  _words,
  invoice,
  proforma: false,
  copy: false,
  workspace: _workspace,
  reference: ActiveTaxReference.current,
);

const _tracks = {
  'L-1': [
    LineTrack(kind: LineTrackKind.lot, code: 'EARLY', quantity: '3'),
    LineTrack(kind: LineTrackKind.lot, code: 'LATE', quantity: '1'),
    LineTrack(kind: LineTrackKind.piece, code: 'SN-1'),
  ],
};

/// The first cell of each row of the default design rendered over [data].
List<String> _labelCells(Map<String, Object?> data) {
  final report = renderReportBands(bands: defaultBandsForDoc('invoice', AppLocalizationsEn()), data: data)!;
  return [for (final row in report.body.whereType<ReportTableRow>()) row.cells.first];
}

void main() {
  test('a traced goods line carries its track IDs as one text and as a list', () {
    final line = (_data(_invoice([invoiceLineFromSnapshot(_commercial('1'))], tracks: _tracks))['lines']! as List).single
        as Map<String, Object?>;
    expect(line['track_ids'], 'EARLY ×3, LATE ×1, SN-1');
    expect(line['tracks'], [
      {'kind': 'lot', 'code': 'EARLY', 'quantity': '3', 'expires_on': '', 'text': 'EARLY ×3'},
      {'kind': 'lot', 'code': 'LATE', 'quantity': '1', 'expires_on': '', 'text': 'LATE ×1'},
      {'kind': 'piece', 'code': 'SN-1', 'quantity': '', 'expires_on': '', 'text': 'SN-1'},
    ]);
  });

  test('a line without tracks carries neither key, whatever the invoice holds for other lines', () {
    for (final tracks in [const <String, List<LineTrack>>{}, const {'L-9': [LineTrack(kind: LineTrackKind.lot, code: 'X')]}]) {
      final line = (_data(_invoice([invoiceLineFromSnapshot(_commercial('1'))], tracks: tracks))['lines']! as List).single
          as Map<String, Object?>;
      expect(line.containsKey('track_ids'), isFalse);
      expect(line.containsKey('tracks'), isFalse);
    }
  });

  test('the default design prints the track IDs after the label of a traced line, and nothing after another', () {
    final traced = _labelCells(_data(_invoice([invoiceLineFromSnapshot(_commercial('1'))], tracks: _tracks)));
    expect(traced, contains('Consulting (EARLY ×3, LATE ×1, SN-1)'));
    final plain = _labelCells(_data(_invoice([invoiceLineFromSnapshot(_commercial('1'))])));
    expect(plain, contains('Consulting'));
    expect(plain.where((c) => c.contains('(')), isEmpty);
  });

  test('the positioned letter layout reads the tracks with the same guard, and renders with and without them', () {
    final xml = defaultLetterLayoutXml('invoice', const LetterStrings());
    expect(xml, contains('{% if line.track_ids != nil and line.track_ids != "" %} ({{ line.track_ids }}){% endif %}'));
    final line = [invoiceLineFromSnapshot(_commercial('1'))];
    expect(() => renderLayoutDocument(xml, _data(_invoice(line, tracks: _tracks))), returnsNormally);
    expect(() => renderLayoutDocument(xml, _data(_invoice(line))), returnsNormally);
  });
}
