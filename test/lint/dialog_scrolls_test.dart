// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A dialog whose content is a Column must scroll: on a phone, with large text
// or a long explanation, a column in a plain AlertDialog spills over its own
// buttons (the reminder rules dialog did). `scrollable: true` is the cure.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('every AlertDialog with a Column as content is scrollable', () {
    final offenders = <String>[];
    for (final f in filesWithExtension('lib', '.dart', recursive: true)) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('content: Column(')) continue;
        for (var j = i - 1; j >= 0 && j > i - 30; j--) {
          if (!lines[j].contains('AlertDialog(')) continue;
          final block = lines.sublist(j, i + 1).join('\n');
          if (!block.contains('scrollable: true')) {
            offenders.add('${f.path}:${i + 1}');
          }
          break;
        }
      }
    }
    expect(offenders, isEmpty, reason: 'add `scrollable: true` to the dialog');
  });
}
