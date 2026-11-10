// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 Design 2 — the answers of the invoicing home: what is owed in its
// three buckets, the month's two figures, "To do" and its order, one line per
// customer and its order, and two currencies never summed anywhere.
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The business's calendar day the tests are read on.
final _today = DateTime(2026, 11, 10);
final _late = DateTime(2026, 11, 2);

Receivable _r({
  String id = 'i1',
  String customer = 'c1',
  String name = 'Ada',
  String currency = 'EUR',
  int total = 10000,
  int? open,
  ReceivableStage stage = ReceivableStage.open,
  DateTime? issued,
  DateTime? due,
  bool declared = false,
  bool toMatch = false,
  bool approval = false,
  bool customerConfirms = false,
  bool hold = false,
  bool failed = false,
  int? dueLevel,
}) => Receivable(
  invoiceId: id,
  customerId: customer,
  customerName: name,
  number: 'F-$id',
  currency: currency,
  totalMinor: total,
  openMinor: open ?? (stage == ReceivableStage.paid ? 0 : total),
  issuedOn: issued ?? DateTime(2026, 10),
  dueOn: stage == ReceivableStage.draft ? null : due ?? DateTime(2026, 11, 20),
  stage: stage,
  paymentDeclared: declared,
  paymentToMatch: toMatch,
  awaitingSecondApproval: approval,
  awaitingCustomerConfirmation: customerConfirms,
  onHold: hold,
  sendFailed: failed,
  reminderDueLevel: dueLevel,
);

