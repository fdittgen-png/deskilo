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

/// #4402 -- a NEW item as it is made from the Stock page, in one command (`create_stock_item_v1`): the service
/// (its name, price in minor units and VAT rate), its stock settings (kept in stock, bought and sold, in
/// [inventoryUnit], with [barcode] as its own code) and its home place. One request id makes the whole of it once.
class NewStockItemDraft {
  const NewStockItemDraft({
    required this.name,
    required this.priceCents,
    required this.inventoryUnit,
    this.vatRateId,
    this.barcode,
    this.homeLocationId,
  });

  final String name;
  final int priceCents;
  final String? vatRateId;
  final String inventoryUnit;
  final String? barcode;
  final String? homeLocationId;

  Map<String, Object?> toJson() => {
    'name': name,
    'price_cents': priceCents,
    'vat_rate_id': ?vatRateId,
    'inventory_unit': inventoryUnit,
    'barcode': ?barcode,
    'home_location_id': ?homeLocationId,
  };
}
