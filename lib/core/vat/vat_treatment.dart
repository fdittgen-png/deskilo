// SPDX-License-Identifier: 0BSD

/// #985 — the counterparty dimension of VAT: who the buyer is for tax.
/// The ERP "business posting group". Stored on `members.vat_treatment`
/// (0182); `create_invoice` applies the matrix business × product.
enum VatTreatment {
  /// Today's rule: reverse charge when the buyer is a business in
  /// another EU member state, domestic VAT otherwise.
  auto('auto'),

  /// Domestic VAT whatever the buyer's country — a desk is a service
  /// connected with immovable property (art. 47).
  domestic('domestic'),

  /// The customer self-assesses (category AE, art. 196).
  reverseCharge('reverse_charge'),

  /// Outside the EU (category G).
  export('export'),

  /// An exempt buyer, with the reason printed (category E).
  exempt('exempt');

  const VatTreatment(this.wire);

  final String wire;

  static VatTreatment fromWire(String? wire) =>
      values.firstWhere((t) => t.wire == wire, orElse: () => auto);
}
