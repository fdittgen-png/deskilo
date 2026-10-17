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
  final AppliedInvoice? appliedInvoice;
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
