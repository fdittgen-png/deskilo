// SPDX-License-Identifier: 0BSD
//
// #1150 — `AppFormat.time()` is the one place that honours the member's
// clock (12/24h) and time-zone mode. A raw `DateFormat.Hm()` in a widget
// shows 14:30 to somebody who chose a 12-hour clock, and the device's
// zone to somebody who chose the workspace's.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('presentation never formats a time with DateFormat directly', () {
    final hits = scanLines(
      handWrittenDartFiles('lib/features').where((f) => f.path.contains('/presentation/')),
      (line) => line.contains('DateFormat.Hm(') || line.contains('DateFormat.jm('),
    );
    expect(hits, isEmpty,
        reason: 'use AppFormat.time() — ref.watch(appFormatProvider) or '
            'AppFormat.read(context):\n${hits.join('\n')}');
  });
}
