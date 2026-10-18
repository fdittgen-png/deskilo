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
