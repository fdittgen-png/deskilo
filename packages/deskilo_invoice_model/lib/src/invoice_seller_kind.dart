// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';
import 'invoice_clauses.dart';

/// #3875 — the seller kind an invoice was ISSUED under. It decides the word
/// of the recurring line (participation or subscription), which has tax
/// consequences, so a later change of the business's kind never rewords an
/// issued invoice.
extension InvoiceSellerKind on Invoice {
  /// The snapshot's kind when the invoice has one, else [live] (an older
  /// invoice, a preview).
  String sellerKindOr(String live) => legalClauses?.sellerKind ?? live;

  /// [sellerKindOr] as the question the wording asks.
  bool sellerIsAssociationOr(bool live) => switch (legalClauses) {
    final LegalClauseSnapshot frozen => frozen.sellerKind == 'association',
    _ => live,
  };
}
