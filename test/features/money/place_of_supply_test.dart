// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — the place-of-supply rule exists twice: `supplyVatCategory` in
// Dart (the member screen's explainer) and `public.supply_vat_category`
// in SQL (what create_invoice applies). This file keeps them one rule:
// every `supply_vat_category(...)` case the pgTAP file 167 runs against
// the database is parsed here and run through the Dart twin, expecting
// the same answer. A case added on one side is a case on both.
//
// The EU set is pinned the same way: the member rows `is_eu_country` reads
// (#2478: the seed of the tax reference store, no array in the function any
// more), the questionnaire's EU set and `euMemberStates` list the same 27
// codes, with Greece as GR.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/place_of_supply.dart';
import 'package:deskilo/core/vat/supply_class.dart';
import 'package:deskilo/core/vat/vat_treatment.dart';
import 'package:flutter_test/flutter_test.dart';

final _case = RegExp(
  r"supply_vat_category\('([a-z_]*)','([a-z]*)','([a-z_]*)','([A-Za-z]*)',"
  r"'([A-Za-z]*)','([a-z]*)',(true|false)\), '([A-Z]*)'",
);

Set<String> _codes(String text) =>
    RegExp(r"'([A-Z]{2})'").allMatches(text).map((m) => m.group(1)!).toSet();

/// The countries of the `eu_member` rows the SQL functions read: every
/// migration that seeds the store, and the bundled copy, agree on them.
Set<String> _memberRows() {
  final rows = (jsonDecode(File('assets/instance/tax_reference.json').readAsStringSync())
          as List)
      .cast<Map<String, dynamic>>();
  return {
    for (final r in rows)
      if (r['domain'] == 'eu_member' && r['key'] == 'member') r['country'] as String,
  };
}

void main() {
  test('every SQL case of the rule gives the same answer in Dart', () {
    final sql = File('supabase/tests/database/167_place_of_supply.sql')
        .readAsStringSync();
    final cases = _case.allMatches(sql).toList();
    expect(
      cases.length,
      greaterThanOrEqualTo(20),
      reason: 'the pgTAP file carries the twin cases',
    );
    for (final m in cases) {
      final got = supplyVatCategory(
        treatment: VatTreatment.fromWire(m.group(1)),
        supply: SupplyClass.fromWire(m.group(2)),
        sellerVatRegistered: m.group(3) == 'vat_registered',
        sellerCountry: m.group(4)!,
        buyerCountry: m.group(5)!,
        buyerCapacity: m.group(6)!,
        reverseChargeOn: m.group(7) == 'true',
      );
      expect(got, m.group(8), reason: m.group(0));
    }
  });

  test('one EU set: SQL, the questionnaire and Dart list the same 27', () {
    final sqlSet = _memberRows();
    expect(sqlSet, euMemberStates);
    final html = File('web/setup.html').readAsStringSync();
    final eu = RegExp(r'const EU=new Set\(\[([^\]]*)\]\)').firstMatch(html);
    expect(eu, isNotNull);
    expect(_codes(eu!.group(1)!), euMemberStates);
    expect(euMemberStates, hasLength(27));
    expect(euMemberStates, isNot(contains('EL')));
  });

  test('EL is accepted on input and normalised to GR', () {
    expect(euCountryCode(' el '), 'GR');
    expect(isEuCountry('EL'), isTrue);
    expect(isEuCountry('gb'), isFalse);
  });
}
