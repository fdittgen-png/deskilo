// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2356 (item 2) — the VAT regime has three wire values, and three places
// spell them: the database constraint, the Dart enum and the setup page's
// export. The page once exported 'registered', which the database refuses
// and the app read as "not subject" (#2331). This pins all three together.
import 'dart:io';

import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the database, the app and the setup page spell the regime alike', () {
    final contract = File('assets/instance/contract.txt').readAsLinesSync();
    final check = contract.singleWhere(
      (l) => l.startsWith('constraint workspaces.workspaces_vat_regime_check '),
    );
    final sql = RegExp(r"'(\w+)'::text")
        .allMatches(check)
        .map((m) => m.group(1)!)
        .toSet();

    final dart = {for (final r in VatRegime.values) vatRegimeWire(r)};
    expect(dart, sql);
    for (final wire in sql) {
      expect(vatRegimeWire(vatRegimeFromWire(wire)), wire, reason: wire);
    }

    final html = File('web/setup.html').readAsStringSync();
    final export = RegExp(
      r"vat_regime:\(\{([^}]*)\}\)\[S\.vatRegime\]\|\|'(\w+)'",
    ).firstMatch(html);
    expect(
      export,
      isNotNull,
      reason: 'the page exports vat_regime through one map',
    );
    final mapped = RegExp(r"(\w+):'(\w+)'").allMatches(export!.group(1)!);
    final page = {for (final m in mapped) m.group(2)!, export.group(2)!};
    expect(page, sql);
    // Every answer the page offers maps to one of them.
    final offered = RegExp(r"'vatRegime',\[\[([^\n]*?)\]\],").firstMatch(html);
    expect(offered, isNotNull);
    final answers = RegExp(r"'(\w+)',T\(")
        .allMatches(offered!.group(1)!)
        .map((m) => m.group(1)!);
    final keys = {for (final m in mapped) m.group(1)!};
    for (final a in answers) {
      expect(keys.contains(a) || a == export.group(2), isTrue, reason: a);
    }
  });
}
