// SPDX-License-Identifier: 0BSD
//
// Invoices (0060/0061/0062): an IMMUTABLE archive whose positions are
// DERIVED — the issue form is member + month + a read-only preview of
// what that month already tracked (subscription, overage, supplements,
// services, packages). Nothing is typed at issue time; an empty month
// cannot be invoiced. Correction stays: void + referencing replacement.
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// A fake archive seeded with one derived invoice for the current month
/// (the default fake statement: 150.00 subscription + 16.00 overage).
Future<FakeMoneyRepository> seededMoney() async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-07',
  );
  return money;
}

Future<FakeMoneyRepository> pumpInvoices(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeWorkspaceRepository? workspace,
  FileSaver? saver,
  FileSharer? sharer,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: workspace,
          fileSharer: sharer,
        ),
        if (saver != null) fileSaverProvider.overrideWithValue(saver),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  // Issuers land on the hub — these tests exercise the ARCHIVE tab;
  // hub tabs have their own tests below. Members have no tabs.
  final archiveTab = find.byKey(const ValueKey('invoice-tab-archive'));
  if (archiveTab.evaluate().isNotEmpty) {
    await tester.tap(archiveTab);
    await tester.pumpAndSettle();
  }
  return money;
}

void main() {
  testWidgets(
      'the OWNER issues an invoice: member + month → the DERIVED preview '
      'shows the tracked positions and the issued invoice carries exactly '
      'those', (tester) async {
    final money = FakeMoneyRepository();
    // A consumed service AND a confirmed payment booked to the current
    // month join the statement's subscription + overage — the invoice
    // nets them into the solde (0063).
    money.ledger.add(LedgerEntry(
      id: 'ledger-1',
      memberId: 'member-1',
      kind: LedgerKind.charge,
      category: LedgerCategory.service,
      amountCents: 450,
      description: 'Coffee ×3',
      period: currentTestPeriod(),
      createdAt: DateTime.now(),
    ));
    money.ledger.add(LedgerEntry(
      id: 'ledger-2',
      memberId: 'member-1',
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: 10000,
      description: 'PayPal',
      period: currentTestPeriod(),
      createdAt: DateTime.now(),
    ));
    await pumpInvoices(tester, money: money);
    expect(find.text('No invoices yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();

    // The read-only preview: subscription 50% (150.00), overage ×2
    // (16.00), the service line — and their total. No text fields.
    expect(find.text('Subscription 50%'), findsOneWidget);
    expect(find.textContaining('extra half-day'), findsOneWidget);
    expect(find.text('Coffee ×3'), findsOneWidget);
    expect(find.textContaining('Payment'), findsOneWidget,
        reason: 'the confirmed payment is a NEGATIVE position');
    expect(find.text('Balance due'), findsOneWidget,
        reason: 'the bottom line is the solde, not a charges total');
    expect(
      find.byKey(const ValueKey('invoice-preview-total')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing,
        reason: 'positions are derived — nothing is typed at issue time');

    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    final invoice = money.invoices.single;
    expect(invoice.period, currentTestPeriod());
    expect(invoice.totalCents, 15000 + 1600 + 450 - 10000,
        reason: 'the invoice total IS the solde: consumptions minus '
            'payments');
    expect(invoice.lines.map((l) => l.kind),
        ['subscription', 'overage', 'service', 'payment']);
    expect(invoice.lines.last.amountCents, -10000);
    expect(invoice.number, startsWith('INV-'));
    expect(find.text('Invoice issued.'), findsOneWidget);
  });

  testWidgets(
      'an EMPTY month cannot be invoiced: the preview says so and Issue '
      'stays disabled', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      feeCents: 0,
      overageCents: 0,
      extraHalfDays: 0,
    );
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('invoice-preview-empty')),
      findsOneWidget,
    );
    final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('invoice-submit')));
    expect(submit.onPressed, isNull,
        reason: 'nothing tracked = nothing to invoice');
    expect(money.invoices, isEmpty);
  });

  testWidgets(
      'the month chevron re-derives the preview for the picked period',
      (tester) async {
    final money = FakeMoneyRepository();
    // Last month tracked nothing.
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    final prevPeriod =
        '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
    money.statements[prevPeriod] = money.statement.copyWith(
      period: prevPeriod,
      feeCents: 0,
      overageCents: 0,
      extraHalfDays: 0,
    );
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    expect(find.text('Subscription 50%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invoice-period-prev')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('invoice-preview-empty')),
      findsOneWidget,
      reason: 'the preview follows the picked month',
    );
    // The current month cannot be exceeded.
    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
    await tester.pumpAndSettle();
    final next = tester.widget<IconButton>(
        find.byKey(const ValueKey('invoice-period-next')));
    expect(next.onPressed, isNull);
  });

  testWidgets(
      'download saves the signed PDF into Downloads under the invoice '
      'number', (tester) async {
    final saved = <({String name, Uint8List bytes})>[];
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      saver: ({required bytes, required fileName}) async {
        saved.add((name: fileName, bytes: bytes));
        return 'Download/$fileName';
      },
    );

    final invoice = money.invoices.single;
    // Font assets and PDF assembly need real async to complete.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('invoice-download-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(saved.single.name, 'inv-2026-0001.pdf');
    expect(String.fromCharCodes(saved.single.bytes.sublist(0, 5)), '%PDF-');
    expect(find.textContaining('Download/inv-2026-0001.pdf'), findsOneWidget);
  });

  testWidgets(
      'share hands the PDF to the system share sheet (mail, WhatsApp…) '
      'via the seam', (tester) async {
    final shared = <({String name, String mime, Uint8List bytes})>[];
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      sharer: ({required bytes, required fileName, required mimeType, text}) async {
        shared.add((name: fileName, mime: mimeType, bytes: bytes));
      },
    );

    final invoice = money.invoices.single;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('invoice-share-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(shared.single.name, 'inv-2026-0001.pdf');
    expect(shared.single.mime, 'application/pdf');
    expect(String.fromCharCodes(shared.single.bytes.sublist(0, 5)), '%PDF-');
  });

  testWidgets(
      'the owner tags an invoice ERRONEOUS (0061): confirm → voided, '
      'struck through with the chip — the row stays in the archive',
      (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());
    final invoice = money.invoices.single;

    await tester.tap(find.byKey(ValueKey('invoice-menu-${invoice.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-void-action')));
    await tester.pumpAndSettle();
    expect(money.invoices.single.isVoided, isFalse);
    await tester.tap(find.byKey(const ValueKey('invoice-void-confirm')));
    await tester.pumpAndSettle();

    expect(money.invoices.single.isVoided, isTrue);
    expect(find.text('Invoice marked as erroneous.'), findsOneWidget);
    expect(find.text('Erroneous'), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-${invoice.id}')), findsOneWidget);
  });

  testWidgets(
      'REPLACE (0061/0062): the replacement RE-DERIVES the same month '
      'from the corrected data and references the erroneous invoice',
      (tester) async {
    final money = await seededMoney();
    final wrong = money.invoices.single;
    // The underlying data was corrected since the wrong invoice: the
    // member's subscription fee changed.
    money.statement = money.statement.copyWith(feeCents: 20000);
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(ValueKey('invoice-menu-${wrong.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-replace-action')));
    await tester.pumpAndSettle();

    // Prefilled member + month; banner names the replaced number; the
    // preview shows the RE-DERIVED positions.
    expect(
      find.byKey(const ValueKey('invoice-replaces-banner')),
      findsOneWidget,
    );
    expect(find.text('Subscription 50%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    expect(money.invoices, hasLength(2));
    final replacement =
        money.invoices.singleWhere((i) => i.id != wrong.id);
    final voided = money.invoices.singleWhere((i) => i.id == wrong.id);
    expect(replacement.replacesInvoiceId, wrong.id);
    expect(replacement.replacesNumber, wrong.number);
    expect(replacement.totalCents, 20000 + 1600,
        reason: 'the replacement carries the corrected derivation');
    expect(replacement.period, wrong.period);
    expect(voided.isVoided, isTrue);
    expect(find.text('Erroneous'), findsOneWidget);
    expect(find.textContaining('Replaces ${wrong.number}'), findsOneWidget);
  });

  testWidgets(
      'a voided-and-replaced invoice offers NO issuer actions — its '
      'menu keeps only the EU e-invoice entries (0066)', (tester) async {
    final money = await seededMoney();
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-07',
      replacesId: 'inv-1',
    );
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-menu-inv-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-void-action')), findsNothing);
    expect(
        find.byKey(const ValueKey('invoice-replace-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-remind-action')), findsNothing,
        reason: 'a voided invoice is not reminded');
    expect(find.byKey(const ValueKey('invoice-einvoice-share')),
        findsOneWidget);
    // Close the menu; the replacement keeps its full issuer menu.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-menu-inv-2')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('invoice-void-action')), findsOneWidget);
  });

  testWidgets(
      'a PLAIN member sees the archive (their own invoices) but no issue '
      'button', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: workspace,
    );
    expect(
      find.byKey(ValueKey('invoice-${money.invoices.single.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invoice-create-button')), findsNothing);
  });

  testWidgets('an admin WITHOUT the adminInvoicing delegation cannot issue',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: true);
    await pumpInvoices(tester, workspace: workspace);
    expect(find.byKey(const ValueKey('invoice-create-button')), findsNothing);
  });

  testWidgets('an admin WITH the adminInvoicing delegation gets the button',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'adminInvoicing': true},
    );
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: true);
    await pumpInvoices(tester, workspace: workspace);
    expect(
      find.byKey(const ValueKey('invoice-create-button')),
      findsOneWidget,
    );
  });
  testWidgets(
      'ARCHIVE FILTERS: member and month narrow the list; sort by month '
      'reorders it', (tester) async {
    final money = FakeMoneyRepository();
    // Flo: June + May; Ana (member-2): July.
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-05');
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-2', period: '2026-07');
    await pumpInvoices(tester, money: money);

    expect(find.byType(ListTile), findsNWidgets(3));

    // Member filter → only Ana's invoice.
    await tester.tap(find.byKey(const ValueKey('invoice-filter-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(1));
    expect(find.textContaining('2026-07'), findsOneWidget);

    // Back to all members, then filter by June.
    await tester.tap(find.byKey(const ValueKey('invoice-filter-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All members').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-filter-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('June 2026').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(1));
    expect(find.textContaining('2026-06'), findsOneWidget);

    // Clear the month filter; sort by month: newest invoiced month
    // first (July, June, May) regardless of issue order.
    await tester.tap(find.byKey(const ValueKey('invoice-filter-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All months').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-sort-period')));
    await tester.pumpAndSettle();
    double rowY(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('invoice-$id'))).dy;
    expect(rowY('inv-3'), lessThan(rowY('inv-2')),
        reason: 'July (inv-3) sorts above June (inv-2)');
    expect(rowY('inv-2'), lessThan(rowY('inv-1')),
        reason: 'June above May');
  });

  testWidgets(
      'a PLAIN member gets the month filter but no member filter (their '
      'archive is theirs alone)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: workspace,
    );
    expect(
        find.byKey(const ValueKey('invoice-filter-member')), findsNothing);
    expect(
        find.byKey(const ValueKey('invoice-filter-period')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-sort')), findsOneWidget);
  });
  testWidgets(
      'the DETAILED toggle (0064) snapshots the annex into the issued '
      'invoice', (tester) async {
    final money = FakeMoneyRepository();
    money.ledger.add(LedgerEntry(
      id: 'ledger-1',
      memberId: 'member-1',
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: 5000,
      description: 'PayPal',
      period: currentTestPeriod(),
      createdAt: DateTime.now(),
    ));
    money.attendanceSeed = const [
      InvoiceAttendance(
        startsAt: '2026-07-12T09:00',
        endsAt: '2026-07-12T13:00',
        space: 'A1 · Window desk',
        status: 'checked_in',
      ),
    ];
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-detailed-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    final invoice = money.invoices.single;
    expect(invoice.detailed, isTrue);
    expect(invoice.detailLedger.single.label, 'PayPal');
    expect(invoice.detailLedger.single.amountCents, -5000,
        reason: 'annex credits are signed like the positions');
    expect(invoice.attendance.single.space, 'A1 · Window desk');
  });
  testWidgets(
      'REMINDER (0066): the owner records a reminder — the PDF goes to '
      'the share sheet with the message, and the row shows the badge',
      (tester) async {
    final shared = <({String name, String mime, String? text})>[];
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        shared.add((name: fileName, mime: mimeType, text: text));
      },
    );
    final invoice = money.invoices.single;

    await tester.tap(find.byKey(ValueKey('invoice-menu-${invoice.id}')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('invoice-remind-action')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(money.invoiceReminders[invoice.id], hasLength(1));
    expect(shared.single.mime, 'application/pdf');
    expect(shared.single.text, contains(invoice.number),
        reason: 'the share text names the invoice');
    expect(find.text('Reminder recorded.'), findsOneWidget);
    expect(find.textContaining('Reminded ×1'), findsOneWidget,
        reason: 'the archive badge reflects the recorded reminder');
  });

  testWidgets(
      'E-INVOICE (0066, EU workspace): even a PLAIN member shares the '
      'EN 16931 XML from the row menu', (tester) async {
    final shared = <({String name, String mime, Uint8List bytes})>[];
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: workspace,
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        shared.add((name: fileName, mime: mimeType, bytes: bytes));
      },
    );
    final invoice = money.invoices.single;

    // The fake workspace is DE — EU, so the menu exists for everyone.
    await tester.tap(find.byKey(ValueKey('invoice-menu-${invoice.id}')));
    await tester.pumpAndSettle();
    // Issuer-only entries stay hidden for the plain member.
    expect(find.byKey(const ValueKey('invoice-remind-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-void-action')), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('invoice-einvoice-share')));
    await tester.pumpAndSettle();

    expect(shared.single.name, 'inv-2026-0001.xml');
    expect(shared.single.mime, 'application/xml');
    final xml = String.fromCharCodes(shared.single.bytes);
    expect(xml, contains('urn:cen.eu:en16931:2017'));
    expect(xml, contains('INV-2026-0001'));
  });

  testWidgets(
      'outside the EU there is no e-invoice affordance — a plain member '
      'has no row menu at all', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(countryCode: 'CH');
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: workspace,
    );
    expect(
      find.byKey(ValueKey('invoice-menu-${money.invoices.single.id}')),
      findsNothing,
    );
  });
  testWidgets(
      'INVOICING HUB: the To-invoice tab lists last month\'s uninvoiced '
      'members with the derived total; Issue prefills member + month; '
      'the member then leaves the list', (tester) async {
    final money = FakeMoneyRepository();
    await pumpInvoices(tester, money: money);
    final prev = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final prevPeriod =
        '${prev.year}-${prev.month.toString().padLeft(2, '0')}';

    await tester.tap(find.byKey(const ValueKey('invoice-tab-todo')));
    await tester.pumpAndSettle();

    // Flo's previous month derives 150.00 + 16.00 → listed.
    expect(find.byKey(const ValueKey('invoice-todo-member-1')),
        findsOneWidget);
    expect(find.textContaining('1 to invoice'), findsOneWidget,
        reason: 'the summary strip counts the pending month');

    await tester.tap(find.byKey(const ValueKey('invoice-issue-member-1')));
    await tester.pumpAndSettle();
    // The issue sheet opens PREFILLED on the member and the month.
    expect(find.text('Subscription 50%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    expect(money.invoices.single.period, prevPeriod);
    expect(money.invoices.single.memberId, 'member-1');
    expect(find.byKey(const ValueKey('invoice-todo-member-1')),
        findsNothing,
        reason: 'an invoiced member leaves the to-invoice list');
    expect(
      find.byKey(const ValueKey('invoice-issue-all')),
      findsNothing,
      reason: 'nothing left — the sweep disappears with the list',
    );
  });

  testWidgets(
      'HUB sweep: Invoice all issues one invoice per listed member',
      (tester) async {
    final money = FakeMoneyRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    workspace.otherMembers.add(workspace.myMember.copyWith(
      id: 'member-2',
      userId: 'user-2',
      isOwner: false,
      isAdmin: false,
    ));
    await pumpInvoices(tester, money: money, workspace: workspace);

    await tester.tap(find.byKey(const ValueKey('invoice-tab-todo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-todo-member-2')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invoice-issue-all')));
    await tester.pumpAndSettle();

    expect(money.invoices, hasLength(2));
    expect(money.invoices.map((i) => i.memberId).toSet(),
        {'member-1', 'member-2'});
    expect(find.text('2 invoices issued.'), findsOneWidget);
    expect(find.textContaining('nothing to invoice'), findsOneWidget);
  });

  testWidgets(
      'HUB Open tab: an unpaid invoice shows its LIVE solde, age and a '
      'direct Remind button; a settled month drops off', (tester) async {
    final money = FakeMoneyRepository();
    final prev = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final prevPeriod =
        '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: prevPeriod);
    final sharedTexts = <String?>[];
    await pumpInvoices(
      tester,
      money: money,
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        sharedTexts.add(text);
      },
    );
    final invoice = money.invoices.single;

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-open-${invoice.id}')),
        findsOneWidget);
    expect(find.textContaining('outstanding'), findsOneWidget);

    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(ValueKey('invoice-remind-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(money.invoiceReminders[invoice.id], hasLength(1));
    expect(sharedTexts.single, contains(invoice.number));

    // The month gets fully paid: zero statement + covering payment →
    // the live solde is gone and the invoice leaves the Open tab.
    money.statements[prevPeriod] = money.statement.copyWith(
        period: prevPeriod, feeCents: 0, overageCents: 0, extraHalfDays: 0);
    // A hub refresh happens whenever the archive changes; issuing the
    // CURRENT month from the FAB is such a change.
    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-open-${invoice.id}')),
        findsNothing,
        reason: 'a settled month is no longer open');
  });
}

/// The period the fake books to when tests issue "now" — mirrors
/// currentPeriod() without importing intl here.
String currentTestPeriod() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
