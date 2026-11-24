// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 -- the invoice sheet states the track IDs frozen on a goods line under it: its lots with the quantity taken from
// each, then its pieces by tag code; a line that took nothing traced shows none. On a phone and on a desk.
import 'package:deskilo/features/money/presentation/widgets/invoice_detail_sheet.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_line_measure.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

const _goods = {
  'kind': 'goods',
  'label': 'Honey',
  'quantity': 1,
  'amount_cents': 4800,
  'vat_percent': 20,
  'commercial': {
    'version': 1,
    'line_id': 'L-1',
    'quantity': '4',
    'unit': {'code': 'piece', 'un_ece_code': 'C62', 'label': 'pc'},
    'unit_price': {'amount': '10', 'currency': 'EUR', 'basis': 'net', 'base_quantity': '1'},
    'supply': 'goods',
    'tax_facts': <String, Object?>{},
    'amounts': {'currency': 'EUR', 'net_minor': '4000', 'tax_minor': '800', 'gross_minor': '4800'},
  },
};

const _tracks = {
  'L-1': [
    LineTrack(kind: LineTrackKind.lot, code: 'EARLY', quantity: '3'),
    LineTrack(kind: LineTrackKind.lot, code: 'LATE', quantity: '1'),
    LineTrack(kind: LineTrackKind.piece, code: 'SN-1'),
  ],
};

Invoice _invoice(Map<String, List<LineTrack>> tracks) => Invoice(
  id: 'inv-goods',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'KC-2026-0005',
  issuedAt: DateTime(2026, 9, 10),
  title: 'Goods',
  lines: [invoiceLineFromSnapshot(_goods)],
  totalCents: 4800,
  currency: 'EUR',
  memberName: 'Domaine des Aires',
  memberAddress: '',
  workspaceName: 'Kessler Conseil',
  workspaceAddress: '',
  issuerName: 'Bruno',
  signature: 'f' * 64,
  lineTracks: tracks,
);

Future<void> _openSheet(WidgetTester tester, Size size, Invoice invoice) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(),
        money: FakeMoneyRepository(),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => FilledButton(
              key: const ValueKey('open'),
              onPressed: () => showInvoiceDetailSheet(
                context,
                ref: ref,
                view: InvoiceDetailView(invoice: invoice, match: null, canIssue: true, isEu: true),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

void main() {
  test('the words of the tracks: lots with their quantities, then pieces, nothing when none', () {
    final l10n = AppLocalizationsEn();
    expect(invoiceLineTracksText(l10n, _tracks['L-1']!), 'Lot: EARLY ×3, LATE ×1 · Pieces: SN-1');
    expect(invoiceLineTracksText(l10n, const [LineTrack(kind: LineTrackKind.piece, code: 'SN-9')]), 'Pieces: SN-9');
    expect(invoiceLineTracksText(l10n, const []), isNull);
  });

  for (final (name, size) in [('phone', const Size(390, 900)), ('desk', const Size(1440, 900))]) {
    testWidgets('on a $name, the sheet states the track IDs under a traced goods line', (tester) async {
      await _openSheet(tester, size, _invoice(_tracks));
      final finder = find.byKey(const ValueKey('invoice-detail-line-tracks-0'));
      await tester.scrollUntilVisible(finder, 120, scrollable: find.byType(Scrollable).last);
      expect(tester.widget<Text>(finder).data, 'Lot: EARLY ×3, LATE ×1 · Pieces: SN-1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a $name, a line without tracks shows none', (tester) async {
      await _openSheet(tester, size, _invoice(const {}));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('invoice-detail-line-0')), 120, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const ValueKey('invoice-detail-line-tracks-0')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
