// SPDX-License-Identifier: 0BSD
//
// Invoices (0060/0061/0062): an IMMUTABLE archive whose positions are
// DERIVED — the issue form is member + month + a read-only preview of
// what that month already tracked (subscription, overage, supplements,
// services, packages). Nothing is typed at issue time; an empty month
// cannot be invoiced. Correction stays: void + referencing replacement.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// A fake archive seeded with one derived invoice for the current month
/// (the default fake statement: 150.00 subscription + 16.00 overage).
Future<FakeMoneyRepository> seededMoney({
  bool matched = true,
  FakeEventRepository? events,
}) async {
  final money = FakeMoneyRepository(events: events);
  final id = await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    // The running month — so the seed does not go stale with the calendar.
    period: currentTestPeriod(),
  );
  // 0067 — the hub's archive holds CLOSED invoices only; row-affordance
  // tests want their seed there, so it ships matched (0068: against a
  // seeded registered payment).
  if (matched) {
    await money.matchInvoice(
      invoiceId: id,
      paymentLedgerId:
          money.seedPayment('member-1', money.invoices.single.totalCents),
      resolution: 'exact',
    );
  }
  return money;
}

Future<FakeMoneyRepository> pumpInvoices(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeWorkspaceRepository? workspace,
  FakeEventRepository? events,
  FileSaver? saver,
  FileSharer? sharer,
  FilePicker? picker,
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
          events: events,
          fileSharer: sharer,
        ),
        if (saver != null) fileSaverProvider.overrideWithValue(saver),
        if (picker != null) filePickerProvider.overrideWithValue(picker),
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
  // Issuers land on the hub — these tests exercise the ARCHIVE tab;
  // hub tabs have their own tests below. Members have no tabs.
  final archiveTab = find.byKey(const ValueKey('invoice-tab-archive'));
  if (archiveTab.evaluate().isNotEmpty) {
    await tester.tap(archiveTab);
    await tester.pumpAndSettle();
  }
  return money;
}

/// True when the PDF paints something at 45° — the diagonal watermark.
/// Its text is font-encoded, so only the drawing operators can be read.
bool _isWatermarked(Uint8List bytes) {
  final raw = String.fromCharCodes(bytes);
  for (final match in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', match.end);
    if (end < 0) continue;
    try {
      final ops =
          String.fromCharCodes(zlib.decode(bytes.sublist(match.end, end)));
      if (RegExp(r'0\.707\d* 0\.707\d* -0\.707').hasMatch(ops)) return true;
    } catch (_) {
      // Not a deflated stream (fonts, metadata).
    }
  }
  return false;
}

/// Opens an archive row's DETAIL sheet — since the invoicing UX pass,
/// reading an invoice and acting on it both live there instead of in a row
/// of icon buttons and an overflow menu.
Future<void> openInvoice(WidgetTester tester, String invoiceId) async {
  await tester.tap(find.byKey(ValueKey('invoice-$invoiceId')));
  await tester.pumpAndSettle();
}

