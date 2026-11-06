// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — the resolution dialog on an unsettled e-invoice submission: offered
// to whoever may issue invoices and only while the outcome is unknown;
// success settles it, a missing reason or evidence is refused under its field
// and sends nothing, and a settled submission offers nothing.

import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_receipt_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

FakeMoneyRepository _money(EInvoiceSubmissionStatus status) {
  final money = FakeMoneyRepository();
  money.transmissions['inv-1'] = InvoiceTransmission(
    id: 't-1',
    invoiceId: 'inv-1',
    status: status,
    sentAt: DateTime(2026, 11, 2, 9),
    provider: 'peppol',
  );
  return money;
}

Future<void> _pump(
  WidgetTester tester,
  FakeMoneyRepository money, {
  required bool canIssue,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: Consumer(
        builder: (context, ref, _) => EInvoiceReceiptLine(
          transmission: money.transmissions['inv-1']!,
          workspaceId: 'ws-1',
          canAsk: canIssue,
        ),
      ),
    ),
    overrides: standardTestOverrides(money: money),
    size: const Size(800, 1400),
  );
  await tester.pump();
}

void main() {
  testWidgets('without the right to issue invoices the action is not offered',
      (tester) async {
    await _pump(tester, _money(EInvoiceSubmissionStatus.uncertain),
        canIssue: false);
    expect(find.byKey(const ValueKey('einvoice-resolve')), findsNothing);
  });

  testWidgets('a settled submission offers nothing to resolve', (tester) async {
    await _pump(tester, _money(EInvoiceSubmissionStatus.accepted),
        canIssue: true);
    expect(find.byKey(const ValueKey('einvoice-resolve')), findsNothing);
  });

  testWidgets('a missing reason, then missing evidence, is refused under its '
      'field and settles nothing; both given, it settles', (tester) async {
    final money = _money(EInvoiceSubmissionStatus.uncertain);
    await _pump(tester, money, canIssue: true);

    await tester.tap(find.byKey(const ValueKey('einvoice-resolve')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('einvoice-resolve-dialog')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('einvoice-resolve-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Say why you are sure.'), findsOneWidget);
    expect(money.transmissions['inv-1']!.status,
        EInvoiceSubmissionStatus.uncertain);

    await tester.enterText(
        find.byKey(const ValueKey('einvoice-resolve-reason')), 'portal shows it');
    await tester.tap(find.byKey(const ValueKey('einvoice-resolve-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Name the platform record you checked.'), findsOneWidget);
    expect(money.transmissions['inv-1']!.status,
        EInvoiceSubmissionStatus.uncertain);

    await tester.enterText(
        find.byKey(const ValueKey('einvoice-resolve-evidence')), 'ref 1, 4 Nov');
    await tester.tap(find.byKey(const ValueKey('einvoice-resolve-submit')));
    await tester.pumpAndSettle();

    expect(money.transmissions['inv-1']!.status,
        EInvoiceSubmissionStatus.accepted);
    expect(find.text('Recorded. The submission is settled.'), findsOneWidget);
    expect(find.byKey(const ValueKey('einvoice-resolve-dialog')), findsNothing);
  });

  testWidgets('"nothing reached the platform" settles it as a failure that may '
      'be sent again', (tester) async {
    final money = _money(EInvoiceSubmissionStatus.uncertain);
    await _pump(tester, money, canIssue: true);

    await tester.tap(find.byKey(const ValueKey('einvoice-resolve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('einvoice-resolve-failed')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('einvoice-resolve-reason')), 'no trace');
    await tester.enterText(
        find.byKey(const ValueKey('einvoice-resolve-evidence')), 'ticket 9');
    await tester.tap(find.byKey(const ValueKey('einvoice-resolve-submit')));
    await tester.pumpAndSettle();

    expect(money.transmissions['inv-1']!.status,
        EInvoiceSubmissionStatus.failed);
  });

  testWidgets('settled elsewhere meanwhile: the dialog says so and changes '
      'nothing', (tester) async {
    final money = _money(EInvoiceSubmissionStatus.uncertain);
    await _pump(tester, money, canIssue: true);

    await tester.tap(find.byKey(const ValueKey('einvoice-resolve')));
    await tester.pumpAndSettle();
    // someone else settled it while the dialog was open
    money.transmissions['inv-1'] =
        money.transmissions['inv-1']!.copyWithStatus(
      EInvoiceSubmissionStatus.rejected,
    );
    await tester.enterText(
        find.byKey(const ValueKey('einvoice-resolve-reason')), 'portal shows it');
    await tester.enterText(
        find.byKey(const ValueKey('einvoice-resolve-evidence')), 'ref 1');
    await tester.tap(find.byKey(const ValueKey('einvoice-resolve-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Someone already settled this submission.'),
        findsOneWidget);
    expect(money.transmissions['inv-1']!.status,
        EInvoiceSubmissionStatus.rejected);
  });
}
