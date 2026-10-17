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
}
