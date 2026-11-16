// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- the server's region facts ARE the app's postal layouts. The issue
// check refuses an invoice whose party lacks a region its country's invoices
// require, and reads which countries those are from
// `public.postal_region_rules()`. A hand-typed copy would drift the first time
// a layout changed, so the SQL is generated
// (`dart run tool/build_postal_region_rules_sql.dart`) and this test requires
// the latest migration defining it to carry exactly that text.
import 'dart:io';

import 'package:deskilo/core/jurisdiction/installed_postal_layouts.dart';
import 'package:flutter_test/flutter_test.dart';

const _definition = 'create or replace function public.postal_region_rules()';

void main() {
  test('the latest migration carries the region facts the layouts generate', () {
    final files =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final latest = files.reversed
        .map((f) => (f, f.readAsStringSync()))
        .firstWhere(
          (e) => e.$2.contains(_definition),
          orElse: () => throw StateError('no migration defines it'),
        );
    expect(
      latest.$2.contains(postalRegionRulesSql()),
      isTrue,
      reason:
          '${latest.$1.uri.pathSegments.last} is not what the layouts generate: '
          'run dart run tool/build_postal_region_rules_sql.dart into a new migration',
    );
  });

  test('a country with a region states both of its facts', () {
    final rules = postalRegionRulesJson();
    expect(rules, contains('"IT":{"form":true,"invoice":"everyParty"}'));
    expect(rules, contains('"RO":{"form":true,"invoice":"everyParty"}'));
    expect(rules, contains('"ES":{"form":false,"invoice":"none"}'));
    expect(rules, contains('"US":{"form":true,"invoice":"seller"}'));
    expect(rules, isNot(contains('"FR"')), reason: 'no region field, no fact');
  });
}
