// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- a typed draft writes the body its server function reads, key for key as the screens built it before
// the drafts: the place, the supplier mapping, the reorder point (new and existing, a quantity or a level) and the
// item group.
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/stock_drafts.dart';
import 'package:deskilo/features/stock/domain/stock_reorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a place writes every field the location save reads', () {
    expect(
      const StockPlaceDraft(
        kind: 'shelf',
        code: 'A-1',
        name: 'Shelf A1',
        parentId: 'zone-1',
        active: true,
        receivesFromSuppliers: true,
        pickRole: 'picking',
      ).toJson(),
      {
        'kind': 'shelf',
        'code': 'A-1',
        'name': 'Shelf A1',
        'barcode': null,
        'parent_id': 'zone-1',
        'active': true,
        'receives_from_suppliers': true,
        'pick_role': 'picking',
      },
    );
  });

  test('a supplier mapping writes every field the mapping save reads', () {
    expect(
      const SupplierMappingDraft(
        supplierId: 's-1',
        itemId: 'i-1',
        articleRef: 'TX-100',
        purchaseUnit: 'box',
        active: true,
      ).toJson(),
      {
        'supplier_id': 's-1',
        'item_id': 'i-1',
        'variant_id': null,
        'article_ref': 'TX-100',
        'purchase_unit': 'box',
        'active': true,
      },
    );
  });

  test('a new reorder point names its item, variant and site; one that exists does not', () {
    const target = (item: 'i-1', variant: null, site: 'site-1');
    expect(
      const StockReorderPointDraft(
        target: target,
        point: '5',
        value: '20',
        upTo: false,
        active: true,
      ).toJson(),
      {
        'item_id': 'i-1',
        'variant_id': null,
        'site_id': 'site-1',
        'reorder_point': '5',
        'reorder_quantity': '20',
        'target_quantity': null,
        'active': true,
      },
    );
    expect(
      const StockReorderPointDraft(
        target: null,
        point: '5',
        value: '40',
        upTo: true,
        active: false,
      ).toJson(),
      {
        'reorder_point': '5',
        'reorder_quantity': null,
        'target_quantity': '40',
        'active': false,
      },
    );
    expect(
      const StockReorderPointDraft(
        target: null,
        point: '5',
        value: '',
        upTo: false,
        active: true,
      ).toJson(),
      {
        'reorder_point': '5',
        'reorder_quantity': null,
        'target_quantity': null,
        'active': true,
      },
      reason: 'an empty value: the point only flags',
    );
  });

  test(
    'an item group writes its name, its parent and the parameters it changes',
    () {
      expect(
        const ItemGroupDraft(
          name: 'Drinks',
          parentId: null,
          parameters: {'shelf_life_days': 120},
        ).toJson(),
        {
          'name': 'Drinks',
          'parent_id': null,
          'parameters': {'shelf_life_days': 120},
        },
      );
    },
  );
}
