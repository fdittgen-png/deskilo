// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the invoices screen (with its seeded money) pump, moved out of `test/features/money/invoices_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_event_repository.dart';
import '../fake_money_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

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
  // #1339 — the responsive matrix asks for a narrow surface. Every
  // other caller keeps the tall one this file has always used, so
  // nothing existing changes.
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
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
  // #1246 — by icon, not by the English label (see navigation.dart).
  await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
  await tester.pumpAndSettle();
  // #720 — the register lives on the Invoices face.
  await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  // #1339 — on a short viewport the button is below the fold and not
  // built, so `ensureVisible` alone threw "Bad state: No element".
  //
  // The scrollable is named explicitly. Left to its default finder,
  // `scrollUntilVisible` takes THE Scrollable and throws "Bad state: Too
  // many elements" as soon as the screen holds a second one — which it
  // does whenever an empty state is on it, since that block scrolls too
  // rather than overflow at large text.
  await tester.scrollUntilVisible(
      find.byKey(const ValueKey('invoices-button')), 200,
      scrollable: find.byType(Scrollable).first);
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

/// Opens an archive row's DETAIL sheet — since the invoicing UX pass,
/// reading an invoice and acting on it both live there instead of in a row
/// of icon buttons and an overflow menu.
Future<void> openInvoice(WidgetTester tester, String invoiceId) async {
  await tester.tap(find.byKey(ValueKey('invoice-$invoiceId')));
  await tester.pumpAndSettle();
}

/// The period the fake books to when tests issue "now" — mirrors
/// currentPeriod() without importing intl here.
String currentTestPeriod() {
  final now = kTestNow;
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
