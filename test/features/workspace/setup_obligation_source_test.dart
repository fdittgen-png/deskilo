// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3283 — the country panel cites the law, never the reference store's notes
// for its maintainers: no code file name and no issue number reaches an
// owner, in the app or on the setup page (whose data comes from the same
// rows), and the citation itself stays word for word.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/setup_obligations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no source the reference carries shows a file name or an issue', () {
    final sources = <String>{};
    void walk(Object? x) {
      if (x is Map) {
        x.forEach(
          (k, v) => k == 'source' && v is String ? sources.add(v) : walk(v),
        );
      } else if (x is List) {
        x.forEach(walk);
      }
    }

    walk(
      jsonDecode(File('assets/instance/tax_reference.json').readAsStringSync()),
    );
    expect(sources, isNotEmpty);
    final leaking = [
      for (final s in sources)
        if (RegExp(r'\.dart\b|#\d').hasMatch(readableSource(s)))
          readableSource(s),
    ];
    expect(leaking, isEmpty);
  });

  test('the citation is kept, the note for maintainers goes', () {
    expect(
      readableSource(
        'einvoice_mandates.dart (#2358): Wachstumschancengesetz, '
        '§14 UStG',
      ),
      'Wachstumschancengesetz, §14 UStG',
    );
    expect(
      readableSource('#2362: the United States has no VAT'),
      'The United States has no VAT',
    );
    expect(
      readableSource('ELSTER UStVA: Kennzahlen 81, 86 (#2480)'),
      'ELSTER UStVA: Kennzahlen 81, 86',
    );
    expect(
      readableSource(
        'DATEV SKR04 10000 (the DATEV export, #2365). Not yet '
        'confirmed',
      ),
      'DATEV SKR04 10000 (the DATEV export). Not yet confirmed',
    );
  });

  test('the setup page reads the same clean rows', () {
    final page = File('web/setup_catalogue.js').readAsStringSync();
    final sources = RegExp(r'"source": "([^"]*)"').allMatches(page);
    expect(sources, isNotEmpty);
    for (final m in sources) {
      expect(m.group(1), isNot(matches(RegExp(r'\.dart\b|#\d'))));
    }
  });
}
