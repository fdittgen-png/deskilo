// SPDX-License-Identifier: AGPL-3.0-or-later
// A supplier order is a separate document from a received purchase bill.

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.description,
    required this.quantity,
    required this.unitCents,
  });

  final String description;
  final int quantity;
  final int unitCents;
  int get totalCents => quantity * unitCents;
}

class PurchaseOrder {
  PurchaseOrder({
    required this.workspaceId,
    required this.supplierId,
    required this.supplierName,
    required this.recipientEmail,
    required this.reference,
    required this.currency,
    required this.issuedAt,
    required List<PurchaseOrderLine> lines,
  }) : lines = List.unmodifiable(lines);

  final String workspaceId;
  final String supplierId;
  final String supplierName;
  final String recipientEmail;
  final String reference;
  final String currency;
  final DateTime issuedAt;
  final List<PurchaseOrderLine> lines;

  int get totalCents => lines.fold(0, (sum, line) => sum + line.totalCents);

  /// Nothing is sent if the document or its intended recipient is incomplete.
  bool get valid =>
      workspaceId.isNotEmpty &&
      supplierId.isNotEmpty &&
      supplierName.trim().isNotEmpty &&
      reference.trim().isNotEmpty &&
      RegExp(r'^[A-Z]{3}$').hasMatch(currency) &&
      lines.isNotEmpty &&
      lines.every(
        (line) =>
            line.description.trim().isNotEmpty &&
            line.quantity > 0 &&
            line.quantity <= 100000 &&
            line.unitCents >= 0 &&
            line.unitCents <= 100000000,
      ) &&
      totalCents <= 1000000000000;

  /// A printed order does not need a recipient; email delivery does.
  bool get emailable =>
      valid &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(recipientEmail.trim()) &&
      !recipientEmail.contains(RegExp(r'[\r\n]'));
}
