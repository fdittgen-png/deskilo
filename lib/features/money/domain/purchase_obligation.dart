// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'purchase.dart';

/// Who is owed: a member who paid out of pocket, or a supplier.
enum CreditorKind {
  member('member'),
  supplier('supplier');

  const CreditorKind(this.wire);

  final String wire;

  static CreditorKind of(String s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => member);
}

/// Where a claim stands. `held` and `cancelled` have no producer yet; the
/// server may already say them.
enum ObligationState {
  open,
  held,
  cancelled;

  static ObligationState of(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => open);
}

/// The invoice that carried a member's credit.
class AppliedInvoice {
  const AppliedInvoice({
    required this.id,
    required this.number,
    required this.totalCents,
  });

  factory AppliedInvoice.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'applied invoice');
    return AppliedInvoice(
      id: r.string('id'),
      number: r.string('number'),
      totalCents: r.integer('total_cents'),
    );
  }

  final String id;
  final String number;

  /// Negative: the invoice became a credit note.
  final int totalCents;
}

/// One movement against a claim: a payment recorded, or its reversal (a
/// negative amount). History: never edited.
class SettlementAllocation {
  const SettlementAllocation({
    required this.id,
    required this.isReversal,
    required this.amountCents,
    required this.method,
    required this.reference,
    this.paidOn,
    this.reversed = false,
  });

  factory SettlementAllocation.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'settlement allocation');
    return SettlementAllocation(
      id: r.string('id'),
      isReversal: r.string('kind') == 'reversal',
      amountCents: r.integer('amount_cents'),
      method: r.stringOr('method'),
      reference: r.stringOr('reference'),
      paidOn: DateTime.tryParse(r.stringOr('paid_on')),
      reversed: r.boolOr('reversed', fallback: false),
    );
  }

  final String id;
  final bool isReversal;

  /// Positive for a payment, negative for its reversal.
  final int amountCents;
  final String method;
  final String reference;
  final DateTime? paidOn;

  /// A payment that a later reversal cancelled.
  final bool reversed;

  /// A payment that can still be reversed.
  bool get reversible => !isReversal && !reversed;
}

/// What the space owes a creditor for one approved purchase. It indexes the
/// existing running-account credit; it is not an expense and not a payment.
class PurchaseObligation {
  const PurchaseObligation({
    required this.id,
    required this.purchaseId,
    required this.creditorKind,
    required this.creditorId,
    required this.amountCents,
    required this.currency,
    required this.appliedCents,
    required this.remainingCents,
    this.paidCents = 0,
    this.revision = 1,
    this.mine = false,
    this.allocations = const [],
    this.state = ObligationState.open,
    this.dueOn,
    this.appliedInvoice,
  });

  factory PurchaseObligation.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase obligation');
    final invoice = r.objectOrNull('applied_invoice');
    return PurchaseObligation(
      id: r.string('id'),
      purchaseId: r.string('purchase_id'),
      creditorKind: CreditorKind.of(r.string('creditor_kind')),
      creditorId: r.string('creditor_id'),
      amountCents: r.integer('amount_cents'),
      currency: r.string('currency'),
      state: ObligationState.of(r.stringOrNull('state')),
      dueOn: DateTime.tryParse(r.stringOr('due_on')),
      appliedCents: r.integer('applied_cents'),
      remainingCents: r.integer('remaining_cents'),
      paidCents: r.integer('paid_cents'),
      revision: r.integer('revision'),
      mine: r.boolOr('mine', fallback: false),
      allocations: [
        for (final a in r.list('allocations')) SettlementAllocation.fromJson(a),
      ],
      appliedInvoice: invoice == null
          ? null
          : AppliedInvoice.fromJson(r.raw('applied_invoice')),
    );
  }

  final String id;
  final String purchaseId;
  final CreditorKind creditorKind;

  /// A member id or a supplier id, by [creditorKind].
  final String creditorId;
  final int amountCents;
  final String currency;
  final ObligationState state;
  final DateTime? dueOn;
  final int appliedCents;
  final int remainingCents;

  /// Cash recorded against the claim, net of reversals.
  final int paidCents;

  /// The version a payment is recorded against; a stale one is refused.
  final int revision;

  /// The signed-in person is the creditor (they cannot record their own
  /// payment).
  final bool mine;
  final List<SettlementAllocation> allocations;
  final AppliedInvoice? appliedInvoice;

  /// Cash may be recorded: something remains and no invoice has applied it.
  bool get payable =>
      creditorKind == CreditorKind.member &&
      state == ObligationState.open &&
      remainingCents > 0 &&
      appliedInvoice == null;
}

/// How a payment was made.
enum PaymentMethod {
  bankTransfer('bank_transfer'),
  cash('cash'),
  card('card'),
  other('other');

  const PaymentMethod(this.wire);

  final String wire;
}

/// A payment to record against a claim. The same [requestId] with the same
/// entries answers the original; the server derives the actor.
class ReimbursementCommand {
  const ReimbursementCommand({
    required this.obligationId,
    required this.amountCents,
    required this.revision,
    required this.requestId,
    required this.paidOn,
    this.method = PaymentMethod.bankTransfer,
    this.reference = '',
  });

  final String obligationId;
  final int amountCents;
  final int revision;
  final String requestId;
  final DateTime paidOn;
  final PaymentMethod method;
  final String reference;

  bool sameEntriesAs(ReimbursementCommand o) =>
      obligationId == o.obligationId &&
      amountCents == o.amountCents &&
      revision == o.revision &&
      paidOn == o.paidOn &&
      method == o.method &&
      reference == o.reference;
}

/// One line of the To-pay list: the claim and the document behind it.
class PayableRow {
  const PayableRow({required this.obligation, required this.purchase});

  factory PayableRow.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'payable');
    final o = PurchaseObligation.fromJson(r.raw('obligation'));
    final p = JsonReader.of(r.raw('purchase'), context: 'payable purchase');
    return PayableRow(
      obligation: o,
      purchase: PurchaseSummary(
        id: o.purchaseId,
        kind: PurchaseKind.of(p.stringOrNull('kind')),
        state: PurchaseState.of(p.stringOrNull('state')),
        category: p.stringOr('category'),
        reference: p.stringOr('original_reference'),
        currency: o.currency,
        grossCents: o.amountCents,
        receivedOn: DateTime.tryParse(p.stringOr('received_on')),
        legacy: p.boolOr('legacy', fallback: false),
      ),
    );
  }

  final PurchaseObligation obligation;
  final PurchaseSummary purchase;
}
