// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the owner's invoicing read models: every status of the final list
// and its precedence (a claim of payment outranks a hold), and the one action
// of a line, which depends on whether reminders are shared by hand. The
// answers built on them are in receivables_answers_test.dart.
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:flutter_test/flutter_test.dart';

/// The business's calendar day the tests are read on.
final _today = DateTime(2026, 11, 10);
final _late = DateTime(2026, 11, 2);

Receivable _r({
  int open = 10000,
  ReceivableStage stage = ReceivableStage.open,
  DateTime? due,
  bool noDue = false,
  bool dueSet = true,
  bool declared = false,
  bool toMatch = false,
  bool approval = false,
  bool customerConfirms = false,
  bool hold = false,
  bool rejected = false,
  int sent = 0,
  bool exhausted = false,
  int? dueLevel,
}) => Receivable(
  invoiceId: 'i1',
  customerId: 'c1',
  customerName: 'Ada',
  number: 'F-1',
  currency: 'EUR',
  totalMinor: 10000,
  openMinor: open,
  issuedOn: DateTime(2026, 10),
  dueOn: stage == ReceivableStage.draft || noDue
      ? null
      : (due ?? DateTime(2026, 11, 20)),
  dueDateSet: dueSet,
  stage: stage,
  paymentDeclared: declared,
  paymentToMatch: toMatch,
  awaitingSecondApproval: approval,
  awaitingCustomerConfirmation: customerConfirms,
  onHold: hold,
  eInvoiceRejected: rejected,
  remindersSent: sent,
  remindersExhausted: exhausted,
  reminderDueLevel: dueLevel,
);

InvoiceStatus _status(Receivable r) => invoiceStatusOf(r, _today);
InvoiceStatusKind _kind(Receivable r) => _status(r).kind;

void main() {
  group('status in words', () {
    test('a document whose story ended says how', () {
      for (final (stage, kind) in [
        (ReceivableStage.draft, InvoiceStatusKind.draft),
        (ReceivableStage.paid, InvoiceStatusKind.paid),
        (ReceivableStage.cancelled, InvoiceStatusKind.cancelled),
        (ReceivableStage.credited, InvoiceStatusKind.credited),
        (ReceivableStage.regrouped, InvoiceStatusKind.regrouped),
        (ReceivableStage.refundOwed, InvoiceStatusKind.refundOwed),
        (ReceivableStage.refunded, InvoiceStatusKind.refunded),
      ]) {
        expect(_kind(_r(stage: stage, due: _late, declared: true)), kind);
      }
    });

    test('the calendar: due in n days, n days late, no due date', () {
      expect(_status(_r()), const InvoiceStatus(InvoiceStatusKind.dueIn, 10));
      expect(
        _kind(_r(due: DateTime(2026, 11, 10))),
        InvoiceStatusKind.late,
        reason: '#3285: the due day itself is late',
      );
      expect(
        _status(_r(due: _late)),
        const InvoiceStatus(InvoiceStatusKind.late, 8),
      );
      expect(_kind(_r(noDue: true)), InvoiceStatusKind.noDueDate);
      // No date frozen at issue: the term still decides lateness (one rule),
      // and before it the invoice says it has no due date.
      expect(_kind(_r(dueSet: false)), InvoiceStatusKind.noDueDate);
      expect(_kind(_r(dueSet: false, due: _late)), InvoiceStatusKind.late);
    });

    test('late, with its reminders: k sent, or every one sent', () {
      expect(
        _status(_r(due: _late, sent: 2, dueLevel: 3)),
        const InvoiceStatus(InvoiceStatusKind.lateReminderSent, 8, 2),
      );
      expect(
        _status(_r(due: _late, sent: 3, exhausted: true)),
        const InvoiceStatus(InvoiceStatusKind.lateEveryReminderSent, 8),
      );
    });

    test("the payment's own steps, in order, each outranking a hold", () {
      expect(
        _kind(_r(due: _late, hold: true, declared: true, approval: true)),
        InvoiceStatusKind.paymentDeclared,
      );
      expect(
        _kind(_r(due: _late, hold: true, approval: true, toMatch: true)),
        InvoiceStatusKind.awaitingSecondApproval,
      );
      expect(
        _kind(_r(due: _late, toMatch: true, customerConfirms: true)),
        InvoiceStatusKind.paymentToMatch,
      );
      expect(
        _kind(_r(due: _late, hold: true, customerConfirms: true)),
        InvoiceStatusKind.awaitingCustomer,
      );
      expect(
        _kind(_r(due: _late, hold: true, dueLevel: 1)),
        InvoiceStatusKind.onHold,
      );
    });

    test('a rejected e-invoice comes before everything still open', () {
      expect(
        _kind(_r(due: _late, rejected: true, declared: true, hold: true)),
        InvoiceStatusKind.eInvoiceRejected,
      );
    });

    test('a part paid, not yet late, says the open amount; once late it is '
        'late', () {
      expect(
        _status(_r(stage: ReceivableStage.partlyPaid, open: 4000)),
        const InvoiceStatus(InvoiceStatusKind.partlyPaid, 4000),
      );
      expect(
        _kind(_r(stage: ReceivableStage.partlyPaid, open: 4000, due: _late)),
        InvoiceStatusKind.late,
      );
    });
  });

  group('one action per line', () {
    InvoiceAction byHand(Receivable r) =>
        actionOf(r, _today, ReminderMode.byHand);
    InvoiceAction automatic(Receivable r) =>
        actionOf(r, _today, ReminderMode.automatic);

    test("the business's move, whatever the reminder mode", () {
      expect(byHand(_r(stage: ReceivableStage.draft)), InvoiceAction.issue);
      expect(byHand(_r(declared: true)), InvoiceAction.confirmPayment);
      expect(byHand(_r(toMatch: true)), InvoiceAction.match);
      expect(
        byHand(_r(stage: ReceivableStage.refundOwed)),
        InvoiceAction.payOutRefund,
      );
      expect(byHand(_r(rejected: true)), InvoiceAction.fix);
    });

    test('a due reminder is shared by hand; never offered when reminders go '
        'out by themselves, on hold, with a payment pending or the ladder '
        'done', () {
      final due = _r(due: _late, dueLevel: 1);
      expect(byHand(due), InvoiceAction.shareReminder);
      expect(automatic(due), InvoiceAction.open);
      for (final r in [
        _r(due: _late, dueLevel: 1, hold: true),
        _r(due: _late, dueLevel: 1, customerConfirms: true),
        _r(due: _late, dueLevel: 1, approval: true),
        _r(due: _late, dueLevel: 1, exhausted: true),
      ]) {
        expect(byHand(r), InvoiceAction.open);
      }
    });

    test('everything else opens the invoice', () {
      for (final r in [
        _r(),
        _r(due: _late),
        _r(approval: true),
        _r(customerConfirms: true),
        _r(stage: ReceivableStage.paid),
        _r(stage: ReceivableStage.regrouped),
        _r(stage: ReceivableStage.refunded),
      ]) {
        expect(byHand(r), InvoiceAction.open, reason: '${_status(r)}');
      }
    });
  });
}
