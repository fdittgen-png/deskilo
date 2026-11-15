// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the invoices screen (with its seeded money) pump, moved out of `test/features/money/invoices_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/credit_move.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // #3349 — a test of the credit move brings its own.
  CreditMoveRepository? creditMoves,
  // #3680 — a test of a failed source brings its override.
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
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
          creditMoves: creditMoves,
        ),
        if (saver != null) ...[
          fileSaverProvider.overrideWithValue(saver),
          typedFileSaverProvider.overrideWithValue(typedSaverOf(saver)),
        ],
        if (picker != null) filePickerProvider.overrideWithValue(picker),
        ...overrides,
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // #1246 — by icon, not by the English label (see navigation.dart).
  await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
  await tester.pumpAndSettle();
  // #720 — the register lives on the Invoices face.
  await tester.ensureVisible(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  await openMoneyWorkspaceTools(tester);
  // #1339 — on a short viewport the button is below the fold and not
  // built, so `ensureVisible` alone threw "Bad state: No element".
  //
  // The scrollable is named explicitly. Left to its default finder,
  // `scrollUntilVisible` takes THE Scrollable and throws "Bad state: Too
  // many elements" as soon as the screen holds a second one — which it
  // does whenever an empty state is on it, since that block scrolls too
  // rather than overflow at large text.
  await scrollInMoneyFace(tester, find.byKey(const ValueKey('invoices-button')));
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  // The scroll lands on the next frame: tapping before it taps where the
  // button was (#4037).
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
  // #3587 — issuers land on the invoicing home (its own tests drive it);
  // members land on their archive. Nothing to tap here.
  return money;
}

/// #3587 — the invoicing home's list, one line per invoice (the home
/// opens by customer). A no-op once already by invoice.
/// #4059 — what the invoicing home sums up about what is owed: the debt
/// card at desk width, the summary strip below it.
final Finder invoicingOwedFigures = find.byWidgetPredicate(
  (w) =>
      w.key == const ValueKey('invoicing-owed') ||
      w.key == const ValueKey('invoicing-summary'),
);

/// #4059 — whether the invoicing home counts something in [bucket]
/// (`notYetDue`, `toConfirm`, `overdue`): at desk width the debt card's
/// legend line; below it the summary strip's counts (not yet due is the
/// amount due less what is to confirm or overdue).
bool owedBucketShown(WidgetTester tester, String bucket) {
  final legend = find.byWidgetPredicate((w) {
    final key = w.key;
    return key is ValueKey<String> &&
        key.value.startsWith('invoicing-owed-') &&
        key.value.endsWith('-$bucket');
  });
  if (find.byKey(const ValueKey('invoicing-owed')).evaluate().isNotEmpty) {
    return legend.evaluate().isNotEmpty;
  }
  int count(String cell) {
    for (final e in find
        .byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'invoicing-summary-$cell-count-',
            ))
        .evaluate()) {
      final key = (e.widget.key! as ValueKey<String>).value;
      return int.parse(key.substring(key.lastIndexOf('-') + 1));
    }
    return 0;
  }

  return switch (bucket) {
    'toConfirm' => count('confirm') > 0,
    'overdue' => count('overdue') > 0,
    _ => count('due') - count('confirm') - count('overdue') > 0,
  };
}

/// #4059 — below desk width the to-do list sits under the invoicing home's
/// summary strip and opens from its To do cell; at desk width it is always
/// shown, and this does nothing. Call it where a case needs the open to-do.
Future<void> openInvoicingTodo(WidgetTester tester) async {
  final cell = find.byKey(const ValueKey('invoicing-summary-review'));
  if (cell.evaluate().isEmpty) return;
  if (find.byKey(const ValueKey('invoicing-todo')).evaluate().isNotEmpty) {
    return;
  }
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

Future<void> showInvoicesByInvoice(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('invoicing-view'));
  if (toggle.evaluate().isEmpty) return;
  await tester.tap(
    find.descendant(of: toggle, matching: find.text('Invoices')),
  );
  await tester.pumpAndSettle();
}

