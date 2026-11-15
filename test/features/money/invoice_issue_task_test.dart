// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4058 — issuing an invoice is a task: a side task at the desk, a sheet on
// a phone. Its button names the amount the preview totals and is pressed
// only on a preview that was read; one line under it says the issued
// invoice is kept as an original that cannot be changed. A resize keeps the
// member and the month.
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/invoices.dart';

/// A preview that answers only when [answer] is completed.
class _SlowPreview extends FakeMoneyRepository {
  final answer = Completer<void>();

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async {
    await answer.future;
    return super.previewInvoice(
      workspaceId: workspaceId,
      memberId: memberId,
      period: period,
    );
  }
}

final _submit = find.byKey(const ValueKey('invoice-submit'));

Future<void> _open(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('invoicing-new'));
  await tester.ensureVisible(open);
  await tester.tap(open);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

String _label(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: _submit, matching: find.byType(Text)))
    .data!;

void main() {
  for (final (size, container) in const [
    (Size(1440, 900), 'task-side-panel'),
    (Size(390, 844), 'task-sheet'),
  ]) {
    testWidgets('at ${size.width.toInt()} the form is a $container; the '
        'button names the amount and the original is said', (tester) async {
      await pumpInvoices(tester, size: size);
      await _open(tester);
      expect(find.byKey(ValueKey(container)), findsOneWidget);
      await _pick(tester, 'Flo');

      final total = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('invoice-preview-total')),
              matching: find.byType(Text),
            ),
          )
          .last
          .data!;
      expect(_label(tester), 'Issue invoice · $total');
      expect(
        find.byKey(const ValueKey('invoice-issue-original')),
        findsOneWidget,
      );
      expect(
        find.textContaining('cannot be changed'),
        findsOneWidget,
        reason: 'what issuing means, before it is done',
      );
    });
  }

  testWidgets('while the preview is read, Issue is disabled and names no '
      'amount', (tester) async {
    final money = _SlowPreview();
    await pumpInvoices(tester, money: money, size: const Size(1440, 900));
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pump();
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
    expect(_label(tester), 'Issue invoice');
    money.answer.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
  });

  testWidgets('a resize keeps the member and the month', (tester) async {
    await pumpInvoices(tester, size: const Size(1440, 900));
    await _open(tester);
    await _pick(tester, 'Flo');
    await tester.tap(find.byKey(const ValueKey('invoice-period-prev')));
    await tester.pumpAndSettle();
    final month = tester
        .widget<Text>(find.byKey(const ValueKey('invoice-period-label')))
        .data;

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-sheet')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('invoice-period-label')))
          .data,
      month,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invoice-member-dropdown')),
        matching: find.text('Flo'),
      ),
      findsOneWidget,
    );
  });
}
