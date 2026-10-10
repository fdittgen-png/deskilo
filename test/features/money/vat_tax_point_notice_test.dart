// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355 — a French VAT-registered space that never chose when its VAT
// falls due moved from the invoice date to receipts, the legal rule for
// services. Its owner is told once, on the declarations screen, and the
// notice goes when dismissed or once the space has chosen. The screen
// then declares on receipts, from every payment recorded one by one.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> _pump(
  WidgetTester tester, {
  Map<String, Object?> invoiceLegal = const {},
  String country = 'FR',
  void Function(FakeMoneyRepository money)? seed,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    countryCode: country,
    vatRegime: 'vat_registered',
    invoiceLegal: invoiceLegal,
  );
  final money = FakeMoneyRepository();
  seed?.call(money);
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/vat-declarations'));
  await tester.pumpAndSettle();
  return money;
}

const _notice = ValueKey('vat-tax-point-notice');

void main() {
  testWidgets('a French space that never chose is told once, and the '
      'notice stays gone when dismissed', (tester) async {
    await _pump(tester);
    expect(find.byKey(_notice), findsOneWidget);
    expect(find.textContaining('taxed on receipts'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(_notice),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_notice), findsNothing);
  });

  testWidgets('a space that chose, or one outside France, is not told', (
    tester,
  ) async {
    await _pump(tester, invoiceLegal: const {'vat_tax_point': 'invoice'});
    expect(find.byKey(_notice), findsNothing);
  });

  testWidgets('a German space is not told either', (tester) async {
    await _pump(tester, country: 'DE');
    expect(find.byKey(_notice), findsNothing);
  });

  testWidgets('the screen declares on receipts, from each instalment', (
    tester,
  ) async {
    final now = kTestNow;
    final money = await _pump(
      tester,
      seed: (money) {
        money.invoices.add(
          Invoice(
            id: 'a',
            workspaceId: 'ws-1',
            memberId: 'member-1',
            number: 'INV-a',
            issuedAt: DateTime(now.year, now.month - 1, 10),
            title: 'Invoice a',
            lines: const [
              InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
            ],
            totalCents: 12000,
            currency: 'EUR',
            memberName: 'Flo',
            memberAddress: '',
            workspaceName: 'Space',
            workspaceAddress: '',
            issuerName: 'Flo',
            signature: 'sig',
          ),
        );
        money.invoiceMatchesStore['a'] = InvoiceMatch(
          invoiceId: 'a',
          paidCents: 12000,
          resolution: 'exact',
          matchedAt: DateTime(now.year, now.month, 2, 12),
        );
        // Half last month, half this month: this month declares half.
        money.invoiceInstalmentsStore['a'] = [
          TaxPointPayment(DateTime(now.year, now.month - 1, 20, 12), 6000),
          TaxPointPayment(DateTime(now.year, now.month, 2, 12), 6000),
        ];
      },
    );
    await tester.tap(find.byKey(const ValueKey('vat-decl-generate')));
    await tester.pumpAndSettle();
    final declaration = money.vatDeclarations.single;
    expect(declaration.totalVatCents, 1000);
    expect(declaration.invoiceCount, 1);
  });
}
