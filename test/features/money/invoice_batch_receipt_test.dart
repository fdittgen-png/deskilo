// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 C2 — the batch issue (wizard / sweep) and the settlement carry a
// request id per constituent. A constituent that committed and lost its
// answer is recovered by its own id; "issue again" with that id replays it,
// it neither fails on "already invoiced" nor issues a second document.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/issue_invoice.dart';
import 'package:deskilo/features/money/application/settle_invoices.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

/// Commits, then loses the answer — once per armed call.
class _Lossy extends FakeInvoiceActionCommands {
  // ignore: use_super_parameters
  _Lossy(FakeMoneyRepository repo) : super(repo);

  bool lose = true;
  int sends = 0;

  Never _lost() =>
      throw const JsonShapeException('rpc', 'id', 'String', 'null');

  @override
  Future<String> createInvoiceOnce(InvoiceIssueCommand c) async {
    sends++;
    await super.createInvoiceOnce(c);
    if (lose) _lost();
    return super.createInvoiceOnce(c);
  }

  @override
  Future<String> settleInvoicesOnce({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    required String requestId,
    String note = '',
  }) async {
    sends++;
    final id = await super.settleInvoicesOnce(
      workspaceId: workspaceId,
      memberId: memberId,
      invoiceIds: invoiceIds,
      requestId: requestId,
      note: note,
    );
    if (lose) _lost();
    return id;
  }
}

void main() {
  late FakeMoneyRepository repo;
  late _Lossy actions;
  late InvoiceIssuance issuance;

  void charge(String period) => repo.ledger.add(
    LedgerEntry(
      id: 'l-$period',
      memberId: 'member-1',
      kind: LedgerKind.charge,
      category: LedgerCategory.service,
      amountCents: 450,
      description: 'Coffee',
      period: period,
      createdAt: DateTime(2026, 9),
    ),
  );

  InvoiceIssueAttempt attempt(String id, {String period = '2026-09'}) =>
      InvoiceIssueAttempt(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: period,
        requestId: id,
        direct: true,
      );

  setUp(() {
    repo = FakeMoneyRepository();
    charge('2026-09');
    charge('2026-08');
    actions = _Lossy(repo);
    issuance = InvoiceIssuance(repo, repo, actions);
  });

  group('batch issue', () {
    test('a lost answer is recovered by the constituent\'s id', () async {
      final out = await issuance.issue(attempt('m1'));
      expect(out, isA<InvoiceIssueUnknown>());
      final found = await issuance.look(out as InvoiceIssueUnknown);
      expect(found, isA<InvoiceIssued>());
      expect((found as InvoiceIssued).invoiceId, repo.invoices.single.id);
    });

    test(
      'issuing again with the SAME id replays; no second invoice, no refusal',
      () async {
        actions.lose = false;
        final first = await issuance.issue(attempt('m1')) as InvoiceIssued;
        final again = await issuance.issue(attempt('m1')) as InvoiceIssued;
        expect(again.invoiceId, first.invoiceId);
        expect(repo.invoices, hasLength(1));
      },
    );

    test('a NEW id for an invoiced month is the server\'s refusal, nothing recovered', () async {
      actions.lose = false;
      await issuance.issue(attempt('m1'));
      final second = await issuance.issue(attempt('m2'));
      expect(second, isA<InvoiceIssueRefused>());
      expect(repo.invoices, hasLength(1));
    });

    test('each member of the batch recovers its own invoice', () async {
      final a = await issuance.issue(attempt('a'));
      final b = await issuance.issue(attempt('b', period: '2026-08'));
      final ia = await issuance.look(a as InvoiceIssueUnknown) as InvoiceIssued;
      final ib = await issuance.look(b as InvoiceIssueUnknown) as InvoiceIssued;
      expect(ia.invoiceId, isNot(ib.invoiceId));
      expect(repo.invoices, hasLength(2));
    });
  });

  group('settlement', () {
    late Settlements settlements;
    late SettleAttempt settle;

    setUp(() async {
      actions.lose = false;
      await issuance.issue(attempt('a'));
      await issuance.issue(attempt('b', period: '2026-08'));
      actions.lose = true;
      settlements = Settlements(actions, repo);
      settle = SettleAttempt(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        invoiceIds: [for (final i in repo.invoices) i.id],
        requestId: 'settle-1',
      );
    });

    test(
      'a lost answer is recovered with the settlement\'s own number',
      () async {
        final out = await settlements.settle(settle);
        expect(out, isA<SettleUnknown>());
        final found = await settlements.look(out as SettleUnknown);
        expect(found, isA<Settled>());
        final number = (found as Settled).number;
        expect(repo.invoices.where((i) => i.number == number), hasLength(1));
      },
    );

    test(
      'a request that never committed stays unknown after every look',
      () async {
        final unknown = SettleUnknown(settle, StateError('lost'));
      final before = actions.sends;
        for (var i = 0; i < 3; i++) {
          expect(await settlements.look(unknown), isA<SettleUnknown>());
        }
        expect(actions.sends, before);
      },
    );
  });
}
