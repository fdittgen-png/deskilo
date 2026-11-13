// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 — the Invoices face at the desk: my invoices as a records table, the
// total per currency under it; the phone keeps its list.
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/money_faces.dart';

void main() {
  testWidgets('at the desk my invoices are a table with their total; on a '
      'phone the list stays', (tester) async {
    final money = FakeMoneyRepository();
    final id = await openInvoice(money);
    final number = money.invoices.firstWhere((i) => i.id == id).number;

    await pumpFaces(tester, money: money, size: const Size(1440, 1000));
    await face(tester, MoneyFace.invoices);
    expect(find.text(number), findsOneWidget);
    expect(find.byKey(const ValueKey('records-total-EUR')), findsOneWidget);
    expect(find.byKey(ValueKey('my-invoice-$id')), findsNothing);
  });

  testWidgets('on a phone the Invoices face keeps its list', (tester) async {
    final money = FakeMoneyRepository();
    final id = await openInvoice(money);
    await pumpFaces(tester, money: money, size: const Size(390, 1400));
    await face(tester, MoneyFace.invoices);
    expect(find.byKey(ValueKey('my-invoice-$id')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-total-EUR')), findsNothing);
  });
}