/// #3587 — the invoicing home's paid and closed invoices (the archive the
/// old hub had as a tab): the Paid filter chip.
Future<void> showPaidInvoices(WidgetTester tester) async {
  // #3614 — at the desk, by invoice, the records table's chip.
  final listChip = find.byKey(const ValueKey('invoicing-filter-paid'));
  final chip = listChip.evaluate().isNotEmpty
      ? listChip
      : find.byKey(const ValueKey('records-chip-paid'));
  // A search for a line may have scrolled the chips out of view.
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// The home's line of [invoiceId] brought into view, from whichever list
/// holds it: the open invoices by invoice, else the paid and closed ones.
Future<Finder> invoicingRow(WidgetTester tester, String invoiceId) async {
  // #3614 — a line of the list, or a row of the desk's records table.
  final row = find.byWidgetPredicate(
    (w) =>
        w.key == ValueKey('invoicing-row-$invoiceId') ||
        w.key == ValueKey('records-row-$invoiceId'),
  );
  final home = find.byKey(const ValueKey('invoicing-home'));
  final table = find.byKey(const ValueKey('records-rows'));
  Future<bool> reach() async {
    if (row.evaluate().isNotEmpty) return true;
    try {
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find
            .descendant(
              of: table.evaluate().isNotEmpty ? table : home,
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 30,
      );
      return true;
    } on StateError {
      return false;
    }
  }

  await showInvoicesByInvoice(tester);
  if (!await reach()) {
    await showPaidInvoices(tester);
    await reach();
  }
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  return row;
}

/// Opens an invoice. An issuer reaches its PAGE from the invoicing home's
/// line (#3587 R1-d, #3773: a panel beside the list where both fit,
/// `invoiceFitsBeside`, full screen otherwise); a member opens its DETAIL
/// sheet from their archive's row.
Future<void> openInvoice(WidgetTester tester, String invoiceId) async {
  // The home may be under an invoice page (offstage): it is still there.
  if (find
      .byKey(const ValueKey('invoicing-home'), skipOffstage: false)
      .evaluate()
      .isNotEmpty) {
    await closeInvoicePage(tester);
    await tester.tap(await invoicingRow(tester, invoiceId));
  } else {
    await tester.tap(find.byKey(ValueKey('invoice-$invoiceId')));
  }
  await tester.pumpAndSettle();
}

/// #3587 R1-d — the events of a payment of [amountCents] registered
/// (confirmed) for [memberId] after the invoice was issued: what makes the
/// invoice page offer "Match the payment" (`invoice-page-match`).
FakeEventRepository registeredPayment(String memberId, int amountCents) =>
    FakeEventRepository()
      ..events.add(
        WorkspaceEvent(
          id: 'payment-$memberId-$amountCents',
          workspaceId: 'ws-1',
          type: EventType.payment,
          action: EventAction.created,
          actorMemberId: 'owner-1',
          subjectMemberId: memberId,
          payload: {'amount_cents': amountCents},
          status: EventStatus.confirmed,
          createdAt: kTestNow.add(const Duration(hours: 1)),
        ),
      );

/// #3587 R1-d — closes an invoice page opened full screen; a no-op when
/// none is open.
Future<void> closeInvoicePage(WidgetTester tester) async {
  // #3607 — the invoice is a page at its address (or the pane beside the
  // list on a large window); a page opened from inside another page is
  // still a dialog. Its own close button closes it wherever it stands.
  final close = find.byKey(const ValueKey('invoice-page-close'));
  final back = find.descendant(
    of: find.byType(InvoicePage),
    matching: find.byType(BackButton),
  );
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.last);
  } else if (back.evaluate().isNotEmpty) {
    await tester.tap(back.last);
  } else {
    return;
  }
  await tester.pumpAndSettle();
}

/// #3587 R1-d — opens the invoice page's More menu (the document, the
/// reminders, the corrections).
Future<void> openInvoicePageMore(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('invoice-page-more')));
  await tester.pumpAndSettle();
}

/// #3587 R1-d — runs the invoice page's More entry [key]
/// (`invoice-more-download`, `invoice-more-hold`, …).
Future<void> invoicePageMore(WidgetTester tester, String key) async {
  await openInvoicePageMore(tester);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// The period the fake books to when tests issue "now" — mirrors
/// currentPeriod() without importing intl here.
String currentTestPeriod() {
  final now = kTestNow;
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
