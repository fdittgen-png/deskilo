// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- what a stock save sends, typed: no map crosses a port. Each draft writes the body its server function
// reads (`toJson`), key for key as the screens built it before, and the Demo reads the same fields.

/// A place as it is saved: a new one or one read at its revision (the port names which).
class StockPlaceDraft {
  const StockPlaceDraft({
    required this.kind,
    required this.code,
    required this.name,
    required this.active,
    required this.receivesFromSuppliers,
    this.barcode,
    this.parentId,
    this.pickRole,
  });

  final String kind;
  final String code;
  final String name;
  final String? barcode;

  /// The place above it; null for a site, which is a root.
  final String? parentId;
  final bool active;

  /// A site only: whether goods are put away there from a supplier.
  final bool receivesFromSuppliers;

  /// A place below a site: `picking` or `reserve`; null when not said.
  final String? pickRole;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'code': code,
    'name': name,
    'barcode': barcode,
    'parent_id': parentId,
    'active': active,
    'receives_from_suppliers': receivesFromSuppliers,
    'pick_role': pickRole,
  };
}

/// A supplier's article mapped to an item, as it is saved.
class SupplierMappingDraft {
  const SupplierMappingDraft({
    required this.supplierId,
    required this.itemId,
    required this.articleRef,
    required this.active,
    this.variantId,
    this.purchaseUnit,
  });

  final String? supplierId;
  final String itemId;
  final String? variantId;
  final String articleRef;
  final String? purchaseUnit;
  final bool active;

  Map<String, Object?> toJson() => {
    'supplier_id': supplierId,
    'item_id': itemId,
    'variant_id': variantId,
    'article_ref': articleRef,
    'purchase_unit': purchaseUnit,
    'active': active,
  };
}
