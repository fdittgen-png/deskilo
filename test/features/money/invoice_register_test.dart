// SPDX-License-Identifier: 0BSD
//
// The invoice REGISTER (0072): one line per invoice — date, name, amount,
// status — sorted by date in either direction, with the sum at the foot.
// The name column follows the reader: an issuer scans members, a member
// scans their own invoice numbers.
import 'dart:convert';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// Three invoices across three months for two members, in a deliberately
/// unsorted issue order.
Future<FakeMoneyRepository> _seed() async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-05');
  await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-2', period: '2026-06');
  await money.createInvoice(
      workspaceId: 'ws-1', memberId: 'member-1', period: '2026-07');
  // The oldest issue date belongs to the FIRST created one; the fake
  // stamps issuedAt with now(), so nudge them apart explicitly.
  for (var i = 0; i < money.invoices.length; i++) {
    money.invoices[i] = money.invoices[i].copyWith(
      issuedAt: DateTime(2026, 5 + i, 3),
    );
  }
  return money;
}

Future<FakeMoneyRepository> _pumpRegister(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= await _seed();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  // #720 — the register lives on the Invoices face.
  await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-register-button')));
  await tester.pumpAndSettle();
  return money;
}

double _rowY(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey('invoice-register-$id'))).dy;

void main() {
  testWidgets(
      'the register lists every invoice by date, newest first, and sums '
      'them; tapping the date header flips the order', (tester) async {
    final money = await _pumpRegister(tester);
    final ids = money.invoices.map((i) => i.id).toList();

    expect(find.byKey(ValueKey('invoice-register-${ids[0]}')),
        findsOneWidget);
    expect(_rowY(tester, ids[2]), lessThan(_rowY(tester, ids[0])),
        reason: 'newest first by default');

    // 3 × the fake statement total (150.00 + 16.00).
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('invoice-register-total')))
          .data,
      '€498.00',
    );

    await tester.tap(find.byKey(const ValueKey('invoice-register-sort-date')));
    await tester.pumpAndSettle();
    expect(_rowY(tester, ids[0]), lessThan(_rowY(tester, ids[2])),
        reason: 'oldest first after the flip');
  });

  testWidgets(
      'ACCOUNTING EXPORT (0074): the SAF-T file covers exactly what the '
      'register shows — the picked year, nothing else', (tester) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2025-11');
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    money.invoices[0] =
        money.invoices[0].copyWith(issuedAt: DateTime(2025, 12, 1));
    money.invoices[1] =
        money.invoices[1].copyWith(issuedAt: DateTime(2026, 7, 1));

    final saved = <({String name, String body})>[];
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(money: money),
          fileSaverProvider.overrideWithValue(
            ({required bytes, required fileName}) async {
              saved.add((name: fileName, body: utf8.decode(bytes)));
              return 'Download/$fileName';
            },
          ),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    // #720 — the register lives on the Invoices face.
    await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
    await tester.tap(find.byKey(const ValueKey('invoices-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-register-button')));
    await tester.pumpAndSettle();

    // Narrow to 2026, then export.
    await tester.tap(find.byKey(const ValueKey('invoice-register-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-accounting-export')));
    await tester.pumpAndSettle();
    // The fake workspace is DE. Since #669 the sheet always opens and
    // offers what THIS country can use: DATEV for a German
    // Steuerberater, never France's FEC.
    expect(find.byKey(const ValueKey('accounting-export-fec')), findsNothing);
    expect(find.byKey(const ValueKey('accounting-export-datev')),
        findsOneWidget,
        reason: 'a German workspace must be offered the file its '
            'accountant actually imports');
    await tester.tap(find.byKey(const ValueKey('accounting-export-saft')));
    await tester.pumpAndSettle();
    // #669 — the file can now carry derived postings. This test is about
    // the PERIOD it covers, so take the documents-only branch: the
    // postings have their own tests and an account mapping would only
    // add noise here.
    await tester.tap(find.byKey(const ValueKey('saft-documents-only')));
    await tester.pumpAndSettle();

    final file = saved.single;
    expect(file.name, contains('saf-t'));
    expect(file.name, contains('2026'));
    expect(file.body, contains('urn:OECD:StandardAuditFile-Tax:2.00'));
    expect(file.body, contains(money.invoices[1].number));
    expect(file.body, isNot(contains(money.invoices[0].number)),
        reason: 'the 2025 invoice is not in a 2026 audit file');
    expect(file.body, contains('<NumberOfEntries>1</NumberOfEntries>'));
  });

  testWidgets(
      'FEC (0075): a FRENCH workspace chooses its format, states the '
      'accounts, and gets the file named after its SIREN', (tester) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    money.invoices[0] =
        money.invoices[0].copyWith(issuedAt: DateTime(2026, 7, 1));
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      countryCode: 'FR',
      legalId: '812 345 678',
      city: 'Pézenas',
      postalCode: '34120',
    );

    final saved = <({String name, String body})>[];
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(money: money, workspace: workspace),
          fileSaverProvider.overrideWithValue(
            ({required bytes, required fileName}) async {
              saved.add((name: fileName, body: utf8.decode(bytes)));
              return 'Download/$fileName';
            },
          ),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    // #720 — the register lives on the Invoices face.
    await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
    await tester.tap(find.byKey(const ValueKey('invoices-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-register-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-accounting-export')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('accounting-export-fec')));
    await tester.pumpAndSettle();
    // The accounts are shown before anything is booked with them.
    expect(
      tester
          .widget<TextField>(
              find.byKey(const ValueKey('fec-account-customers')))
          .controller!
          .text,
      '411000',
    );
    await tester.enterText(
        find.byKey(const ValueKey('fec-account-revenue')), '70610');
    await tester.tap(find.byKey(const ValueKey('fec-accounts-confirm')));
    await tester.pumpAndSettle();

    final file = saved.single;
    expect(file.name, '812345678FEC20261231.txt');
    final lines = file.body.split('\r\n');
    expect(lines.first.split('\t').first, 'JournalCode');
    expect(lines[1], contains('411000'));
    expect(lines[2], contains('70610'),
        reason: 'the account the owner typed, not the default');
    expect(lines[1], contains('166,00'),
        reason: 'French decimals, and the invoice total from the fake');
  });

  testWidgets('an ISSUER reads MEMBER names — they scan people',
      (tester) async {
    await _pumpRegister(tester);

    expect(find.text('Flo'), findsWidgets);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets(
      'a MEMBER reads INVOICE numbers — nobody needs to be told their own '
      'name in every row', (tester) async {
    final money = await _seed();
    final member = FakeWorkspaceRepository.withWorkspace();
    member.myMember =
        member.myMember.copyWith(isOwner: false, isAdmin: false);
    await _pumpRegister(tester, money: money, workspace: member);

    expect(find.text('Flo'), findsNothing);
    expect(find.text(money.invoices.first.number), findsOneWidget);
  });

  testWidgets(
      'a MEMBER register hides erroneous invoices and names a partial '
      'payment for what it is', (tester) async {
    final money = await _seed();
    final wrong = money.invoices.first.id;
    await money.voidInvoice(wrong);
    final partial = money.invoices.last.id;
    await money.matchInvoice(
      invoiceId: partial,
      // #512 — a payment declared for the month it was RECORDED in
      // (the seed invoice's period was baked long before): cross-month
      // settlement, exactly what matching is for.
      paymentLedgerId: money.seedPayment('member-1', 5000, period: '2026-07'),
      resolution: 'under_accepted',
      note: 'Rest next month',
    );
    final member = FakeWorkspaceRepository.withWorkspace();
    member.myMember =
        member.myMember.copyWith(isOwner: false, isAdmin: false);
    await _pumpRegister(tester, money: money, workspace: member);

    expect(find.byKey(ValueKey('invoice-register-$wrong')), findsNothing,
        reason: 'a cancelled invoice owes the member nothing');
    expect(find.text('Partially paid'), findsOneWidget);
  });
}
