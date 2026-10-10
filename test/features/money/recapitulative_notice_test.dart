// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — Invoicing says an EU sales list is due while something was
// reverse-charged last month or this month, and says nothing otherwise or
// with the feature off.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/presentation/widgets/recapitulative_notice.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Invoice _ae(DateTime issued) => Invoice(
  id: 'inv-ae',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-AE',
  issuedAt: issued,
  period: '2026-04',
  title: 'INV-AE',
  lines: const [],
  totalCents: 1500,
  currency: 'EUR',
  memberName: 'Kunde',
  memberAddress: '',
  workspaceName: 'Demo',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  vatTotals: const [
    InvoiceVatTotal(
      percent: 0,
      category: 'AE',
      grossCents: 1500,
      netCents: 1500,
      vatCents: 0,
    ),
  ],
  buyerParty: const InvoiceParty(
    name: 'Kunde',
    country: 'DE',
    vatId: 'DE123456789',
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<Invoice> invoices,
  bool enabled = true,
}) async {
  final money = FakeMoneyRepository()..invoices.addAll(invoices);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        workspace: FakeWorkspaceRepository.withWorkspace(),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RecapitulativeNotice(enabled: enabled)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final lastMonth = DateTime(kTestNow.year, kTestNow.month - 1, 20);

  testWidgets('a reverse charge last month: the list is due', (tester) async {
    await _pump(tester, invoices: [_ae(lastMonth)]);
    expect(find.byKey(const ValueKey('recapitulative-notice')), findsOneWidget);
    expect(find.textContaining('An EU sales list is due for'), findsOneWidget);
    expect(find.textContaining('1 reverse-charged invoice'), findsOneWidget);
  });

  testWidgets('nothing reverse-charged lately: no notice', (tester) async {
    await _pump(tester, invoices: [_ae(DateTime(kTestNow.year - 1))]);
    expect(find.byKey(const ValueKey('recapitulative-notice')), findsNothing);
  });

  testWidgets('the feature off: no notice', (tester) async {
    await _pump(tester, invoices: [_ae(lastMonth)], enabled: false);
    expect(find.byKey(const ValueKey('recapitulative-notice')), findsNothing);
  });
}
