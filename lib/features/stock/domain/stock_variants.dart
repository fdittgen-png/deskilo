// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (A2) -- dimensions, variants and the supplier's article, as an
// operator edits them. A variant is one value per dimension, unique per item;
// it shares its item's inventory unit and is separate stock. A mapping binds a
// supplier's article to an item (and a variant) and one of the item's package
// units by an explicit save, never by a name.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One allowed value of a dimension (Red, Blue).
class StockDimensionValue {
  const StockDimensionValue({
    required this.id,
    required this.label,
    required this.active,
  });

  final String? id;
  final String label;
  final bool active;

  Map<String, Object?> toJson() => {'id': id, 'label': label, 'active': active};

  factory StockDimensionValue.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_dimension_values');
    return StockDimensionValue(
      id: r.stringOrNull('id'),
      label: r.string('label'),
      active: r.boolOr('active', fallback: true),
    );
  }
}

/// A dimension of the business (Colour, Size) with its values and revision.
class StockDimension {
  const StockDimension({
    required this.id,
    required this.revision,
    required this.name,
    required this.active,
    required this.values,
  });

  final String id;
  final int revision;
  final String name;
  final bool active;
  final List<StockDimensionValue> values;

  /// The body of a save: the values sent are the complete list.
  Map<String, Object?> toSave() => {
    'name': name,
    'active': active,
    'values': [for (final v in values) v.toJson()],
  };
}

/// One variant of an item: a value of each dimension it varies by.
class StockVariant {
  const StockVariant({
    required this.id,
    required this.values,
    required this.priceCents,
    required this.active,
    required this.label,
  });

  /// Null for a variant not saved yet.
  final String? id;

  /// Dimension id to value id.
  final Map<String, String> values;
  final int? priceCents;
  final bool active;

  /// `Colour: Red · Size: M`, as the server reads it.
  final String label;

  Map<String, Object?> toJson() => {
    'id': id,
    'values': values,
    'price_cents': priceCents,
    'active': active,
  };
}

/// A supplier's article mapped to an item.
class SupplierItemMapping {
  const SupplierItemMapping({
    required this.id,
    required this.revision,
    required this.supplierId,
    required this.itemId,
    required this.variantId,
    required this.articleRef,
    required this.purchaseUnit,
    required this.active,
  });

  final String id;
  final int revision;
  final String supplierId;
  final String itemId;
  final String? variantId;
  final String articleRef;

  /// Null is the item's inventory unit.
  final String? purchaseUnit;
  final bool active;

  factory SupplierItemMapping.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'supplier_item_mappings');
    return SupplierItemMapping(
      id: r.string('id'),
      revision: r.integer('revision'),
      supplierId: r.string('supplier_id'),
      itemId: r.string('item_id'),
      variantId: r.stringOrNull('variant_id'),
      articleRef: r.string('article_ref'),
      purchaseUnit: r.stringOrNull('purchase_unit'),
      active: r.boolOr('active', fallback: true),
    );
  }
}

/// A supplier of the business, as the mapping editor offers it.
class StockSupplierRef {
  const StockSupplierRef({required this.id, required this.name});

  final String id;
  final String name;
}
