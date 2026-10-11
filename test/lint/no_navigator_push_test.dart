// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — a page has a path. A `Navigator.push` of a `MaterialPageRoute`
// builds a page the router, the route policy and the route registry never
// see; on the web the back stack then diverges from the address bar. A
// page opened over another screen is a `PageSpec` (or `openLocation` for a
// route the router already has), both in lib/core/navigation/page_spec.dart,
// the one file that may push a page directly — for a widget pumped without
// a router. Dialogs and sheets (`showDialog`, `showModalBottomSheet`) are
// not pages and stay as they are.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no Navigator.push of a page outside page_spec.dart', () {
    final push = RegExp(
      r'Navigator\.(of\([^)]*\)\s*\.)?push(Replacement|AndRemoveUntil)?\b',
    );
    final hits = scanLines(
      handWrittenDartFiles('lib')
          .where((f) => !f.path.endsWith('core/navigation/page_spec.dart')),
      push.hasMatch,
    );
    expect(
      hits,
      isEmpty,
      reason:
          'open a page through a PageSpec or openLocation '
          '(lib/core/navigation/page_spec.dart):\n${hits.join('\n')}',
    );
  });
}
