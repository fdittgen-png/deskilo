// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2567 — the one door for supplier master data. The server decides who may
// (manageBilling, supplyExpenses on) and what is a duplicate; this refuses
// only what cannot be a supplier at all.
import '../domain/supplier.dart';

class SupplierCommands {
  const SupplierCommands(this._repository);

  final SupplierRepository _repository;

  /// Saves [draft]; null when it has no name (nothing is sent).
  Future<String?> save(String workspaceId, SupplierDraft draft) async {
    if (draft.name.trim().isEmpty) return null;
    return _repository.save(workspaceId, draft);
  }

  Future<void> archive(String supplierId) =>
      _repository.setStatus(supplierId, SupplierStatus.archived);

  Future<void> restore(String supplierId) =>
      _repository.setStatus(supplierId, SupplierStatus.active);

  /// A bank-detail change; the server records the revision and judges it.
  Future<int> changeBank(
    String supplierId, {
    required String accountHolder,
    required String iban,
    required String bic,
  }) => _repository.setBank(
    supplierId,
    accountHolder: accountHolder.trim(),
    iban: iban.trim(),
    bic: bic.trim(),
  );

  Future<String> resolveReview(String reviewId, String? supplierId) =>
      _repository.resolveReview(reviewId, supplierId);
}
