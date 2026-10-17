// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one door for capturing a supplier bill. The server derives the actor,
// the state and the totals and decides who may (managePurchases, purchases
// on); this refuses only what cannot be a bill at all.
import '../domain/purchase.dart';

class PurchaseCommands {
  const PurchaseCommands(this._repository);

  final PurchaseRepository _repository;

  /// Saves [draft] as a draft bill under [requestId] (the same id retries
  /// the same save). Null, nothing sent, when the amount is not positive or
  /// the stated tax exceeds the gross.
  Future<String?> saveBill(
    String workspaceId,
    String requestId,
    PurchaseBillDraft draft,
  ) async {
    if (draft.grossCents <= 0) return null;
    final tax = draft.taxCents;
    if (tax != null && (tax < 0 || tax > draft.grossCents)) return null;
    return _repository.saveDraft(workspaceId, requestId, draft);
  }

  /// Records cash paid against [claim]. Null, nothing sent, when the amount
  /// is not positive or exceeds what remains; the server decides the rest
  /// (permission, revision, an invoice that applied the claim).
  Future<PurchaseObligation?> reimburse(
    String workspaceId,
    PurchaseObligation claim,
    ReimbursementCommand command,
  ) async {
    if (!claim.payable ||
        command.amountCents <= 0 ||
        command.amountCents > claim.remainingCents) {
      return null;
    }
    return _repository.recordReimbursement(workspaceId, command);
  }

  /// Reverses one recorded payment of [claim] for [reason].
  Future<PurchaseObligation?> reverse(
    String workspaceId,
    PurchaseObligation claim,
    SettlementAllocation payment, {
    required String reason,
    required String requestId,
  }) async {
    if (!payment.reversible || reason.trim().isEmpty) return null;
    return _repository.reverseAllocation(
      workspaceId,
      allocationId: payment.id,
      revision: claim.revision,
      reason: reason.trim(),
      requestId: requestId,
    );
  }

  /// Sends a captured bill to approval; null, nothing sent, when it is not a
  /// draft bill.
  Future<PurchaseState?> submit(
    String workspaceId,
    PurchaseDetail bill,
    String requestId,
  ) async {
    final s = bill.summary;
    if (s.kind != PurchaseKind.bill || s.state != PurchaseState.draft) {
      return null;
    }
    return _repository.submitBill(workspaceId, s.id, bill.revision, requestId);
  }

  /// Approves or rejects a bill awaiting approval; a rejection needs its
  /// reason.
  Future<PurchaseState?> decide(
    String workspaceId,
    PurchaseDetail bill, {
    required bool approve,
    required String reason,
    required String requestId,
  }) async {
    if (bill.summary.state != PurchaseState.pending ||
        (!approve && reason.trim().isEmpty)) {
      return null;
    }
    return _repository.decideBill(
      workspaceId,
      bill.summary.id,
      bill.revision,
      approve: approve,
      reason: reason.trim(),
      requestId: requestId,
    );
  }
}
