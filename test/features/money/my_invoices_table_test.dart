// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 — the Invoices face at the desk: my invoices as a records table, the
// total per currency under it; the phone keeps its list.
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/features/money/presentation/widgets/my_credits_table.dart';
import 'package:deskilo/features/money/presentation/widgets/usage_table.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
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

  testWidgets('at the desk the Payments face lists my payments and credits '
      'as a table under its actions', (tester) async {
    await pumpFaces(tester, size: const Size(1440, 1000));
    await face(tester, MoneyFace.payments);
    expect(
      find.byKey(const ValueKey('money-face-body-payments')),
      findsOneWidget,
    );
    expect(find.byType(MyCreditsTable), findsOneWidget);
  });

  testWidgets('at the desk the Usage face is the month\'s bookings as a '
      'table', (tester) async {
    await pumpFaces(
      tester,
      flags: {WorkspaceFeature.usageRecords.dbKey: true},
      size: const Size(1440, 1000),
    );
    await face(tester, MoneyFace.usage);
    expect(find.byType(UsageTable), findsOneWidget);
  });

  testWidgets('at the desk the Documents face names the month its reports are '
      'made for', (tester) async {
    await pumpFaces(tester, size: const Size(1440, 1000));
    await face(tester, MoneyFace.documents);
    expect(find.byKey(const ValueKey('money-reports-month')), findsOneWidget);
  });
}
