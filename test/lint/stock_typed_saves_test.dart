// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- no map crosses a stock port: a save takes its typed draft (StockPlaceDraft, StockDimension,
// SupplierMappingDraft, StockReorderPointDraft, ItemGroupDraft), which writes the body its server function reads. A
// `required Map<String, ...>` parameter in the stock domain, its data layer or its Demo is counted, and the count is 0.
import 'package:flutter_test/flutter_test.dart';
import 'lint_sources.dart';

/// The lines of [source] that take a map as a required parameter.
List<int> mapParameters(String source) => [
  for (final (i, line) in source.split('\n').indexed)
    if (RegExp(r'required Map<String,').hasMatch(line)) i + 1,
];

void main() {
  test('every stock save takes a typed draft, never a map', () {
    final files = [
      ...handWrittenDartFiles('lib/features/stock'),
      ...handWrittenDartFiles('lib/core/demo/data').where(
        (f) =>
            !f.path.substring('lib/core/demo/data/'.length).contains('/') &&
            RegExp(r'demo_(stock|item_group)').hasMatch(f.path),
      ),
    ];
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
