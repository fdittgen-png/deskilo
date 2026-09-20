// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1218 — a provider registers its dependencies BEFORE its first await.
//
// Seen on a device: "Cannot use the Ref of eventTrailProvider after it
// has been disposed." A trail is opened from a sheet and disposed the
// moment the sheet closes, so the `ref.watch` that sat on the far side
// of an await threw and the load ended in error instead of in data.
//
// `await ref.watch(x.future)` is the SAFE idiom and is not what this
// catches: the watch runs synchronously and registers the dependency
// before the await suspends. What is unsafe is a bare watch reached
// after an earlier await already gave the framework a chance to
// dispose — and the fix is always the same one line, because a watch
// is a registration and belongs where there is not yet anything to be
// disposed during.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no provider watches after an await', () {
    final offenders = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      // Comments out first: a line explaining this very rule contains
      // both words, and a scanner that reads prose reports the
      // explanation as the defect.
      final src = file
          .readAsStringSync()
          .split('\n')
          .map((line) {
            final at = line.indexOf('//');
            return at < 0 ? line : line.substring(0, at);
          })
          .join('\n');
      final signature = RegExp(
        r'^(?:Future|Stream)<[^\n]*> (\w+)\(\s*Ref ref',
        multiLine: true,
      );
      for (final m in signature.allMatches(src)) {
        final open = src.indexOf('{', m.end);
        if (open < 0) continue;
        var depth = 1;
        var i = open + 1;
        while (i < src.length && depth > 0) {
          if (src[i] == '{') depth++;
          if (src[i] == '}') depth--;
          i++;
        }
        final body = src.substring(open, i);
        for (final w in RegExp(r'\bref\.(watch|listen)\(').allMatches(body)) {
          const kAwait = 'await ';
          if (w.start >= kAwait.length &&
              body.startsWith(kAwait, w.start - kAwait.length)) {
            continue;
          }
          if (body.lastIndexOf(kAwait, w.start) >= 0) {
            offenders.add('${file.path}: ${m.group(1)}');
            break;
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'these register a dependency on the far side of an async gap, '
          'where a disposed Ref throws instead of loading. Hoist the '
          '`ref.watch` above the first await and read it from the local.',
    );
  });
}
