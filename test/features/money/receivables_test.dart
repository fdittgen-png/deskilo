// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 step 1 — the owner's invoicing read models: every status, the one
// action per status, the four figures, "Do next" and its order, customer
// balances, and two currencies never summed.
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:flutter_test/flutter_test.dart';

/// The business's calendar day the tests are read on.
final _today = DateTime(2026, 11, 10);

Receivable _r({
  String id = 'i1',
  String customer = 'c1',
  String name = 'Ada',
  String currency = 'EUR',
  int total = 10000,
  int open = 10000,
  ReceivableStage stage = ReceivableStage.open,
  DateTime? issued,
  DateTime? due,
  bool noDue = false,
  bool declared = false,
  bool hold = false,
  bool failed = false,
  int sent = 0,
  int? dueLevel,
  DateTime? paidOn,
}) => Receivable(
  invoiceId: id,
  customerId: customer,
  customerName: name,
  number: stage == ReceivableStage.draft ? '' : 'F-$id',
  currency: currency,
  totalMinor: total,
  openMinor: open,
  issuedOn: issued ?? DateTime(2026, 10),
  dueOn: stage == ReceivableStage.draft || noDue
      ? null
      : (due ?? DateTime(2026, 11, 20)),
  stage: stage,
  paymentDeclared: declared,
  onHold: hold,
  sendFailed: failed,
  remindersSent: sent,
  reminderDueLevel: dueLevel,
  paidOn: paidOn,
);

InvoiceStatus _status(Receivable r) => invoiceStatusOf(r, _today);

