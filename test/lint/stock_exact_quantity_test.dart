// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4393 -- a stock quantity is an `ExactQuantity` from the field to the RPC
// parameter, in the app and in the Demo. No binary float reads, holds or sums
// a quantity there: `double.parse` / `double.tryParse`, a `double` typed
// quantity, and a sum started at `0.0` are refused. The purchase order's own
// numbers (#4177) enter stock through `exactOfReceived`, once.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _patterns = <String, RegExp>{
  'double.parse': RegExp(r'\bdouble\.(try)?[Pp]arse\('),
  'a double quantity': RegExp(r'\bdouble\??\s+(received|putAway|remaining|qty|quantity|delivered)\b'),
  'a float sum': RegExp(r'\.fold(<double>)?\(\s*0(\.0)?\s*,'),
};

Iterable<File> _files() => [
  ...handWrittenDartFiles('lib/features/stock'),
  ...handWrittenDartFiles('lib/core/demo/data').where((f) => f.uri.pathSegments.last.startsWith('demo_stock_')),
];

/// The offences of [source], as `pattern: line`.
List<String> floatQuantities(String source) => [
  for (final (i, line) in source.split('\n').indexed)
    if (!line.trimLeft().startsWith('//'))
      for (final MapEntry(key: name, value: re) in _patterns.entries)
        if (re.hasMatch(line)) '$name: ${i + 1}',
];

void main() {
  test('no stock or Demo stock file holds a quantity in a binary float', () {
    final found = [
      for (final f in _files())
        for (final hit in floatQuantities(f.readAsStringSync())) '${f.path} $hit',
    ];
    expect(found, isEmpty, reason: 'read and sum quantities as ExactQuantity (#4393)');
  });

  test('the rule sees each shape', () {
    expect(floatQuantities('final q = double.tryParse(text);'), ['double.parse: 1']);
    expect(floatQuantities('  final double received;'), ['a double quantity: 1']);
    expect(floatQuantities('xs.fold(0.0, (s, x) => s + x)'), ['a float sum: 1']);
    expect(floatQuantities('xs.fold<double>(0, (s, x) => s + x)'), ['a float sum: 1']);
    expect(floatQuantities('// double.parse is refused here'), isEmpty);
  });
}
