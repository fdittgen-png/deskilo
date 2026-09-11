// SPDX-License-Identifier: 0BSD
//
// #1148 — `Enum.values.byName` throws on a value it does not know, and a
// throw inside a row mapper empties the whole list on an older client.
// Data layers read enums through `enumOr`, which traces the unknown and
// keeps the row.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no data layer calls Enum.values.byName', () {
    final hits = scanLines(
      handWrittenDartFiles('lib').where((f) => f.path.contains('/data/')),
      (line) => line.contains('.values.byName('),
    );
    expect(hits, isEmpty,
        reason: 'read it through enumOr(values, raw, fallback, area: …) '
            '(lib/core/data/enum_wire.dart):\n${hits.join('\n')}');
  });
}
