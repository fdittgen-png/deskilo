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
  return money;
}

void main() {
  testWidgets(
      'the OWNER issues an invoice: member + month → the DERIVED preview '
      'shows the tracked positions and the issued invoice carries exactly '
      'those', (tester) async {
    final money = FakeMoneyRepository();
    // A consumed service booked to the current month joins the
    // statement's subscription + overage on the preview.
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
    expect(invoice.totalCents, 15000 + 1600 + 450);
    expect(invoice.lines.map((l) => l.kind),
        ['subscription', 'overage', 'service']);
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
      sharer: ({required bytes, required fileName, required mimeType}) async {
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
      'a replaced invoice offers no second replacement; a voided-and-'
      'replaced one has no menu at all', (tester) async {
    final money = await seededMoney();
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-07',
      replacesId: 'inv-1',
    );
    await pumpInvoices(tester, money: money);

    expect(find.byKey(const ValueKey('invoice-menu-inv-1')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-menu-inv-2')), findsOneWidget);
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
}

/// The period the fake books to when tests issue "now" — mirrors
/// currentPeriod() without importing intl here.
String currentTestPeriod() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
