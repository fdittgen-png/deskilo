// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A decision still pending is not an issued invoice, and an answer that is
// lost after the commit is retried under the SAME request id, so the retry
// returns the invoice already made instead of making a second one.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:deskilo/features/money/application/issue_invoice.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/invoices.dart';

/// A validation policy holds the issue request.
class _Held extends FakeMoneyRepository {
  int writes = 0;

  @override
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command) async {
    writes++;
    throw const PendingValidationException('evt-1');
  }
}

/// The server commits under the request id, the first answer is malformed.
class _LostOnce extends FakeMoneyRepository {
  final sentIds = <String>[];

  @override
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command) async {
    sentIds.add(command.requestId);
    final id = await super.issueInvoiceWithReceipt(command);
    if (sentIds.length == 1) {
      throw const JsonShapeException(
        'request_invoice_issue_v1',
        'invoice_id',
        'String',
        'null',
      );
    }
    return id;
  }
}

void main() {
  testWidgets('a pending decision is sent for validation, not issued: no '
      'success notice, one write, no invoice', (tester) async {
    final money = _Held();
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sent for validation'), findsOneWidget);
    expect(find.text('Invoice issued.'), findsNothing);
    expect(money.writes, 1);
    expect(money.invoices, isEmpty);
  });

  test(
    'a malformed answer after the commit is unknown, and sending the '
    'retained attempt again reuses its request id and the same invoice',
    () async {
      final money = _LostOnce();
      final issuance = InvoiceIssuance(money, money);
      const attempt = InvoiceIssueAttempt(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-09',
        requestId: 'req-retry',
      );

      final first = await issuance.issue(attempt);
      expect(first, isA<InvoiceIssueUnknown>(), reason: 'not a success');
      expect(money.invoices, hasLength(1), reason: 'the commit happened');

      final again = await issuance.issue(first.attempt);
      expect(again, isA<InvoiceIssued>());
      expect(money.sentIds, ['req-retry', 'req-retry']);
      expect(
        (again as InvoiceIssued).invoiceId,
        money.invoices.single.id,
        reason: 'the retry returns the invoice already made',
      );
      expect(money.invoices, hasLength(1), reason: 'never a second invoice');
    },
  );
}
