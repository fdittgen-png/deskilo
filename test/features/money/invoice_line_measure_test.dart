// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 -- the invoice sheet states an issued commercial line's exact quantity
// and unit at its entered price (1.5 h at 90 EUR, 0.75 kg at 12.5 EUR per 10
// kg), never the legacy integer; a legacy line shows only its label and amount;
// a line recorded by a newer version is shown and said to be unusable here. On
// a phone and on a desk.
import 'package:deskilo/features/money/presentation/widgets/invoice_detail_sheet.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_line_measure.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Map<String, Object?> _snapshot({
  required String lineId,
  required String quantity,
  required String unitCode,
  required String unitLabel,
  required String unEce,
  required String price,
  String base = '1',
  required int net,
  required int gross,
  int version = 1,
}) => {
  'kind': 'service',
  'label': 'Line $lineId',
  'quantity': 1,
  'amount_cents': gross,
  'vat_percent': 20,
  'commercial': {
    'version': version,
    'line_id': lineId,
    'quantity': quantity,
    'unit': {'code': unitCode, 'un_ece_code': unEce, 'label': unitLabel},
    'unit_price': {
      'amount': price,
      'currency': 'EUR',
      'basis': 'net',
      'base_quantity': base,
    },
    'supply': 'general',
    'tax_facts': <String, Object?>{},
    'amounts': {
      'currency': 'EUR',
      'net_minor': '$net',
      'tax_minor': '${gross - net}',
      'gross_minor': '$gross',
    },
  },
};

final _hours = invoiceLineFromSnapshot(
  _snapshot(
    lineId: 'L-1',
    quantity: '1.5',
    unitCode: 'hour',
    unitLabel: 'h',
    unEce: 'HUR',
    price: '90',
    net: 13500,
    gross: 16200,
  ),
);
final _kilos = invoiceLineFromSnapshot(
  _snapshot(
    lineId: 'L-2',
    quantity: '0.75',
    unitCode: 'kg',
    unitLabel: 'kg',
    unEce: 'KGM',
    price: '12.5',
    base: '10',
    net: 94,
    gross: 113,
  ),
);
final _future = invoiceLineFromSnapshot(
  _snapshot(
    lineId: 'L-3',
    quantity: '2.25',
    unitCode: 'm',
    unitLabel: 'm',
    unEce: 'MTR',
    price: '4',
    net: 900,
    gross: 1080,
    version: 2,
  ),
);
const _legacy = InvoiceLine(
  kind: 'service',
  label: 'Coffee',
  quantity: 3,
  amountCents: 900,
  vatPercent: 20,
);

Invoice _invoice() => Invoice(
  id: 'inv-measured',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'KC-2026-0004',
  issuedAt: DateTime(2026, 9, 10),
  title: 'Measured',
  lines: [_hours, _kilos, _future, _legacy],
  totalCents: 16200 + 113 + 1080 + 900,
  currency: 'EUR',
  memberName: 'Domaine des Aires',
  memberAddress: '',
  workspaceName: 'Kessler Conseil',
  workspaceAddress: '',
  issuerName: 'Bruno',
  signature: 'f' * 64,
);

Future<void> _openSheet(WidgetTester tester, Size size) async {
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
                view: InvoiceDetailView(
                  invoice: _invoice(),
                  match: null,
                  canIssue: true,
                  isEu: true,
                ),
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

Future<void> _expectMeasures(WidgetTester tester) async {
  Finder measure(int i) =>
      find.byKey(ValueKey('invoice-detail-line-measure-$i'));
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('invoice-detail-line-3')),
    120,
    scrollable: find.byType(Scrollable).last,
  );
  expect(
    find.descendant(of: measure(0), matching: find.text('1.5 h at 90 EUR')),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: measure(1),
      matching: find.text('0.75 kg at 12.5 EUR per 10 kg'),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: measure(2),
      matching: find.textContaining('2.25 · Recorded by a newer version'),
    ),
    findsOneWidget,
  );
  expect(measure(3), findsNothing, reason: 'a legacy line shows no measure');
  expect(tester.takeException(), isNull);
}

void main() {
  test('the measure text of each kind of line', () {
    final l10n = AppLocalizationsEn();
    expect(invoiceLineMeasureText(l10n, _hours), '1.5 h at 90 EUR');
    expect(
      invoiceLineMeasureText(l10n, _kilos),
      '0.75 kg at 12.5 EUR per 10 kg',
    );
    expect(
      invoiceLineMeasureText(l10n, _future),
      startsWith('2.25 · '),
      reason: 'the raw quantity of a newer version is shown, never 1',
    );
    expect(invoiceLineMeasureText(l10n, _legacy), isNull);
    expect(_hours.commercial, isA<CommercialLineV1>());
    expect(_future.commercial, isA<CommercialLineUnsupported>());
  });

  testWidgets('on a phone, the sheet states each commercial line exactly', (
    tester,
  ) async {
    await _openSheet(tester, const Size(390, 844));
    await _expectMeasures(tester);
  });

  testWidgets('on a desk, the sheet states each commercial line exactly', (
    tester,
  ) async {
    await _openSheet(tester, const Size(1440, 900));
    await _expectMeasures(tester);
  });
}
