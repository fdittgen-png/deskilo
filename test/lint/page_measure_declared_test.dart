// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3604 — the route table is the only place a page's measure is declared
// (route_classes.dart, `measure:`); the frame applies it. A screen under
// lib/features that wraps itself in a WorkArea or a ReadingColumn would give
// itself a measure its route does not say, and draw differently on the desk
// and off it. A FormColumn inside a page (a form section in a work page)
// stays free.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _selfMeasure = RegExp(r'\b(WorkArea|ReadingColumn)\(');

/// The files of [sources] that give themselves a page measure.
List<String> selfMeasured(Map<String, String> sources) => [
  for (final e in sources.entries)
    if (_selfMeasure.hasMatch(e.value)) e.key,
];

void main() {
  test('a planted screen that wraps itself in a WorkArea is found', () {
    expect(
      selfMeasured({
        'lib/features/a.dart': 'Widget build(c) => WorkArea(child: body);',
        'lib/features/b.dart': 'Widget build(c) => FormColumn(child: form);',
      }),
      ['lib/features/a.dart'],
    );
  });

  test('no screen gives itself a page measure', () {
    final sources = {
      for (final f in handWrittenDartFiles('lib/features'))
        f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
    };
    expect(
      selfMeasured(sources),
      isEmpty,
      reason: 'declare `measure:` on the route in lib/app/route_classes.dart',
    );
  });
}
