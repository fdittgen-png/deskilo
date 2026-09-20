// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 / #1234 — registering a payment is a decision, not a form.
//
// The sheet owned three rules that nothing could test without pumping a
// widget: which month a payment belongs to, when there is not enough to
// send, and that a payment recorded here is a CLAIM the other side
// confirms (0017) rather than money in the ledger.
//
// The month is the rule worth naming. A payment belongs to the month it
// was PAID in, not the month somebody typed it into the app: an admin
// entering January's bank transfers on the 3rd of February is recording
// January. The sheet used to derive that string inline, so the rule
// lived in a widget and read as formatting.
//
// ADR 0024's shape (`WordingTerms`, `WorkspaceColours`): pure Dart, the
// repository handed in, so the rules below are exercised without a
// screen.
import '../domain/money_repository.dart';
import '../domain/payment_method.dart';

/// What happened to a payment somebody tried to register.
sealed class RecordPaymentOutcome {
  const RecordPaymentOutcome();
}

/// Recorded, and awaiting the other side's confirmation (0017). [period]
/// is the month it was booked into; [eventId] the claim to confirm.
class PaymentRecorded extends RecordPaymentOutcome {
  const PaymentRecorded({required this.eventId, required this.period});
  final String eventId;
  final String period;
}

/// Not enough to send: [what] says which part is missing.
class PaymentIncomplete extends RecordPaymentOutcome {
  const PaymentIncomplete(this.what);

  /// `member`, `amount` or `workspace` — the one the caller must fix.
  final String what;
}

/// The month a payment paid on [day] belongs to, `YYYY-MM`.
String periodOfPayment(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}';

class Payments {
  const Payments(this._money);
  final MoneyRepository _money;

  /// Registers a payment a member made, as the month it was paid in.
  ///
  /// Refuses rather than sending an empty or negative amount: the server
  /// would refuse it too, and a refusal that names what is missing is
  /// the difference between "fix the amount" and "something went wrong".
  Future<RecordPaymentOutcome> record({
    required String? workspaceId,
    required String? memberId,
    required int? amountCents,
    required DateTime paidOn,
    String note = '',
    PaymentMethod? method,
  }) async {
    if (workspaceId == null || workspaceId.isEmpty) {
      return const PaymentIncomplete('workspace');
    }
    if (memberId == null || memberId.isEmpty) {
      return const PaymentIncomplete('member');
    }
    if (amountCents == null || amountCents <= 0) {
      return const PaymentIncomplete('amount');
    }
    final period = periodOfPayment(paidOn);
    final eventId = await _money.recordPayment(
      workspaceId: workspaceId,
      memberId: memberId,
      amountCents: amountCents,
      note: note.trim(),
      method: method,
      paidOn: paidOn,
      period: period,
    );
    return PaymentRecorded(eventId: eventId, period: period);
  }
}
