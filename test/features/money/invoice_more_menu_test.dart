// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 train 2, part C -- the invoice page's More menu and its Details: the
// menu runs the entry that was TAPPED, not whatever sits at its position after
// a refresh; Share a reminder and Match a payment are offered for every open or
// partly paid invoice whatever the reminder mode; Cancel and Correct follow
// THIS invoice's own match; one write-off at a time; no proforma on a
// part-paid invoice; and Details shows the settlement trail the old sheet did.
import 'package:deskilo/core/ui/adaptive/task_choice.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_details_section.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page_parts.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

/// The matches the test can change while a menu is open (a refresh).
final ValueNotifier<Map<String, InvoiceMatch>> _matchesNow = ValueNotifier({});

Invoice _invoice(
  String id, {
  List<SettledSource> settles = const [],
  String member = 'kalo',
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: member,
  number: '2026-$id',
  issuedAt: DateTime(2026, 9),
  period: '2026-09',
  title: '2026-09',
  lines: const [InvoiceLine(label: 'Flexible desk', amountCents: 10000)],
  totalCents: 10000,
  currency: 'CHF',
  memberName: 'SASU KaloA',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
  settles: settles,
);

Receivable _receivable(
  String id, {
  ReceivableStage stage = ReceivableStage.open,
  bool paymentPending = false,
  bool awaitingSecondApproval = false,
}) => Receivable(
  invoiceId: id,
  customerId: 'kalo',
  customerName: 'SASU KaloA',
  number: '2026-$id',
  currency: 'CHF',
  totalMinor: 10000,
  openMinor: stage == ReceivableStage.partlyPaid ? 4000 : 10000,
  issuedOn: DateTime(2026, 9),
  stage: stage,
  dueOn: DateTime(2026, 9, 21),
  paymentDeclared: paymentPending,
  awaitingSecondApproval: awaitingSecondApproval,
);

Future<void> _pump(
  WidgetTester tester,
  Invoice invoice,
  Receivable receivable, {
  Map<String, InvoiceMatch> matches = const {},
  bool automatic = false,
}) async {
  _matchesNow.value = matches;
  await pumpApp(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: InvoiceMoreMenu(invoice: invoice, receivable: receivable),
      ),
    ),
    size: const Size(390, 1200),
    overrides: [
      ...standardTestOverrides(),
      invoiceMatchesProvider.overrideWith((ref) async => _matchesNow.value),
      dunningRulesProvider.overrideWith(
        (ref) async => DunningRules(automatic: automatic),
      ),
      invoiceTransmissionsProvider.overrideWith((ref) async => const {}),
      invoiceRemindersProvider.overrideWith((ref) async => const {}),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-page-more')));
  await tester.pumpAndSettle();
}

Finder _entry(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('Share a reminder and Match a payment are in More for an open '
      'invoice, in automatic mode too', (tester) async {
    await _pump(tester, _invoice('0063'), _receivable('0063'), automatic: true);
    expect(_entry('invoice-more-remind'), findsOneWidget);
    expect(find.text('Share a reminder'), findsOneWidget);
    expect(_entry('invoice-more-match'), findsOneWidget);
    expect(find.text('Match a payment'), findsOneWidget);
  });

  testWidgets('both are there for a partly paid invoice, neither for a paid '
      'one', (tester) async {
    await _pump(
      tester,
      _invoice('0064'),
      _receivable('0064', stage: ReceivableStage.partlyPaid),
    );
    expect(_entry('invoice-more-remind'), findsOneWidget);
    expect(_entry('invoice-more-match'), findsOneWidget);
  });

  testWidgets('a paid invoice offers neither', (tester) async {
    await _pump(
      tester,
      _invoice('0058'),
      _receivable('0058', stage: ReceivableStage.paid),
    );
    expect(_entry('invoice-more-remind'), findsNothing);
    expect(_entry('invoice-more-match'), findsNothing);
  });

  testWidgets('Cancel and Correct follow THIS invoice\'s match: offered on '
      'invoice 2 while the customer\'s other payment is matched or '
      'pending', (tester) async {
    // Invoice 1 is matched; the customer also has a payment on its way.
    await _pump(
      tester,
      _invoice('0002'),
      _receivable('0002', paymentPending: true),
      matches: {
        '0001': InvoiceMatch(
          invoiceId: '0001',
          paidCents: 10000,
          resolution: 'exact',
          matchedAt: DateTime(2026, 11, 3),
        ),
      },
    );
    expect(_entry('invoice-more-cancel'), findsOneWidget);
    expect(_entry('invoice-more-replace'), findsOneWidget);
  });

  testWidgets('an invoice that has its own match offers neither', (
    tester,
  ) async {
    await _pump(
      tester,
      _invoice('0001'),
      _receivable('0001'),
      matches: {
        '0001': InvoiceMatch(
          invoiceId: '0001',
          paidCents: 4000,
          resolution: 'under_accepted',
          matchedAt: DateTime(2026, 11, 3),
        ),
      },
    );
    expect(_entry('invoice-more-cancel'), findsNothing);
    expect(_entry('invoice-more-replace'), findsNothing);
  });

  testWidgets('a write-off is offered once: not while one waits for its '
      'approval', (tester) async {
    await _pump(
      tester,
      _invoice('0064'),
      _receivable('0064', stage: ReceivableStage.partlyPaid),
    );
    expect(_entry('invoice-more-writeoff'), findsOneWidget);
  });

  testWidgets('no second write-off while one waits', (tester) async {
    await _pump(
      tester,
      _invoice('0064'),
      _receivable(
        '0064',
        stage: ReceivableStage.partlyPaid,
        awaitingSecondApproval: true,
      ),
    );
    expect(_entry('invoice-more-writeoff'), findsNothing);
  });

  testWidgets('a proforma asks for the whole total: not on a part-paid '
      'invoice', (tester) async {
    await _pump(
      tester,
      _invoice('0064'),
      _receivable('0064', stage: ReceivableStage.partlyPaid),
    );
    expect(_entry('invoice-more-proforma'), findsNothing);
  });

  testWidgets('a proforma is offered on an open invoice', (tester) async {
    await _pump(tester, _invoice('0063'), _receivable('0063'));
    expect(_entry('invoice-more-proforma'), findsOneWidget);
  });

  testWidgets('the menu runs the tapped entry after a refresh, not the one '
      'at its position', (tester) async {
    await _pump(tester, _invoice('0063'), _receivable('0063'));
    // The reads refresh while the menu is open: the list of entries changes
    // (the invoice is matched, so Cancel and Correct leave it).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InvoiceMoreMenu)),
    );
    _matchesNow.value = {
      '0063': InvoiceMatch(
        invoiceId: '0063',
        paidCents: 10000,
        resolution: 'exact',
        matchedAt: DateTime(2026, 11, 3),
      ),
    };
    container.invalidate(invoiceMatchesProvider);
    await tester.pump();
    await tester.pump();
    // Tap Hold reminders: its own action opens its dialog, whatever else the
    // list holds now.
    await tester.tap(_entry('invoice-more-hold'));
    await tester.pumpAndSettle();
    // #3614 — a short task: its words, in a dialog at the desk.
    expect(find.byType(TaskChoice), findsOneWidget);
  });

  testWidgets('Details shows the settlement trail the old sheet did', (
    tester,
  ) async {
    final settlement = _invoice(
      '0090',
      settles: const [
        SettledSource(
          invoiceId: '0061',
          number: '2026-0061',
          totalCents: 10000,
          lines: [InvoiceLine(label: 'Flexible desk', amountCents: 10000)],
        ),
      ],
    ).copyWith(kind: InvoiceKind.settlement);
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: InvoiceDetailsSection(invoice: settlement),
        ),
      ),
      size: const Size(390, 1600),
      overrides: [
        ...standardTestOverrides(),
        invoiceMatchesProvider.overrideWith((ref) async => const {}),
        invoiceTransmissionsProvider.overrideWith((ref) async => const {}),
        invoiceRemindersProvider.overrideWith((ref) async => const {}),
      ],
    );
    await tester.pumpAndSettle();
    // Collapsed first: the page keeps its own words.
    expect(find.byKey(const ValueKey('settlement-source-0061')), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settlement-source-0061')),
      findsOneWidget,
    );
    expect(find.textContaining('Owner'), findsWidgets, reason: 'issued by');
  });
}
