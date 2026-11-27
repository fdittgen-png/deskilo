// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4485 -- master data lives on the Master data page (docs/AGENT_RULES.md
// "Master data lives on the Master data page"): every screen that edits a
// kind of master data -- a list a picker reads, or a list the business is
// configured with -- has a card in the page's registry
// (lib/app/master_data/master_data_kinds.dart), and every card names one of
// those screens. The route table has no class for "master-data editor", so
// the editors are named here; a new one joins this list and gets its card in
// the same pull request.
import 'package:deskilo/app/master_data/master_data_kinds.dart';
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:flutter_test/flutter_test.dart';

/// The screens that edit master data, and what each one edits.
const Map<String, String> _masterDataEditors = {
  '/settings/units': '#4442 the units of measure and their conversions',
  '/vat': 'the VAT rates',
  '/stock/items': '#4299 the item registry',
  '/stock/groups': '#4361 the item groups',
  '/services': 'the services the business sells',
  '/stock/places': '#4299 the stock places',
  '/till/drawer': '#4367 the tills (and, from each, its layout)',
  '/money/suppliers': '#3070 the suppliers',
  '/money/customers': '#4164 the billing customers',
  '/settings/sites': '#945 the sites',
};

void main() {
  final cards = {for (final k in MasterDataKind.values) k.route: k};

  test('every master-data editor has a card on the Master data page', () {
    final missing = [
      for (final r in _masterDataEditors.keys)
        if (!cards.containsKey(r)) r,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'give each a MasterDataKind in lib/app/master_data/master_data_kinds.dart',
    );
  });

  test('every card opens a master-data editor named here', () {
    final unnamed = [
      for (final r in cards.keys)
        if (!_masterDataEditors.containsKey(r)) r,
    ];
    expect(
      unnamed,
      isEmpty,
      reason: 'name the screen in _masterDataEditors with what it edits',
    );
  });

  test(
    'every editor named here is a registered route that asks a permission',
    () {
      final registered = {for (final r in routeRules) r.pattern};
      for (final r in _masterDataEditors.keys) {
        expect(
          registered,
          contains(r),
          reason: '$r is not in route_classes.dart',
        );
        expect(
          routePermissions[r],
          isNotNull,
          reason: '$r asks no permission in route_access.dart',
        );
      }
    },
  );
}