void main() {
  group('status in words', () {
    test('ended invoices say how they ended', () {
      expect(
        _status(_r(stage: ReceivableStage.draft)).kind,
        InvoiceStatusKind.draft,
      );
      expect(
        _status(_r(stage: ReceivableStage.paid, open: 0)).kind,
        InvoiceStatusKind.paid,
      );
      expect(
        _status(_r(stage: ReceivableStage.cancelled)).kind,
        InvoiceStatusKind.cancelled,
      );
      expect(
        _status(_r(stage: ReceivableStage.credited)).kind,
        InvoiceStatusKind.credited,
      );
    });

    test('the calendar: due in n days, due today, n days late', () {
      expect(
        _status(_r(due: DateTime(2026, 11, 13))),
        const InvoiceStatus(InvoiceStatusKind.dueIn, 3),
      );
      // #3285: the due day itself is late — "due today" is the only
      // sentence that names it.
      expect(
        _status(_r(due: DateTime(2026, 11, 10))),
        const InvoiceStatus(InvoiceStatusKind.dueToday),
      );
      expect(
        _status(_r(due: DateTime(2026, 11, 2))),
        const InvoiceStatus(InvoiceStatusKind.late, 8),
      );
    });

    test('what waits on the business comes before the calendar', () {
      final late = DateTime(2026, 11, 2);
      expect(
        _status(_r(due: late, dueLevel: 2)),
        const InvoiceStatus(InvoiceStatusKind.reminderDue, 2),
      );
      expect(
        _status(_r(due: late, sent: 1)),
        const InvoiceStatus(InvoiceStatusKind.reminderSent, 1),
      );
      expect(
        _status(_r(due: late, declared: true, dueLevel: 2)).kind,
        InvoiceStatusKind.paymentDeclared,
      );
      expect(
        _status(_r(due: late, failed: true, declared: true)).kind,
        InvoiceStatusKind.couldNotBeSent,
      );
      expect(
        _status(_r(due: late, hold: true, failed: true)).kind,
        InvoiceStatusKind.onHold,
      );
    });

    test('a part paid, not yet late, says so; once late it is late', () {
      expect(
        _status(_r(stage: ReceivableStage.partlyPaid, open: 4000)).kind,
        InvoiceStatusKind.partlyPaid,
      );
      expect(
        _status(
          _r(
            stage: ReceivableStage.partlyPaid,
            open: 4000,
            due: DateTime(2026, 11),
          ),
        ),
        const InvoiceStatus(InvoiceStatusKind.late, 9),
      );
    });
  });

  test('an invoice without a due date is never late: it awaits payment', () {
    final r = _r(noDue: true);
    expect(_status(r).kind, InvoiceStatusKind.noDueDate);
    expect(actionFor(_status(r)), InvoiceAction.open);
    final f = figuresOf([r], today: _today);
    expect(f.awaitingPayment, const Tally(1, {'EUR': 10000}));
    expect(f.overdue, Tally.empty);
  });

  test('one action per status', () {
    expect(
      actionFor(const InvoiceStatus(InvoiceStatusKind.draft)),
      InvoiceAction.issue,
    );
    expect(
      actionFor(const InvoiceStatus(InvoiceStatusKind.reminderDue, 1)),
      InvoiceAction.sendReminder,
    );
    expect(
      actionFor(const InvoiceStatus(InvoiceStatusKind.paymentDeclared)),
      InvoiceAction.confirmPayment,
    );
    expect(
      actionFor(const InvoiceStatus(InvoiceStatusKind.couldNotBeSent)),
      InvoiceAction.fix,
    );
    for (final k in [
      InvoiceStatusKind.dueIn,
      InvoiceStatusKind.dueToday,
      InvoiceStatusKind.late,
      InvoiceStatusKind.reminderSent,
      InvoiceStatusKind.partlyPaid,
      InvoiceStatusKind.paid,
      InvoiceStatusKind.onHold,
      InvoiceStatusKind.cancelled,
      InvoiceStatusKind.credited,
    ]) {
      expect(actionFor(InvoiceStatus(k)), InvoiceAction.open, reason: '$k');
    }
  });

  group('the four figures', () {
    test('two currencies are never added', () {
      final f = figuresOf(
        [
          _r(id: 'a', due: DateTime(2026, 11, 2)),
          _r(id: 'b', currency: 'CHF', open: 8000, due: DateTime(2026, 11, 2)),
          _r(id: 'c', open: 2500),
          _r(
            id: 'd',
            currency: 'CHF',
            total: 3000,
            open: 0,
            stage: ReceivableStage.paid,
            paidOn: DateTime(2026, 11, 3),
          ),
          _r(
            id: 'e',
            total: 900,
            open: 0,
            stage: ReceivableStage.paid,
            paidOn: DateTime(2026, 10, 31),
          ),
        ],
        toInvoice: [(customerId: 'c9', currency: 'EUR', amountMinor: 5000)],
        today: _today,
      );
      expect(f.overdue, const Tally(2, {'EUR': 10000, 'CHF': 8000}));
      expect(f.awaitingPayment, const Tally(1, {'EUR': 2500}));
      // Paid this month counts November only, in the business's calendar.
      expect(f.paidThisMonth, const Tally(1, {'CHF': 3000}));
      expect(f.toInvoice, const Tally(1, {'EUR': 5000}));
    });

    test('a draft, a cancelled and a credited invoice count in none', () {
      final f = figuresOf([
        _r(stage: ReceivableStage.draft),
        _r(stage: ReceivableStage.cancelled),
        _r(stage: ReceivableStage.credited),
      ], today: _today);
      expect(f.overdue, Tally.empty);
      expect(f.awaitingPayment, Tally.empty);
      expect(f.paidThisMonth, Tally.empty);
    });
  });

  test(
    '"Do next" keeps the issue\'s order and only what has something to do',
    () {
      final late = DateTime(2026, 11, 2);
      final next = doNextOf(
        [
          _r(
            id: 'd',
            stage: ReceivableStage.draft,
            issued: DateTime(2026, 10, 20),
          ),
          _r(id: 'f', due: late, failed: true),
          _r(id: 'p', due: late, declared: true),
          _r(id: 'r1', due: late, dueLevel: 1, open: 1000),
          _r(id: 'r2', due: late, dueLevel: 2, currency: 'CHF', open: 2000),
          _r(
            id: 'fresh',
            stage: ReceivableStage.draft,
            issued: DateTime(2026, 11, 8),
          ),
        ],
        toInvoice: [(customerId: 'c9', currency: 'EUR', amountMinor: 5000)],
        today: _today,
      );
      expect(
        [for (final n in next) n.kind],
        [
          DoNextKind.invoiceTheMonth,
          DoNextKind.sendReminders,
          DoNextKind.confirmPayments,
          DoNextKind.fixSending,
          DoNextKind.issueDrafts,
        ],
      );
      expect(next[1].tally, const Tally(2, {'EUR': 1000, 'CHF': 2000}));
      // Every draft counts, however recent.
      expect(next[4].tally.count, 2);
      expect(doNextOf([_r()], today: _today), isEmpty);
    },
  );

  test('customer balances: open and overdue per currency, the oldest age, '
      'the most overdue first', () {
    final balances = customerBalancesOf([
      _r(
        id: 'a1',
        customer: 'a',
        open: 1000,
        issued: DateTime(2026, 9),
        due: DateTime(2026, 10),
      ),
      _r(
        id: 'a2',
        customer: 'a',
        currency: 'CHF',
        open: 700,
        issued: DateTime(2026, 11),
      ),
      _r(
        id: 'b1',
        customer: 'b',
        name: 'Bea',
        open: 5000,
        issued: DateTime(2026, 11, 5),
      ),
      _r(
        id: 'c1',
        customer: 'c',
        name: 'Cy',
        stage: ReceivableStage.paid,
        open: 0,
      ),
    ], today: _today);
    expect([for (final b in balances) b.customerName], ['Ada', 'Bea']);
    expect(balances.first.open, const Tally(2, {'EUR': 1000, 'CHF': 700}));
    expect(balances.first.overdue, const Tally(1, {'EUR': 1000}));
    expect(balances.first.oldestDays, 70);
    expect(balances.last.overdue, Tally.empty);
  });
}
