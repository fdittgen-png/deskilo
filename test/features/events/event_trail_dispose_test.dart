// SPDX-License-Identifier: 0BSD
//
// #1218 — "Cannot use the Ref of eventTrailProvider after it has been
// disposed."
//
// A decision trail is opened from a sheet and disposed the moment the
// sheet closes. The provider awaited the workspace first and only then
// watched its repository, so when the sheet went away mid-flight the
// `ref.watch` on the far side of the gap threw and the load ended in
// error instead of in data.
//
// The repository is a dependency REGISTRATION, so it belongs before the
// gap — where there is not yet anything to be disposed during.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no provider in event_providers.dart watches after an await', () {
    // Comments out first: a line explaining why a watch must not follow
    // an await contains both words, and a scanner that reads prose
    // reports the explanation as the defect.
    final src = File('lib/features/events/providers/event_providers.dart')
        .readAsStringSync()
        .split('\n')
        .map((line) {
          final at = line.indexOf('//');
          return at < 0 ? line : line.substring(0, at);
        })
        .join('\n');

    final offenders = <String>[];
    final signature =
        RegExp(r'^(?:Future|Stream)<[^\n]*> (\w+)\(\s*Ref ref', multiLine: true);
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
      // `await ref.watch(x.future)` is the safe idiom: the watch runs
      // synchronously and registers the dependency BEFORE the await
      // suspends. What is unsafe is a BARE watch reached after an
      // earlier await already gave the framework a chance to dispose.
      for (final w
          in RegExp(r'\bref\.(watch|listen)\(').allMatches(body)) {
        const kAwait = 'await ';
        final awaited = w.start >= kAwait.length &&
            body.startsWith(kAwait, w.start - kAwait.length);
        if (awaited) continue;
        if (body.lastIndexOf(kAwait, w.start) >= 0) {
          offenders.add(m.group(1)!);
          break;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these register a dependency on the far side of an async gap, '
          'where a disposed Ref throws instead of loading. Hoist the '
          '`ref.watch` above the first await.',
    );
  });
}
