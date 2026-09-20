// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the rules the Register payment sheet used to own.
import 'package:deskilo/features/money/application/record_payment.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_money_repository.dart';

void main() {
  test('a payment belongs to the month it was PAID in, not the month it '
      'was typed in', () {
    // January's transfers, entered on the 3rd of February, are January.
    expect(periodOfPayment(DateTime(2026, 1, 31)), '2026-01');
    expect(periodOfPayment(DateTime(2026, 2, 3)), '2026-02');
    expect(periodOfPayment(DateTime(2026, 12, 9)), '2026-12');
    expect(periodOfPayment(DateTime(2027, 9, 1)), '2027-09',
        reason: 'a single-digit month is padded, or the server refuses it');
  });

  test('a recorded payment reports the month it landed in and the claim to '
      'confirm', () async {
    final money = FakeMoneyRepository();
    final outcome = await Payments(money).record(
      workspaceId: 'ws-1',
      memberId: 'm-1',
      amountCents: 5000,
      paidOn: DateTime(2026, 1, 31),
      note: '  bank transfer  ',
      method: PaymentMethod.bankTransfer,
    );
    expect(outcome, isA<PaymentRecorded>());
    expect((outcome as PaymentRecorded).period, '2026-01');
    expect(outcome.eventId, isNotEmpty);
    expect(money.recordedPayments.single.period, '2026-01');
    expect(money.recordedPayments.single.note, 'bank transfer',
        reason: 'the note is trimmed once, here, not in every caller');
  });

  test('what is missing is named, and nothing is sent', () async {
    final money = FakeMoneyRepository();
    final payments = Payments(money);
    String what(RecordPaymentOutcome o) => (o as PaymentIncomplete).what;

    expect(
      what(await payments.record(
          workspaceId: null,
          memberId: 'm-1',
          amountCents: 100,
          paidOn: DateTime(2026, 1, 1))),
      'workspace',
    );
    expect(
      what(await payments.record(
          workspaceId: 'ws-1',
          memberId: null,
          amountCents: 100,
          paidOn: DateTime(2026, 1, 1))),
      'member',
    );
    for (final cents in [null, 0, -100]) {
      expect(
        what(await payments.record(
            workspaceId: 'ws-1',
            memberId: 'm-1',
            amountCents: cents,
            paidOn: DateTime(2026, 1, 1))),
        'amount',
        reason: 'amount $cents',
      );
    }
    expect(money.recordedPayments, isEmpty,
        reason: 'an incomplete payment is never sent');
  });
}
