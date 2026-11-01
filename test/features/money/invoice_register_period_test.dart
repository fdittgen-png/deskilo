// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the invoice register opened from a figure: the rows of its months,
// a chip that says so, and a way back to every invoice.
import 'package:deskilo/features/money/presentation/screens/invoice_register_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> _seed() async {
  final money = FakeMoneyRepository();
  for (final period in ['2026-05', '2026-06', '2026-07']) {
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: period,
    );
  }
  for (var i = 0; i < money.invoices.length; i++) {
    money.invoices[i] = money.invoices[i].copyWith(
      issuedAt: DateTime(2026, 5 + i, 3),
    );
  }
  return money;
}

Future<FakeMoneyRepository> _pump(
  WidgetTester tester, {
  String? from,
  String? to,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final money = await _seed();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        workspace: FakeWorkspaceRepository.withWorkspace(),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceRegisterScreen(from: from, to: to),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return money;
}

Finder _row(String id) => find.byKey(ValueKey('invoice-register-$id'));
const _chip = ValueKey('invoice-register-period');
const _clear = ValueKey('invoice-register-period-clear');

void main() {
  testWidgets('a period shows only the invoices of its months, with a chip', (
    tester,
  ) async {
    final money = await _pump(tester, from: '2026-06', to: '2026-07');
    final ids = money.invoices.map((i) => i.id).toList();
    expect(_row(ids[0]), findsNothing);
    expect(_row(ids[1]), findsOneWidget);
    expect(_row(ids[2]), findsOneWidget);
    expect(find.byKey(_chip), findsOneWidget);
    expect(find.textContaining('Period:'), findsOneWidget);
  });

  testWidgets('clearing the chip brings every invoice back', (tester) async {
    final money = await _pump(tester, from: '2026-06', to: '2026-06');
    final ids = money.invoices.map((i) => i.id).toList();
    expect(_row(ids[0]), findsNothing);
    await tester.tap(find.byKey(_clear));
    await tester.pumpAndSettle();
    expect(find.byKey(_chip), findsNothing);
    for (final id in ids) {
      expect(_row(id), findsOneWidget);
    }
  });

  testWidgets('a period holding nothing keeps its chip beside the empty state', (
    tester,
  ) async {
    await _pump(tester, from: '2025-01', to: '2025-01');
    expect(find.byKey(_chip), findsOneWidget);
    expect(find.byKey(_clear), findsOneWidget);
  });

  testWidgets('a malformed or one-sided period is ignored: the whole register', (
    tester,
  ) async {
    for (final pair in const [
      ('junk', '2026-06'),
      ('2026-06', null),
      ('2026-13', '2026-14'),
    ]) {
      final money = await _pump(tester, from: pair.$1, to: pair.$2);
      expect(find.byKey(_chip), findsNothing, reason: '$pair');
      for (final i in money.invoices) {
        expect(_row(i.id), findsOneWidget, reason: '$pair');
      }
    }
  });

  testWidgets('without a period the register is what it always was', (
    tester,
  ) async {
    final money = await _pump(tester);
    expect(find.byKey(_chip), findsNothing);
    expect(_row(money.invoices.first.id), findsOneWidget);
  });
}
