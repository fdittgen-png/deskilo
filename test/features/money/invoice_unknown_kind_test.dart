// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3730 — an invoice of a kind a newer server sent is read and printed;
// every action that would change it (correct, remind, mark paid or
// erroneous, hold the dunning, e-invoice, pay) is refused with the sentence
// that says why, through the one path every invoice action takes.
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_detail_sheet.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _future = Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'F-1',
  issuedAt: DateTime(2026, 11, 13),
  title: '2026-11',
  lines: const [],
  totalCents: 1000,
  currency: 'EUR',
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 's',
  kind: InvoiceKind.fromWire('future_kind'),
);

void main() {
  for (final action in [
    for (final a in InvoiceAction.values)
      if (a != InvoiceAction.quickView &&
          a != InvoiceAction.downloadPdf &&
          a != InvoiceAction.sharePdf)
        a,
  ]) {
    testWidgets('${action.name} is refused on an unknown kind', (tester) async {
      expect(_future.kind, InvoiceKind.unknown);
      await pumpApp(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              key: const ValueKey('run'),
              onPressed: () => runInvoiceAction(
                context,
                ref,
                action,
                _future,
                countryCode: 'FR',
              ),
              child: const Text('run'),
            ),
          ),
        ),
        overrides: standardTestOverrides(),
      );
      await tester.tap(find.byKey(const ValueKey('run')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('it can be read, not changed'),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
    });
  }
}