void main() {
  group('owed', () {
    test('three buckets: money on its way is to confirm whatever its due '
        'date; a customer\'s confirmation is not', () {
      expect(owedBucketOf(_r(), _today), OwedBucket.notYetDue);
      expect(owedBucketOf(_r(due: _late), _today), OwedBucket.overdue);
      for (final r in [
        _r(due: _late, declared: true),
        _r(toMatch: true),
        _r(due: _late, approval: true),
      ]) {
        expect(owedBucketOf(r, _today), OwedBucket.toConfirm);
      }
      expect(
        owedBucketOf(_r(due: _late, customerConfirms: true), _today),
        OwedBucket.overdue,
      );
      for (final stage in [
        ReceivableStage.draft,
        ReceivableStage.paid,
        ReceivableStage.cancelled,
        ReceivableStage.credited,
      ]) {
        expect(
          owedBucketOf(_r(stage: stage), _today),
          isNull,
          reason: '$stage',
        );
      }
    });

    test('one entry per currency, never added across currencies', () {
      final owed = owedOf([
        _r(id: 'a', due: _late),
        _r(id: 'b', open: 2500),
        _r(id: 'c', currency: 'CHF', total: 8000, due: _late),
        _r(id: 'd', currency: 'CHF', total: 900, declared: true),
        _r(id: 'e', stage: ReceivableStage.paid),
      ], _today);
      expect([for (final o in owed) o.currency], ['CHF', 'EUR']);
      final chf = owed.first;
      expect(chf.totalMinor, 8900);
      expect(chf.buckets[OwedBucket.overdue], (count: 1, minor: 8000));
      expect(chf.buckets[OwedBucket.toConfirm], (count: 1, minor: 900));
      expect(chf.buckets.containsKey(OwedBucket.notYetDue), isFalse);
      final eur = owed.last;
      expect(eur.totalMinor, 12500);
      expect(eur.buckets[OwedBucket.notYetDue], (count: 1, minor: 2500));
    });
  });

  test('the month: invoiced at the totals issued in it, received as the '
      'money of the payments dated in it, partial ones included', () {
    final m = monthOf(
      [
        _r(id: 'a', issued: DateTime(2026, 11, 3)),
        _r(id: 'b', currency: 'CHF', total: 700, issued: DateTime(2026, 11)),
        _r(id: 'c', issued: DateTime(2026, 10, 31)),
        _r(
          id: 'd',
          stage: ReceivableStage.cancelled,
          issued: DateTime(2026, 11, 4),
        ),
        _r(
          id: 'e',
          stage: ReceivableStage.draft,
          issued: DateTime(2026, 11, 5),
        ),
      ],
      _today,
      received: [
        (currency: 'EUR', minor: 4000, on: DateTime(2026, 11, 2)),
        (currency: 'EUR', minor: 1500, on: DateTime(2026, 11, 9)),
        (currency: 'CHF', minor: 300, on: DateTime(2026, 11)),
        (currency: 'EUR', minor: 9999, on: DateTime(2026, 10, 30)),
      ],
    );
    expect(m.invoiced, const Tally(2, {'EUR': 10000, 'CHF': 700}));
    expect(m.received, const Tally(3, {'EUR': 5500, 'CHF': 300}));
  });

  group('To do', () {
    test('the order: month, reminders, confirm, match, could not be sent, '
        'drafts — only what has something to do', () {
      final todo = todoOf(
        [
          _r(id: 'd', stage: ReceivableStage.draft),
          _r(id: 'f', due: _late, failed: true),
          _r(id: 'm', toMatch: true, open: 300),
          _r(id: 'p', due: _late, declared: true),
          _r(id: 'r1', due: _late, dueLevel: 1, open: 1000),
          _r(id: 'r2', due: _late, dueLevel: 2, currency: 'CHF', open: 2000),
        ],
        toInvoice: [(customerId: 'c9', currency: 'EUR', amountMinor: 5000)],
        today: _today,
      );
      expect([for (final t in todo) t.kind], TodoKind.values);
      expect(todo[1].tally, const Tally(2, {'EUR': 1000, 'CHF': 2000}));
      expect(todo[3].tally, const Tally(1, {'EUR': 300}));
      expect(todoOf([_r()], today: _today), isEmpty);
    });

    test('a hold stops the reminder, not the payment to confirm', () {
      final todo = todoOf([
        _r(id: 'h', due: _late, hold: true, dueLevel: 1),
        _r(id: 'hp', due: _late, hold: true, declared: true),
      ], today: _today);
      expect([for (final t in todo) t.kind], [TodoKind.confirmPayments]);
    });
  });

  group('one line per customer', () {
    test('what they owe per currency, their worst lateness and their one '
        'action: remind, else confirm, else match', () {
      final rows = customerRowsOf([
        _r(id: 'a1', customer: 'a', due: DateTime(2026, 10), dueLevel: 2),
        _r(id: 'a2', customer: 'a', currency: 'CHF', total: 700, due: _late),
        _r(id: 'b1', customer: 'b', name: 'Bea', declared: true),
        _r(id: 'c1', customer: 'c', name: 'Cy', toMatch: true),
        _r(id: 'd1', customer: 'd', name: 'Dee', hold: true),
      ], today: _today);
      final ada = rows.first;
      expect(ada.customerName, 'Ada');
      expect(ada.owes, const Tally(2, {'EUR': 10000, 'CHF': 700}));
      expect(ada.daysLate, 40);
      expect(ada.action, InvoiceAction.sendReminder);
      expect([for (final i in ada.invoices) i.invoiceId], ['a1', 'a2']);
      final byName = {for (final r in rows) r.customerName: r};
      expect(byName['Bea']!.action, InvoiceAction.confirmPayment);
      expect(byName['Cy']!.action, InvoiceAction.match);
      expect(byName['Dee']!.action, isNull);
      expect(byName['Dee']!.onHold, isTrue);
      expect(byName['Bea']!.daysLate, isNull);
    });

    test('late first, the most late first, then the larger amount in one '
        'same currency, then the name', () {
      final rows = customerRowsOf([
        _r(id: 'z', customer: 'z', name: 'Zed', due: _late),
        _r(id: 'y', customer: 'y', name: 'Yan', due: DateTime(2026, 10)),
        _r(id: 'small', customer: 's', name: 'Sam', total: 100),
        _r(id: 'big', customer: 'b', name: 'Bo', total: 900),
        _r(id: 'chf', customer: 'c', name: 'Cal', currency: 'CHF', total: 50),
      ], today: _today);
      expect(
        [for (final r in rows) r.customerName],
        ['Yan', 'Zed', 'Bo', 'Cal', 'Sam'],
      );
    });
  });
}
