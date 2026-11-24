// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4414 -- an exception's own text never reaches a screen: it is English,
// it can carry a server's internals, and it tells a member nothing they can
// act on. A failed read is shown by `ReadFailureBanner` / `AsyncReadBody`
// (lib/core/ui/async_read_body.dart), which says whether the connection,
// the access or the read failed and offers Try again. Held at zero.
import 'dart:io';

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

/// An error branch of a read: `AsyncError(`, a `.when(error: (e, _) =>`, a
/// snapshot's `.hasError`.
final _errorBranch = RegExp(
  r'AsyncError\(|\berror:\s*\(\s*\w+\s*,|\.hasError\b',
);

/// The shared views a failed read is shown with.
final _sharedView = RegExp(
  r'ReadFailureBanner|AsyncReadBody|ReadsAnswer|StockReadFailed',
);

/// The error branches of [source] whose next lines show no shared view.
int ownErrorBranches(String source) {
  final lines = source.split('\n');
  var n = 0;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('//')) continue;
    if (!_errorBranch.hasMatch(lines[i])) continue;
    final next = lines.sublist(i, (i + 4).clamp(0, lines.length)).join('\n');
    if (!_sharedView.hasMatch(next)) n++;
  }
  return n;
}

/// #4414 -- error branches of presentation (and lib/app) that word a failed
/// read their own way, per feature, measured on 24 Nov 2026 after stock's
/// sweep. Only falls: a branch moved onto the shared view lowers its feature.
const _ownErrorBranchCeiling = <String, int>{
  'app': 19,
  'auth': 2,
  'calendar': 5,
  'directory': 25,
  'editor': 2,
  'events': 2,
  'kiosk': 1,
  'mcp': 18,
  'me': 20,
  'members': 4,
  'money': 104,
  'plan': 2,
  'profile': 3,
  'reservations': 11,
  'stock': 14,
  'workspace': 37,
};

String _featureOf(String path) {
  final p = path.replaceAll(r'\', '/');
  final feature = RegExp(r'lib/features/(\w+)/').firstMatch(p);
  if (feature != null) return feature.group(1)!;
  return p.startsWith('lib/app/') ? 'app' : 'core';
}

void main() {
  test('#4414 -- an error branch that words a read its own way is found', () {
    expect(ownErrorBranches('AsyncError() => Text(l10n.stockReadFailed),'), 1);
    expect(
      ownErrorBranches(
        'AsyncError(:final error) =>\n    ReadFailureBanner(error: error, onRetry: r),',
      ),
      0,
    );
    expect(ownErrorBranches('error: (e, _) => StockReadFailed(keyName: k,'), 0);
  });

  test(
    '#4414 -- error branches off the shared view only fall, per feature',
    () {
      final actual = <String, int>{};
      for (final f in handWrittenDartFiles('lib')) {
        final p = f.path.replaceAll(r'\', '/');
        if (!p.contains('/presentation/') && !p.startsWith('lib/app/')) {
          continue;
        }
        final n = ownErrorBranches(File(p).readAsStringSync());
        if (n > 0) {
          actual.update(_featureOf(p), (v) => v + n, ifAbsent: () => n);
        }
      }
      final changed = [
        for (final k in {
          ...actual.keys,
          ..._ownErrorBranchCeiling.keys,
        }.toList()..sort())
          if ((actual[k] ?? 0) != (_ownErrorBranchCeiling[k] ?? 0))
            '$k: ${actual[k] ?? 0} (ceiling ${_ownErrorBranchCeiling[k] ?? 0})',
      ];
      expect(
        changed,
        isEmpty,
        reason:
            'show a failed read with ReadFailureBanner / AsyncReadBody; '
            'when a feature fell, lower its ceiling.\n$actual',
      );
    },
  );

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
