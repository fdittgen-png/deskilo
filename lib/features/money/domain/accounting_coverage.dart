// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the coverage table of the accounting target registry, as
// docs/domain/ACCOUNTING_EXPORTS.md carries it between its generated markers
// (`dart run tool/build_accounting_coverage.dart`; the drift test fails when
// the document and the registry disagree).
import 'package:meta/meta.dart';

import 'accounting_format.dart';

const _begin =
    '<!-- BEGIN GENERATED TARGETS (dart run tool/build_accounting_coverage.dart) -->';
const _end = '<!-- END GENERATED TARGETS -->';

/// One row per target, in registry order.
@visibleForTesting
String accountingCoverageTable() {
  String cell(String s) => s.replaceAll('|', r'\|');
  final rows = [
    '| target | product | transport | payload | countries | qualification | specification |',
    '|---|---|---|---|---|---|---|',
    for (final t in accountingTargets)
      '| `${t.id}` | ${cell('${t.vendor} · ${t.product} · ${t.edition}')} '
          '| ${t.transport.name} | ${t.payload.name} '
          '| ${t.countries.isEmpty ? 'everywhere' : (t.countries.toList()..sort()).join(', ')} '
          '| ${t.capability.state.name} '
          '| ${t.capability.specification.isEmpty ? 'not named yet' : cell(t.capability.specification)} |',
  ];
  return rows.join('\n');
}

/// [document] with its generated block replaced by the current table.
String withAccountingCoverage(String document) {
  final begin = document.indexOf(_begin);
  final end = document.indexOf(_end);
  if (begin < 0 || end < begin) {
    throw StateError('the generated markers are missing');
  }
  return '${document.substring(0, begin + _begin.length)}\n'
      '${accountingCoverageTable()}\n'
      '${document.substring(end)}';
}
