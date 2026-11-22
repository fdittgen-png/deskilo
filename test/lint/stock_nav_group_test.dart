// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- the Stock group of the navigation: directly below Purchases, holding
// every stock and item page, and no stock or item route is placed in another
// group. A page that appears under another group, or a Stock entry that drifts
// away from Purchases, fails here with the sentence that says which.
import 'dart:io';

import 'package:deskilo/app/route_classes.dart';
import 'package:flutter_test/flutter_test.dart';

/// The group ids of `navGroupsOf`, in menu order: every `pick('<id>'` or
/// `NavGroup('<id>'` at the top of the list.
List<String> _groupOrder(String source) => [
  for (final m in RegExp(r"(?:pick\(\s*|NavGroup\(\s*)'(\w+)',\s*(?:labels\.|\w)").allMatches(source))
    m.group(1)!,
];

void main() {
  final groups = File('lib/app/shell/shell_nav_groups.dart').readAsStringSync();

  test('the Stock group sits directly below Purchases', () {
    final order = _groupOrder(groups).where((id) => id != 'cash' && id != 'accounting').toList();
    final purchases = order.indexOf('purchases');
    expect(purchases, isNonNegative);
    expect(order.indexOf('stock'), purchases + 1, reason: 'Stock is the group directly after purchases: $order');
  });

  test('no stock or item route is placed outside the Stock group', () {
    final stray = [
      for (final r in routeRules)
        if ((r.pattern == '/stock' || r.pattern.startsWith('/stock/')) && !(r.place ?? '').startsWith('drawer-stock'))
          '${r.pattern} -> ${r.place}',
    ];
    expect(stray, isEmpty, reason: 'a /stock route whose place is outside the Stock group');
    final foreign = [
      for (final r in routeRules)
        if (!(r.pattern == '/stock' || r.pattern.startsWith('/stock/')) && (r.place ?? '').startsWith('drawer-stock'))
          '${r.pattern} -> ${r.place}',
    ];
    expect(foreign, isEmpty, reason: 'a page outside /stock placed in the Stock group');
  });

  test('every stock entry is picked by the Stock group and by no other', () {
    final stock = RegExp(r"pick\('stock',.*?\}\)", dotAll: true).firstMatch(groups)!.group(0)!;
    final inStock = RegExp(r"'(drawer-stock[\w-]*)'").allMatches(stock).map((m) => m.group(1)!).toSet();
    final everywhere = RegExp(r"'(drawer-stock[\w-]*)'").allMatches(groups).map((m) => m.group(1)!).toList();
    expect(inStock, isNotEmpty);
    expect(everywhere.length, inStock.length, reason: 'a stock entry is also picked by another group');
    final entries = File('lib/app/shell/shell_stock_entries.dart').readAsStringSync();
    final defined = RegExp(r"DrawerEntry\(\s*'(drawer-stock[\w-]*)'").allMatches(entries).map((m) => m.group(1)!).toSet();
    expect(inStock, defined, reason: 'the entries the Stock group picks are the ones the stock entries define');
  });
}
