// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- the Dart twin of `invoice_region_missing` (0792), for the Demo. It is
// bound to the server's rule over the very data the server holds: for every
// country of `postalRegionRulesJson()` (what `postal_region_rules()` carries)
// and each of its three values, the twin answers what the SQL's reading of that
// JSON answers. pgTAP 446 pins the SQL side on the server.
import 'dart:convert';

import 'package:deskilo/core/jurisdiction/installed_postal_layouts.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _missing(
  String seller,
  String sellerRegion,
  String buyer,
  String buyerRegion,
) => invoiceRegionMissing(
  sellerCountry: seller,
  sellerRegion: sellerRegion,
  buyerCountry: buyer,
  buyerRegion: buyerRegion,
);

/// The SQL of `invoice_region_missing`, read over the generated JSON.
List<String> _sqlReading(
  Map<String, dynamic> rules,
  String seller,
  String sellerRegion,
  String buyer,
  String buyerRegion,
) {
  final invoice = (rules[seller] as Map?)?['invoice'] as String? ?? 'none';
  final buyerCountry = buyer.isEmpty ? seller : buyer;
  return [
    if ((invoice == 'seller' || invoice == 'everyParty') &&
        sellerRegion.isEmpty)
      'seller_region',
    if (invoice == 'everyParty' &&
        buyerCountry == seller &&
        buyerRegion.isEmpty)
      'buyer_region',
  ];
}

void main() {
  test('the twin answers what the server\'s rule answers, for every country of its data', () {
    final rules = jsonDecode(postalRegionRulesJson()) as Map<String, dynamic>;
    expect(rules.values.map((r) => (r as Map)['invoice']).toSet(), {
      'none',
      'seller',
      'everyParty',
    }, reason: 'the data holds all three values');
    for (final country in [...rules.keys, 'FR', 'ZZ']) {
      for (final sellerRegion in ['', 'X1']) {
        for (final buyer in [country, '', 'ZZ']) {
          for (final buyerRegion in ['', 'X2']) {
            expect(
              _missing(country, sellerRegion, buyer, buyerRegion),
              _sqlReading(rules, country, sellerRegion, buyer, buyerRegion),
              reason: '$country/$sellerRegion -> $buyer/$buyerRegion',
            );
          }
        }
      }
    }
  });

  test('Italy asks every party in the seller\'s country for its province', () {
    expect(_missing('IT', '', 'IT', ''), ['seller_region', 'buyer_region']);
    expect(_missing('IT', 'MI', 'IT', 'TO'), isEmpty);
  });

  test(
    'a customer abroad is never refused; one without a country is domestic',
    () {
      expect(_missing('IT', 'MI', 'CH', ''), isEmpty);
      expect(_missing('IT', 'MI', '', ''), ['buyer_region']);
    },
  );

  test('the US asks the seller\'s own state only', () {
    expect(_missing('US', '', 'US', ''), ['seller_region']);
    expect(_missing('US', 'MA', 'US', ''), isEmpty);
  });

  test('a country whose invoices do not ask refuses nothing', () {
    expect(_missing('FR', '', 'FR', ''), isEmpty);
    expect(_missing('ES', '', 'ES', ''), isEmpty);
  });
}
