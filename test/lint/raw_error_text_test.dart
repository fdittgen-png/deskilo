// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4414 -- an exception's own text never reaches a screen: it is English,
// it can carry a server's internals, and it tells a member nothing they can
// act on. A failed read is shown by `ReadFailureBanner` / `AsyncReadBody`
// (lib/core/ui/async_read_body.dart), which says whether the connection,
// the access or the read failed and offers Try again. Held at zero.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// `Text(error.toString())`, `Text(snapshot.error.toString())`,
/// `Text('$error')`, `Text('${e}')` and their kin.
final _rawErrorText = RegExp(
  r'''\bText\(\s*(?:[\w.]*\b(?:error|err|e)[!?]?\.toString\(\)|['"]\$\{?(?:[\w.]*\.)?(?:error|err|e)\}?['"])''',
);

List<int> rawErrorTextLines(String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (!lines[i].trimLeft().startsWith('//') &&
          _rawErrorText.hasMatch(lines[i]))
        i + 1,
  ];
}

void main() {
  test('the detector sees each spelling and leaves the worded view alone', () {
    for (final planted in [
      'AsyncError(:final error) => Text(error.toString()),',
      'return Text(snapshot.error.toString());',
      "child: Text('\$error'),",
      "child: Text('\${e}'),",
      'Text(err!.toString())',
    ]) {
      expect(rawErrorTextLines(planted), [1], reason: planted);
    }
    for (final fine in [
      'AsyncError(:final error) => ReadFailureBanner(error: error, onRetry: r),',
      'Text(l10n.readStateFailed)',
      'Text(errorCount.toString())',
      '// Text(error.toString()) was the old way',
    ]) {
      expect(rawErrorTextLines(fine), isEmpty, reason: fine);
    }
  });

  test('no screen shows an exception as text', () {
    final hits = [
      for (final file in handWrittenDartFiles('lib'))
        for (final line in rawErrorTextLines(file.readAsStringSync()))
          '${file.path}:$line',
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'show a failed read with ReadFailureBanner or AsyncReadBody '
          '(lib/core/ui/async_read_body.dart):\n${hits.join('\n')}',
    );
  });
}
