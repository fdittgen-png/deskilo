// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3773 — a state in the invoice table is never cut. Its parts (the lateness,
// then the reminder) are pieces that wrap between each other: one line when
// both fit, two when not, and the row grows. At the list's minimum width, in
// the five languages, the longest Demo state ("5 days late · reminder 1
// sent") is whole, read by the chip's own text, not by a width guess. The
// other cells stay level with the first line, the whole row opens the
// invoice, and the phone list keeps its one chip.
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _today = DateTime(2026, 5, 13);

/// Five days late, reminder 1 sent: the Demo's longest state.
final _late = Receivable(
  invoiceId: 'inv-1',
  customerId: 'c-1',
  customerName: 'Bruno Kessler',
  number: 'F-2026-0402',
  currency: 'EUR',
  totalMinor: 10080,
  openMinor: 10080,
  issuedOn: DateTime(2026, 4, 24),
  dueOn: DateTime(2026, 5, 8),
  stage: ReceivableStage.open,
  remindersSent: 1,
);

Future<List<String>> _opened(
  WidgetTester tester, {
  required Locale locale,
  required bool wide,
  double width = kInvoicingListMinWidth,
}) async {
  final opened = <String>[];
  await pumpApp(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: InvoicingHome(
            wide: wide,
            data: InvoicingHomeData(
              receivables: [_late],
              today: _today,
              month: 'May',
              currency: 'EUR',
              mode: ReminderMode.byHand,
            ),
            actions: InvoicingHomeActions(
              onOpenInvoice: opened.add,
              onOpenCustomer: (_) {},
              onCustomerAction: (_, _) {},
              onTodo: (_) {},
              onRetry: (_) {},
              onNewInvoice: () {},
            ),
          ),
        ),
      ),
    ),
    locale: locale,
    size: const Size(1600, 3000),
  );
  await tester.pumpAndSettle();
  final l = lookupAppLocalizations(locale);
  // The invoices view, not the customers'.
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('invoicing-view')),
      matching: find.text(l.featureInvoicing),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  for (final code in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('at the list\'s minimum width the longest state is whole, '
        'in its two parts ($code)', (tester) async {
      final locale = Locale(code);
      final l = lookupAppLocalizations(locale);
      await _opened(tester, locale: locale, wide: true);
      final cell = find.byKey(const ValueKey('invoicing-state-inv-1'));
      expect(cell, findsOneWidget);
      final chips = tester
          .widgetList<StatusChip>(
            find.descendant(of: cell, matching: find.byType(StatusChip)),
          )
          .toList();
      expect(
        [for (final c in chips) c.label],
        [l.invoicingDaysLate(5), l.invoicingReminderLevelSent(1)],
      );
      for (final c in chips) {
        expect(c.whole, isTrue);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.byWidget(c), matching: find.text(c.label)),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: c.label);
        expect(paragraph.text.toPlainText(), c.label);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a two-line state keeps the other cells level with its first '
      'line, and the whole row opens the invoice', (tester) async {
    // #3614 — at the list's minimum the desk table's state column is
    // narrow enough that the two parts cannot share a line.
    final opened = await _opened(
      tester,
      locale: const Locale('de'),
      wide: true,
    );
    final cell = find.byKey(const ValueKey('invoicing-state-inv-1'));
    final chips = find.descendant(of: cell, matching: find.byType(StatusChip));
    final first = tester.getRect(chips.first);
    final second = tester.getRect(chips.last);
    expect(second.top, greaterThan(first.top), reason: 'two lines');
    final name = tester.getRect(find.text('Bruno Kessler'));
    final number = tester.getRect(find.text('F-2026-0402'));
    // On the first line, not centred on the grown row (#3614: the desk
    // table centres every cell in the row's first line).
    for (final cell in [name, number]) {
      expect(cell.center.dy, inInclusiveRange(first.top, first.bottom));
      expect(cell.center.dy, lessThan(second.top));
    }
    // A tap under the name, on the row's second line, still opens it.
    final row = tester.getRect(
      find.byKey(const ValueKey('records-row-inv-1')),
    );
    await tester.tapAt(Offset(name.left, second.center.dy));
    await tester.pumpAndSettle();
    expect(opened, ['inv-1']);
    expect(row.height, greaterThanOrEqualTo(second.bottom - first.top));
  });

  testWidgets('the phone list is unchanged: one chip with the whole state', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await _opened(tester, locale: const Locale('en'), wide: false, width: 390);
    expect(find.byKey(const ValueKey('invoicing-state-inv-1')), findsNothing);
    final chip = tester.widget<StatusChip>(
      find.descendant(
        of: find.byKey(const ValueKey('invoicing-row-inv-1')),
        matching: find.byType(StatusChip),
      ),
    );
    expect(chip.label, l.invoicingStatusReminderSent(5, 1));
    expect(chip.whole, isFalse);
  });
}
