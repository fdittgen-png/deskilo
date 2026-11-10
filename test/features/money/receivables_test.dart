// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the owner's invoicing read models: every status, its precedence
// over the payment's own steps, and the one action per status. The answers
// built on them are in receivables_answers_test.dart.
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
  bool toMatch = false,
  bool approval = false,
  bool customerConfirms = false,
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
  paymentToMatch: toMatch,
  awaitingSecondApproval: approval,
  awaitingCustomerConfirmation: customerConfirms,
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
        InvoiceStatusKind.couldNotBeSent,
      );
    });

    test('the payment\'s own steps, in order, and each outranks a hold', () {
      final late = DateTime(2026, 11, 2);
      InvoiceStatusKind kind(Receivable r) => _status(r).kind;
      expect(
        kind(_r(due: late, hold: true, declared: true, approval: true)),
        InvoiceStatusKind.paymentDeclared,
      );
      expect(
        kind(_r(due: late, hold: true, approval: true, toMatch: true)),
        InvoiceStatusKind.awaitingSecondApproval,
      );
      expect(
        kind(_r(due: late, toMatch: true, customerConfirms: true)),
        InvoiceStatusKind.paymentToMatch,
      );
      expect(
        kind(_r(due: late, hold: true, customerConfirms: true, dueLevel: 1)),
        InvoiceStatusKind.awaitingCustomer,
      );
      // A hold stops the reminder that would be due.
      expect(
        kind(_r(due: late, hold: true, dueLevel: 1)),
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
    expect(r.isLateOn(_today), isFalse);
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
      actionFor(const InvoiceStatus(InvoiceStatusKind.paymentToMatch)),
      InvoiceAction.match,
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
      InvoiceStatusKind.awaitingSecondApproval,
      InvoiceStatusKind.awaitingCustomer,
      InvoiceStatusKind.cancelled,
      InvoiceStatusKind.credited,
    ]) {
      expect(actionFor(InvoiceStatus(k)), InvoiceAction.open, reason: '$k');
    }
  });
}