/// Reveals the cancelled (voided) rows — hidden by default since #452.
Future<void> showCancelled(WidgetTester tester) async {
  await tester
      .tap(find.byKey(const ValueKey('invoice-filter-hide-voided')));
  await tester.pumpAndSettle();
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
      createdAt: kTestNow,
    ));
    money.ledger.add(LedgerEntry(
      id: 'ledger-2',
      memberId: 'member-1',
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: 10000,
      description: 'PayPal',
      period: currentTestPeriod(),
      createdAt: kTestNow,
    ));
    await pumpInvoices(tester, money: money);
    expect(find.text('No invoices yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    // The sheet opens on the COMPLETED month — the billing moment. This
    // test is about the RUNNING month's tracked data, so step forward,
    // which is also where the "still running" warning belongs.
    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('invoice-running-month-banner')),
      findsOneWidget,
      reason: 'a month can only be invoiced once — say so before it ends',
    );

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
      'the sheet opens on the COMPLETED month and the chevron re-derives '
      'the preview for the picked period', (tester) async {
    final money = FakeMoneyRepository();
    // Last month tracked nothing — and last month is where the sheet
    // lands, because that is the month whose numbers no longer move.
    final now = kTestNow;
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
    expect(
      find.byKey(const ValueKey('invoice-preview-empty')),
      findsOneWidget,
      reason: 'the default month is the completed one, which tracked '
          'nothing here',
    );
    expect(find.byKey(const ValueKey('invoice-running-month-banner')),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
    await tester.pumpAndSettle();
    expect(find.text('Subscription 50%'), findsOneWidget,
        reason: 'the preview follows the picked month');
    // The current month cannot be exceeded.
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
    // Download is the one action frequent enough to stay ON the row.
    // Font assets and PDF assembly need real async to complete.
    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(ValueKey('invoice-download-row-${invoice.id}')));
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
    await openInvoice(tester, invoice.id);
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
    final money =
        await pumpInvoices(tester, money: await seededMoney(matched: false));
    final invoice = money.invoices.single;

    // 0068 — an invoice EN COURS is corrected from the Open tab.
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('invoice-void-open-${invoice.id}')));
    await tester.pumpAndSettle();
    expect(money.invoices.single.isVoided, isFalse);
    await tester.tap(find.byKey(const ValueKey('invoice-void-confirm')));
    await tester.pumpAndSettle();

    expect(money.invoices.single.isVoided, isTrue);
    expect(find.text('Invoice marked as erroneous.'), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-open-${invoice.id}')), findsNothing,
        reason: 'the voided invoice leaves the Open tab');
    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    // #452: cancelled rows are hidden by default; the chip reveals the
    // correction trail.
    expect(find.byKey(ValueKey('invoice-${invoice.id}')), findsNothing,
        reason: 'voided invoices are filtered out by default');
    await showCancelled(tester);
    expect(find.text('Erroneous'), findsOneWidget);
    expect(find.byKey(ValueKey('invoice-${invoice.id}')), findsOneWidget);
  });

  testWidgets(
      'REPLACE (0061/0062): the replacement RE-DERIVES the same month '
      'from the corrected data and references the erroneous invoice',
      (tester) async {
    final money = await seededMoney(matched: false);
    final wrong = money.invoices.single;
    // 0068 — correction path: void first, then replace from the
    // voided archive row.
    await money.voidInvoice(wrong.id);
    // The underlying data was corrected since the wrong invoice: the
    // member's subscription fee changed.
    money.statement = money.statement.copyWith(feeCents: 20000);
    await pumpInvoices(tester, money: money);

    await showCancelled(tester);
    await openInvoice(tester, wrong.id);
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
    // The voided one stays archived; the fresh replacement is OPEN
    // (unmatched, 0067) and shows on the Open tab.
    expect(find.text('Erroneous'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-open-${replacement.id}')),
        findsOneWidget);
  });

  testWidgets(
      'a voided-and-replaced invoice offers NO issuer actions — its detail '
      'sheet keeps only the file exports (0066)', (tester) async {
    final money = await seededMoney();
    final replacementId = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-07',
      replacesId: 'inv-1',
    );
    await money.matchInvoice(
      invoiceId: replacementId,
      paymentLedgerId: money.seedPayment(
          'member-1',
          money.invoices
              .firstWhere((i) => i.id == replacementId)
              .totalCents),
      resolution: 'exact',
    );
    await pumpInvoices(tester, money: money);

    await showCancelled(tester);
    await openInvoice(tester, 'inv-1');
    expect(find.byKey(const ValueKey('invoice-void-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-replace-action')), findsNothing,
        reason: 'corrections form a chain, never a fork (0061)');
    expect(find.byKey(const ValueKey('invoice-remind-action')), findsNothing,
        reason: 'a voided invoice is not reminded');
    expect(find.text('Replaced by INV-2026-0002'), findsOneWidget,
        reason: 'the sheet says where the correction went');
    expect(find.byKey(const ValueKey('invoice-einvoice-action')),
        findsOneWidget);
    // Close the sheet; the MATCHED replacement is definitive (0068): its
    // sheet also keeps only the file exports.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await openInvoice(tester, 'inv-2');
    expect(find.byKey(const ValueKey('invoice-void-action')), findsNothing);
    expect(
        find.byKey(const ValueKey('invoice-replace-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-remind-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-einvoice-action')),
        findsOneWidget);
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
    // Flo: June + May; Ana (member-2): July — all matched (the archive
    // shows closed invoices, 0067).
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-05');
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-2', period: '2026-07');
    for (final invoice in List.of(money.invoices)) {
      await money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId:
            money.seedPayment(invoice.memberId, invoice.totalCents),
        resolution: 'exact',
      );
    }
    await pumpInvoices(tester, money: money);

    expect(find.byType(ListTile), findsNWidgets(3));

    // Member filter → only Ana's invoice.
    await tester.tap(find.byKey(const ValueKey('invoice-filter-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(1));
    expect(find.textContaining('July 2026'), findsOneWidget,
        reason: 'rows read the month, never the raw 2026-07 period');

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
    expect(find.textContaining('June 2026 · Flo'), findsOneWidget,
        reason: 'the row names the month and the member');
    expect(find.byKey(const ValueKey('invoice-count')), findsOneWidget);

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
      createdAt: kTestNow,
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
    // The seeded activity sits in the RUNNING month.
    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
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
      money: await seededMoney(matched: false),
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        shared.add((name: fileName, mime: mimeType, text: text));
      },
    );
    final invoice = money.invoices.single;

    // 0068 — an invoice EN COURS is reminded from its Open card.
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(ValueKey('invoice-remind-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(money.invoiceReminders[invoice.id], hasLength(1));
    expect(shared.single.mime, 'application/pdf');
    expect(shared.single.text, contains(invoice.number),
        reason: 'the share text names the invoice');
    expect(find.text('Reminder recorded.'), findsOneWidget);
    expect(find.textContaining('Reminded ×1'), findsOneWidget,
        reason: 'the open card reflects the recorded reminder');
  });

  testWidgets(
      'MATCH with NO registered payment (0068): the dialog explains that '
      'the payment must be recorded first and confirm stays inert',
      (tester) async {
    final money = await seededMoney(matched: false);
    await pumpInvoices(tester, money: money);
    final invoice = money.invoices.single;

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-match-${invoice.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invoice-match-no-payments')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();
    expect(money.invoiceMatchesStore, isEmpty,
        reason: 'nothing to map — the confirm cannot create a match');
    expect(find.byKey(const ValueKey('invoice-match-confirm')),
        findsOneWidget, reason: 'the dialog stays open');
  });

  testWidgets(
      'E-INVOICE (0066, EU workspace): the sheet says WHERE the file has to '
      'go, then even a PLAIN member shares the EN 16931 XML', (tester) async {
    final shared = <({String name, String mime, Uint8List bytes})>[];
    final workspace = FakeWorkspaceRepository.withWorkspace();
    // 0069 — a workspace WITH its legal identity: without it the export
    // refuses (see the readiness test below).
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      legalId: 'HRB 12345 B',
      city: 'Berlin',
      postalCode: '10115',
    );
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

    // The fake workspace is DE — EU, so the export exists for everyone.
    await openInvoice(tester, invoice.id);
    // Issuer-only actions stay hidden for the plain member.
    expect(find.byKey(const ValueKey('invoice-remind-action')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-void-action')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invoice-einvoice-action')));
    await tester.pumpAndSettle();

    // Germany imposes no channel — the sheet says so instead of leaving
    // "where do I send this?" to the reader.
    expect(find.textContaining('XRechnung'), findsOneWidget);
    expect(find.textContaining('OZG-RE'), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-einvoice-format-warning')),
        findsNothing, reason: 'EN 16931 UBL is fine on a German route');

    await tester.tap(find.byKey(const ValueKey('invoice-einvoice-share')));
    await tester.pumpAndSettle();

    expect(shared.single.name, 'inv-2026-0001.xml');
    expect(shared.single.mime, 'application/xml');
    final xml = String.fromCharCodes(shared.single.bytes);
    expect(xml, contains('urn:cen.eu:en16931:2017'));
    expect(xml, contains('INV-2026-0001'));
  });

  testWidgets(
      'outside the EU there is no e-invoice affordance — the sheet offers '
      'the PDF only', (tester) async {
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
    await openInvoice(tester, money.invoices.single.id);
    expect(find.byKey(const ValueKey('invoice-einvoice-action')),
        findsNothing);
    expect(
      find.byKey(ValueKey('invoice-share-${money.invoices.single.id}')),
      findsOneWidget,
    );
  });
  testWidgets(
      'INVOICING HUB: the To-invoice tab lists last month\'s uninvoiced '
      'members with the derived total; Issue prefills member + month; '
      'the member then leaves the list', (tester) async {
    final money = FakeMoneyRepository();
    await pumpInvoices(tester, money: money);
    final prev = DateTime(kTestNow.year, kTestNow.month - 1);
    final prevPeriod =
        '${prev.year}-${prev.month.toString().padLeft(2, '0')}';

    await tester.tap(find.byKey(const ValueKey('invoice-tab-todo')));
    await tester.pumpAndSettle();

    // Flo's previous month derives 150.00 + 16.00 → listed.
    expect(find.byKey(const ValueKey('invoice-todo-member-1')),
        findsOneWidget);
    // #812 — the stage strip's first tile counts the pending month.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invoice-stage-issue')),
        matching: find.text('1'),
      ),
      findsOneWidget,
      reason: 'the stage strip counts the pending month',
    );

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

    // The sweep is N immutable documents in one tap — it confirms first.
    await tester.tap(find.byKey(const ValueKey('invoice-issue-all')));
    await tester.pumpAndSettle();
    expect(money.invoices, isEmpty, reason: 'nothing issued before confirm');
    await tester
        .tap(find.byKey(const ValueKey('invoice-issue-all-confirm')));
    await tester.pumpAndSettle();

    expect(money.invoices, hasLength(2));
    expect(money.invoices.map((i) => i.memberId).toSet(),
        {'member-1', 'member-2'});
    expect(find.text('2 invoices issued.'), findsOneWidget);
    expect(find.textContaining('nothing to invoice'), findsOneWidget);
  });

  testWidgets(
      'PROFORMA (0072): the To-invoice row shares the month as a proforma '
      'and issues NOTHING', (tester) async {
    final shared = <({String name, String mime})>[];
    final money = await pumpInvoices(
      tester,
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        shared.add((name: fileName, mime: mimeType));
      },
    );

    await tester.tap(find.byKey(const ValueKey('invoice-tab-todo')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('invoice-proforma-member-1')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // #514 — the triad sheet; Share hands the proforma out.
      await tester.tap(find.byKey(const ValueKey('proforma-share')));
      await tester.pump();
      // The chain reads providers BEFORE it renders: give the whole of it
      // real time, or the font load lands back on the fake clock.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(shared.single.mime, 'application/pdf');
    expect(shared.single.name, contains('proforma'),
        reason: 'the file must never look like the invoice');
    expect(money.invoices, isEmpty,
        reason: 'a proforma issues nothing — no number is burned');
  });

  testWidgets(
      'PROFORMA (0072): the Open card re-sends the issued invoice as a '
      'payment request, and its actions are ICONS so nothing clips',
      (tester) async {
    final shared = <String>[];
    final money = await seededMoney(matched: false);
    await pumpInvoices(
      tester,
      money: money,
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        shared.add(fileName);
      },
    );
    final invoice = money.invoices.single;

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();

    // Field report: three localized labels side by side ran off the card.
    expect(find.text('Send a reminder'), findsNothing);
    expect(find.text('Mark as paid'), findsNothing);
    for (final action in ['void-open', 'proforma', 'remind', 'match']) {
      expect(
        find.byKey(ValueKey('invoice-$action-${invoice.id}')),
        findsOneWidget,
        reason: '$action must stay reachable as an icon',
      );
    }

    await tester
        .tap(find.byKey(ValueKey('invoice-proforma-${invoice.id}')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('proforma-share')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(shared.single, contains('proforma'));
    expect(money.invoices.single.isVoided, isFalse,
        reason: 're-sending changes nothing about the issued document');
  });

  testWidgets(
      'LIFECYCLE (0067): an issued invoice stays OPEN until matched; an '
      'exact match archives it with the Paid badge', (tester) async {
    final money = await seededMoney(matched: false);
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

    // Open tab: the invoice with the summary strip, remind and match.
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-open-${invoice.id}')),
        findsOneWidget);
    expect(find.textContaining('outstanding'), findsOneWidget);

    // Reminders still work from here.
    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(ValueKey('invoice-remind-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(money.invoiceReminders[invoice.id], hasLength(1));
    expect(sharedTexts.single, contains(invoice.number));

    // The exact match closes it — 0068: mapped to the REGISTERED
    // payment, never a typed amount.
    final payId =
        money.seedPayment('member-1', invoice.totalCents, description: 'IBAN');
    await tester.tap(find.byKey(ValueKey('invoice-match-${invoice.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-match-amount')), findsNothing,
        reason: 'no typed amount — the payment picker is the only input');
    await tester
        .tap(find.byKey(ValueKey('invoice-match-payment-$payId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();

    // (The snack queues behind the reminder snack — the store is the
    // truth here.)
    expect(money.invoiceMatchesStore[invoice.id]!.resolution, 'exact');
    expect(money.invoiceMatchesStore[invoice.id]!.paymentLedgerId, payId,
        reason: 'the match records WHICH payment settled the invoice');
    expect(find.byKey(ValueKey('invoice-open-${invoice.id}')),
        findsNothing, reason: 'a matched invoice leaves the Open tab');
    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-${invoice.id}')), findsOneWidget,
        reason: 'only matched invoices archive');
    expect(find.textContaining('Paid'), findsOneWidget);
  });

  testWidgets(
      'OVERPAYMENT (0067): the dialog offers forced-OK or a credit note '
      '— the credit note lands the excess on the ledger', (tester) async {
    final money = await seededMoney(matched: false);
    await pumpInvoices(tester, money: money);
    final invoice = money.invoices.single;

    final payId = money.seedPayment('member-1', 20000);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-match-${invoice.id}')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('invoice-match-payment-$payId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-match-credit-note')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('invoice-match-force')), findsOneWidget);
    // Credit note is preselected — confirm.
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();

    final match = money.invoiceMatchesStore[invoice.id]!;
    expect(match.resolution, 'over_credit_note');
    expect(match.paidCents, 20000);
    final credit = money.ledger.last;
    expect(credit.kind, LedgerKind.credit);
    expect(credit.amountCents, 20000 - invoice.totalCents,
        reason: 'the excess becomes a ledger credit note');
    expect(credit.description, contains(invoice.number));
  });

  testWidgets(
      'UNDERPAYMENT (0067): accepting less REQUIRES a note — the inline '
      'error blocks an empty one', (tester) async {
    final money = await seededMoney(matched: false);
    await pumpInvoices(tester, money: money);
    final invoice = money.invoices.single;

    final payId = money.seedPayment('member-1', 10000);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-match-${invoice.id}')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('invoice-match-payment-$payId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('A note is required.'), findsOneWidget);
    expect(money.invoiceMatchesStore, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('invoice-match-note')),
      'Hardship agreed with Flo',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();
    final match = money.invoiceMatchesStore[invoice.id]!;
    expect(match.resolution, 'under_accepted');
    expect(match.note, 'Hardship agreed with Flo');
  });

  testWidgets(
      'VALIDATION (0067): with a rule configured the match awaits the '
      'quorum — the card shows the chip and no further actions',
      (tester) async {
    final money = await seededMoney(matched: false)
      ..matchPolicyConfigured = true;
    await pumpInvoices(tester, money: money);
    final invoice = money.invoices.single;

    final payId = money.seedPayment('member-1', invoice.totalCents);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-match-${invoice.id}')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('invoice-match-payment-$payId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
    await tester.pumpAndSettle();

    expect(money.invoiceMatchesStore[invoice.id]!.pending, isTrue);
    expect(
      find.byKey(ValueKey('invoice-match-pending-${invoice.id}')),
      findsOneWidget,
      reason: 'the pending match stays on Open, awaiting validation',
    );
    expect(find.byKey(ValueKey('invoice-match-${invoice.id}')),
        findsNothing);
    expect(find.byKey(ValueKey('invoice-remind-${invoice.id}')),
        findsNothing);
    // Rejected by the quorum → the match disappears server-side and the
    // invoice reopens.
    money.invoiceMatchesStore.remove(invoice.id);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('invoice-match-${invoice.id}')),
        findsNothing, reason: 'stale providers: refresh happens on the '
            'next archive change; the chip is gone after re-derive');
  });

  testWidgets(
      'ONE ACTIVE INVOICE PER MONTH (0067): issuing the same month again '
      'refuses with the pinned message', (tester) async {
    final money = await seededMoney(matched: false);
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    // The seed covers the RUNNING month.
    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('This month is already invoiced for this member.'),
      findsOneWidget,
    );
    expect(money.invoices, hasLength(1));
  });

  testWidgets(
      'DETAIL SHEET: a row opens the invoice IN THE APP — its positions, '
      'its balance, its status and the payment that closed it',
      (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());
    final invoice = money.invoices.single;

    await openInvoice(tester, invoice.id);

    expect(find.byKey(const ValueKey('invoice-detail-number')),
        findsOneWidget);
    expect(find.text('Subscription 50%'), findsOneWidget,
        reason: 'reading an invoice no longer requires downloading a PDF');
    expect(find.text('Balance due'), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-detail-total')),
        findsOneWidget);
    expect(find.text('Paid'), findsNWidgets(2),
        reason: 'the same lifecycle chip on the row and in the sheet');
    expect(find.textContaining('Paid €166.00 on'), findsOneWidget,
        reason: 'the match that closed it (0067), in words');
    // Immutability holds: nothing here edits or deletes.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'FILTERED EMPTY: filters that match nothing say so — and Clear '
      'filters brings the archive back', (tester) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-2', period: '2026-07');
    for (final invoice in List.of(money.invoices)) {
      await money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId:
            money.seedPayment(invoice.memberId, invoice.totalCents),
        resolution: 'exact',
      );
    }
    await pumpInvoices(tester, money: money);

    // Ana has nothing in June.
    await tester.tap(find.byKey(const ValueKey('invoice-filter-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-filter-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('June 2026').last);
    await tester.pumpAndSettle();

    expect(find.text('No invoice matches these filters.'), findsOneWidget,
        reason: 'a filtered-empty list is not an empty archive');
    expect(find.text('No invoices yet.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('invoice-filter-clear')));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets(
      "MEMBER VIEW (0072): erroneous invoices are hidden, a partial "
      'payment reads as such, and the PDF they render is stamped a COPY',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    final money = FakeMoneyRepository();
    // One partially paid, one tagged erroneous.
    final partial = await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-05');
    await money.matchInvoice(
      invoiceId: partial,
      paymentLedgerId: money.seedPayment('member-1', 5000),
      resolution: 'under_accepted',
      note: 'Rest next month',
    );
    final wrong = await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    await money.voidInvoice(wrong);

    final shared = <Uint8List>[];
    await pumpInvoices(
      tester,
      money: money,
      workspace: workspace,
      sharer: ({required bytes, required fileName, required mimeType, text})
          async {
        shared.add(bytes);
      },
    );

    expect(find.byKey(ValueKey('invoice-$wrong')), findsNothing,
        reason: 'a cancelled invoice owes the member nothing');
    expect(find.byKey(ValueKey('invoice-$partial')), findsOneWidget);
    expect(find.text('Partially paid'), findsOneWidget);

    await openInvoice(tester, partial);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('invoice-share-$partial')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(String.fromCharCodes(shared.single.take(5)), '%PDF-');
    expect(_isWatermarked(shared.single), isTrue,
        reason: 'the member holds a COPY — the issuer keeps the original');
  });

  testWidgets(
      'a NARROW phone renders the archive row without overflowing — number, '
      'status, month, amount and the download button', (tester) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-06');
    await money.matchInvoice(
      invoiceId: money.invoices.single.id,
      paymentLedgerId:
          money.seedPayment('member-1', money.invoices.single.totalCents),
      resolution: 'exact',
    );
    await pumpInvoices(tester, money: money);
    // Shrink AFTER the pump — pumpInvoices sizes the view for the hub.
    tester.view.physicalSize = const Size(360, 780);
    await tester.pumpAndSettle();

    final invoice = money.invoices.single;
    expect(find.byKey(ValueKey('invoice-${invoice.id}')), findsOneWidget);
    expect(find.text(invoice.number), findsOneWidget,
        reason: 'the number never ellipsizes (0068 field report)');
    expect(
      find.byKey(ValueKey('invoice-download-row-${invoice.id}')),
      findsOneWidget,
    );
    // A RenderFlex overflow would have been thrown by now.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'E-INVOICE READINESS (0069): without a legal identity the export '
      'REFUSES and names what EN 16931 is missing; the owner is offered '
      'the fix', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await openInvoice(tester, money.invoices.single.id);
    await tester.tap(find.byKey(const ValueKey('invoice-einvoice-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invoice-einvoice-blocked')),
        findsOneWidget);
    expect(find.textContaining('company registration number'),
        findsOneWidget,
        reason: 'BR-CO-26 in the owner\'s words, not as a rule code');
    expect(find.byKey(const ValueKey('invoice-einvoice-download')),
        findsNothing,
        reason: 'handing out a file every validator rejects helps nobody');
    expect(find.byKey(const ValueKey('invoice-einvoice-fix-identity')),
        findsOneWidget);
  });

  testWidgets(
      'E-INVOICE ROUTING: where the domestic mandate runs on a national '
      'syntax the sheet warns instead of looking compliant (IT → SdI)',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(countryCode: 'IT');
    final money = await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: workspace,
    );

    await openInvoice(tester, money.invoices.single.id);
    await tester.tap(find.byKey(const ValueKey('invoice-einvoice-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('SdI'), findsWidgets);
    expect(find.byKey(const ValueKey('invoice-einvoice-format-warning')),
        findsOneWidget,
        reason: 'SdI takes FatturaPA — this EN 16931 file is not it');
  });
}

/// The period the fake books to when tests issue "now" — mirrors
/// currentPeriod() without importing intl here.
String currentTestPeriod() {
  final now = kTestNow;
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
