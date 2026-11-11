// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- the month is issued customer by customer, each ONCE; the
// report says what each one ended as, and a retry touches only those that
// did not end well.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/issue_invoice.dart';
import 'package:deskilo/features/money/application/issue_month.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

/// Commits, then loses the answer — for the members it is armed for.
class _Lossy extends FakeInvoiceActionCommands {
  // ignore: use_super_parameters
  _Lossy(FakeMoneyRepository repo) : super(repo);

  final Set<String> lose = {};
  final List<String> sent = [];

  @override
  Future<String> createInvoiceOnce(InvoiceIssueCommand c) async {
    sent.add('${c.memberId}:${c.requestId}');
    final id = await super.createInvoiceOnce(c);
    if (lose.contains(c.memberId)) {
      throw const JsonShapeException('rpc', 'id', 'String', 'null');
    }
    return id;
  }
}

void main() {
  late FakeMoneyRepository repo;
  late _Lossy actions;
  late InvoiceIssuance issuance;
  var counter = 0;
  String id() => 'req-${++counter}';

  void charge(String member, {String period = '2026-10'}) => repo.ledger.add(
    LedgerEntry(
      id: 'l-$member-$period',
      memberId: member,
      kind: LedgerKind.charge,
      category: LedgerCategory.service,
      amountCents: 450,
      description: 'Coffee',
      period: period,
      createdAt: DateTime(2026, 10),
    ),
  );

  setUp(() {
    counter = 0;
    repo = FakeMoneyRepository();
    actions = _Lossy(repo);
    issuance = InvoiceIssuance(repo, repo, actions);
    charge('anna');
    charge('ben');
  });

  test('every ticked customer is issued once, in the order ticked', () async {
    final progress = <String>[];
    final report = await issueMonth(
      issuance: issuance,
      workspaceId: 'ws-1',
      period: '2026-10',
      memberIds: ['ben', 'anna'],
      requestId: id,
      onProgress: (m, p) => progress.add('$m:${p.name}'),
    );
    expect(report.allIssued, isTrue);
    expect(report.outcomes.keys, ['ben', 'anna']);
    expect(repo.invoices, hasLength(2));
    expect(actions.sent, ['ben:req-1', 'anna:req-2']);
    expect(progress, ['ben:issuing', 'ben:done', 'anna:issuing', 'anna:done']);
    expect(report.invoiceOf('ben'), isNotNull);
  });

  test(
    'a customer whose answer was lost is looked up, not sent again',
    () async {
      actions.lose.add('anna');
      final report = await issueMonth(
        issuance: issuance,
        workspaceId: 'ws-1',
        period: '2026-10',
        memberIds: ['anna', 'ben'],
        requestId: id,
      );
      expect(
        report.allIssued,
        isTrue,
        reason: 'the receipt shows it was committed',
      );
      expect(actions.sent, hasLength(2), reason: 'one send each, no resend');
      expect(repo.invoices, hasLength(2));
    },
  );

  test('a refusal is reported with the others untouched, and the retry '
      'sends only that customer, under a new id', () async {
    // Anna was invoiced for October already: the server refuses her alone.
    await issueMonth(
      issuance: issuance,
      workspaceId: 'ws-1',
      period: '2026-10',
      memberIds: ['anna'],
      requestId: id,
    );
    final report = await issueMonth(
      issuance: issuance,
      workspaceId: 'ws-1',
      period: '2026-10',
      memberIds: ['anna', 'ben'],
      requestId: id,
    );
    expect(report.issued, ['ben']);
    expect(report.refused, ['anna']);
    expect(report.notDone, ['anna']);
    expect(report.allIssued, isFalse);
    final before = List.of(actions.sent);
    final retried = await retryNotDone(
      issuance: issuance,
      report: report,
      requestId: id,
    );
    expect(actions.sent.length, before.length + 1, reason: 'only anna again');
    expect(actions.sent.last, startsWith('anna:req-'));
    expect(retried.issued, ['ben'], reason: 'ben stays as he was');
    expect(repo.invoices, hasLength(2));
  });

  test('an empty selection issues nothing and is not "all issued"', () async {
    final report = await issueMonth(
      issuance: issuance,
      workspaceId: 'ws-1',
      period: '2026-10',
      memberIds: const [],
      requestId: id,
    );
    expect(report.outcomes, isEmpty);
    expect(report.allIssued, isFalse);
    expect(actions.sent, isEmpty);
  });
}
