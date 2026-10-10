// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — Invoicing says an EU sales list is due while something was
// reverse-charged last month or this month, and says nothing otherwise or
// with the feature off.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/presentation/widgets/recapitulative_notice.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('VAT declarations export the period\'s list as a CSV', (
    tester,
  ) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      vatRegime: 'vat_registered',
    );
    final money = FakeMoneyRepository()
      ..invoices.add(_ae(DateTime(kTestNow.year, kTestNow.month, 3)));
    final saved = <({String name, Uint8List bytes})>[];
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(money: money, workspace: workspace),
          fileSaverProvider.overrideWithValue(({
            required bytes,
            required fileName,
          }) async {
            saved.add((name: fileName, bytes: bytes));
            return fileName;
          }),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/vat-declarations'));
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('vat-recap-csv'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.name, startsWith('eu-sales-list-'));
    expect(
      utf8.decode(saved.single.bytes),
      contains(',DE,123456789,Kunde,15.00,1'),
    );
  });
}
