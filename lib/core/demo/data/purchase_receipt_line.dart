// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/vat_rate.dart';

/// A claim's receipt as the server reads it: one line, its claim.
PurchaseLine claimReceiptLine(PayableRow row, double? rate) {
  final gross = row.purchase.grossCents;
  if (rate == null) {
    return PurchaseLine(
      lineNo: 1,
      description: row.purchase.category,
      grossCents: gross,
    );
  }
  final split = vatSplit(gross, rate);
  return PurchaseLine(
    lineNo: 1,
    description: row.purchase.category,
    grossCents: gross,
    netCents: split.netCents,
    taxCents: split.vatCents,
    taxRatePercent: rate,
    recoverableTaxCents: split.vatCents,
  );
}

<<<<<<< HEAD
/// #2573 — the demonstration files no expense request as a document and
/// links no received invoice.
=======
/// #2573 — the demonstration files no expense request as a document.
>>>>>>> origin/master
mixin NoFiledPurchases implements PurchaseRepository {
  @override
  Future<String?> purchaseFiledFrom(
    String workspaceId, {
    required String sourceKind,
    required String sourceId,
  }) async => null;
<<<<<<< HEAD

  /// Received invoices are not linked in the demonstration: refused, so
  /// the sheet says so instead of pretending.
  @override
  Future<void> linkInboxDocument(
    String workspaceId,
    String purchaseId, {
    required int revision,
    required String documentId,
    required String requestId,
  }) async => throw UnsupportedError('no inbox linking in the demonstration');
=======
>>>>>>> origin/master
}
