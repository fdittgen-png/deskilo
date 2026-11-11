// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- money received and not assigned is ONE answer: one definition
// of a consumed payment (the matches, every payment of an aggregate match,
// the credits moved away), one read of the workspace's ledger, and one rule
// of who holds money, from which the home's count and Payments to match both
// come.

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/application/unassigned_money.dart';
import 'package:deskilo/features/money/domain/credit_move.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/providers/credit_move_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry _pay(
  String id, {
  String member = 'anna',
  int cents = 12000,
  String period = '2026-03',
}) => LedgerEntry(
  id: id,
  memberId: member,
  kind: LedgerKind.credit,
  category: LedgerCategory.payment,
  amountCents: cents,
  description: 'Transfer',
  period: period,
  createdAt: DateTime(2026, 3, 20),
  occurredOn: DateTime(2026, 3, 18),
);

Receivable _inv(
  String id, {
  String customer = 'anna',
  int open = 12000,
  String currency = 'EUR',
}) => Receivable(
  invoiceId: id,
  customerId: customer,
  customerName: customer,
  number: 'INV-$id',
  currency: currency,
  totalMinor: open,
  openMinor: open,
  issuedOn: DateTime(2026, 5),
  stage: ReceivableStage.open,
);

/// The ledger, the junction and the moved credits as the server holds them;
/// it counts every ledger read.
class _Repo extends FakeMoneyRepository {
  int workspaceReads = 0;
  int memberReads = 0;
  Set<String> junction = {};

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async {
    workspaceReads++;
    return List.of(ledger);
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async {
    memberReads++;
    return [
      for (final e in ledger)
        if (e.memberId == memberId) e,
    ];
  }

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async =>
      junction;
}

class _Moves implements CreditMoveRepository {
  Set<String> moved = {};

  @override
  Future<Set<String>> fetchMovedCreditIds(String workspaceId) async => moved;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repo repo;
  late _Moves moves;

  setUp(() {
    repo = _Repo();
    moves = _Moves();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        invoicesProvider.overrideWith((ref) async => const <Invoice>[]),
        invoiceMatchesProvider.overrideWith(
          (ref) async => const <String, InvoiceMatch>{},
        ),
        invoiceRemindersProvider.overrideWith(
          (ref) async => const <String, ({int count, DateTime last})>{},
        ),
        invoicingBusinessProvider.overrideWith(
          (ref) => (
            id: 'ws-1',
            currency: 'EUR',
            country: 'FR',
            dayOf: (DateTime d) => DateTime(d.year, d.month, d.day),
          ),
        ),
        invoiceQueriesProvider.overrideWithValue(repo),
        memberAccountQueriesProvider.overrideWithValue(repo),
        creditMoveRepositoryProvider.overrideWithValue(moves),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<UnassignedMoney> read(ProviderContainer c) {
    c.listen(unassignedMoneyProvider, (_, _) {});
    return c.read(unassignedMoneyProvider.future);
  }

  test('a payment of an aggregate match and a credit moved away are not '
      'money received and not assigned', () async {
    repo.ledger.addAll([
      _pay('aggregate'),
      _pay('moved'),
      _pay('free', member: 'ben'),
    ]);
    repo.junction = {'aggregate'};
    moves.moved = {'moved'};
    final money = await read(container());
    final receivables = [_inv('a1'), _inv('b1', customer: 'ben')];
    expect(money.paymentsOf.keys, ['ben']);
    expect(money.creditOf('anna'), {'EUR': 0}, reason: 'read, and zero');
    expect(money.holdersAmong(receivables), {'ben'});
  });

  test('one read of the workspace ledger for fifty customers, and a '
      'reminder or a hold read since changes nothing here', () async {
    for (var i = 0; i < 50; i++) {
      repo.ledger.add(_pay('p$i', member: 'c$i'));
    }
    final c = container();
    final money = await read(c);
    expect(money.paymentsOf, hasLength(50));
    expect(repo.workspaceReads, 1);
    expect(repo.memberReads, 0, reason: 'never one read per customer');

    c.invalidate(invoiceRemindersProvider);
    await c.read(invoiceRemindersProvider.future);
    await c.read(unassignedMoneyProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(repo.workspaceReads, 1, reason: 'a reminder reads nothing again');
  });

  test('a prepayment from before the invoice is in Payments to match, and '
      'the home counts exactly what the list shows', () {
    final money = UnassignedMoney(
      currency: 'EUR',
      paymentsOf: {
        'anna': [_pay('prepaid')],
        'ben': [_pay('credit', member: 'ben', cents: 3000)],
      },
    );
    // No confirmed payment event after the invoice: the old event-based
    // flag is false; the ledger still holds Anna's money.
    final receivables = [
      _inv('a1'),
      _inv('b1', customer: 'ben', open: 5000),
      _inv('c1', customer: 'cleo'),
    ];
    final rows = money.toMatch(receivables);
    final holders = money.holdersAmong(receivables);
    expect(rows.map((r) => r.payment.id), ['prepaid', 'credit']);
    expect({for (final r in rows) r.customerId}, holders);
    final matchCount = todoOf(
      receivables,
      mode: ReminderMode.byHand,
      holdsUnassigned: holders,
    ).firstWhere((t) => t.kind == TodoKind.matchPayments).tally.count;
    expect(matchCount, rows.length, reason: 'count = list length');
  });

  test('an invoice in another currency than the business never changes the '
      'payment\'s currency and is not offered', () {
    final money = UnassignedMoney(
      currency: 'EUR',
      paymentsOf: {
        'anna': [_pay('p1')],
      },
    );
    final rows = money.toMatch([_inv('eur'), _inv('usd', currency: 'USD')]);
    expect(rows.single.candidates.map((c) => c.invoice.invoiceId), ['eur']);
    expect(
      money.holdersAmong([_inv('usd', currency: 'USD')]),
      isEmpty,
      reason: 'money in EUR is not held against a USD invoice',
    );
  });
}
