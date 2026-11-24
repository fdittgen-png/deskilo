// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- no map crosses a stock port: a save takes its typed draft (StockPlaceDraft, StockDimension,
// SupplierMappingDraft, StockReorderPointDraft, ItemGroupDraft), which writes the body its server function reads. A
// `required Map<String, ...>` parameter in the stock domain, its data layer or its Demo is counted, and the count is 0.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The lines of [source] that take a map as a required parameter.
List<int> mapParameters(String source) => [
  for (final (i, line) in source.split('\n').indexed)
    if (RegExp(r'required Map<String,').hasMatch(line)) i + 1,
];

void main() {
  test('every stock save takes a typed draft, never a map', () {
    final files = [
      ...Directory('lib/features/stock')
          .listSync(recursive: true)
          .whereType<File>(),
      ...Directory('lib/core/demo/data')
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'demo_(stock|item_group)').hasMatch(f.path)),
    ].where((f) => f.path.endsWith('.dart'));
    final hits = [
      for (final f in files)
        for (final line in mapParameters(f.readAsStringSync()))
          '${f.path}:$line',
    ];
    expect(
      hits,
      isEmpty,
      reason: 'take a typed draft with toJson instead:\n${hits.join('\n')}',
    );
  });

  test('the check sees a map parameter and not a draft', () {
    expect(
      mapParameters(
        'Future<void> save(String ws, {required Map<String, Object?> body});',
      ),
      [1],
    );
    expect(
      mapParameters(
        'Future<void> save(String ws, {required ItemGroupDraft body});',
      ),
      isEmpty,
    );
  });
}
