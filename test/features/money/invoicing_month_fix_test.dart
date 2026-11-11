// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 release 1 -- the month's flow opened from the invoicing home: a
// customer who needs a fix is said apart with its Fix; Fix opens the
// customer's page through the app's router, and on return the flow reads
// the customer again, so a completed customer can be issued.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/invoices.dart';

/// The money fake whose dry run says what the test set.
class _Repo extends FakeMoneyRepository {
  final Map<String, List<String>> missing = {};

  @override
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async => missing[memberId] ?? const [];
}

void main() {
  testWidgets('from To do: Fix opens the customer, and on return the row is '
      'free to issue', (tester) async {
    final money = _Repo()..missing['member-1'] = ['buyer_address'];
    await pumpInvoices(tester, money: money);

    final entry = find.byKey(const ValueKey('invoicing-todo-invoiceTheMonth'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    final fix = find.byKey(const ValueKey('invoice-month-fix-member-1'));
    expect(fix, findsOneWidget, reason: 'the customer needs a fix');
    // The details are completed while the person is on the customer's page.
    money.missing.clear();
    await tester.tap(fix);
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));
    expect(
      router.routeInformationProvider.value.uri.path,
      isNot('/invoices'),
      reason: 'Fix leaves for the place where the customer is completed',
    );
    router.pop();
    await tester.pumpAndSettle();

    expect(fix, findsNothing, reason: 'read again on return: nothing to fix');
    await tester.tap(find.byKey(const ValueKey('invoice-month-issue')));
    await tester.pumpAndSettle();
    expect(money.invoices.single.memberId, 'member-1');
  });
}
