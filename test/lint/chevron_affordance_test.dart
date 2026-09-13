// SPDX-License-Identifier: 0BSD
//
// #1182 — the trailing chevron means "this opens something". The rule is
// in docs/AGENT_RULES.md; this pins the two rows the 2026-09-13 review
// found on the wrong side of it, so neither drifts back.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('a row that PRODUCES a file carries no chevron', () {
    final src = _read(
        'lib/features/workspace/presentation/screens/workspace_settings_screen.dart');
    final report = src.indexOf('_exportWorkspaceReport');
    expect(report, greaterThan(0));
    // The 400 characters before the handler are its own ListTile.
    final tile = src.substring(report - 400, report);
    expect(tile, isNot(contains('Icons.chevron_right')),
        reason: 'the workspace report is produced, not navigated to — its '
            'five file-making siblings carry no chevron either');
  });

  test('a row that OPENS A SHEET carries one', () {
    final src =
        _read('lib/features/money/presentation/widgets/negotiation_card.dart');
    final start = src.indexOf('class MemberNegotiationTile');
    expect(start, greaterThan(0));
    final tile = src.substring(start);
    expect(tile, contains('showPriceNegotiationSheet('));
    expect(tile, contains('Icons.chevron_right'),
        reason: 'its two siblings in the Billing card are _ManageTiles, '
            'which carry one');
  });

  test('the rule is written down where the next person will look', () {
    expect(_read('docs/AGENT_RULES.md'),
        contains('The trailing chevron means one thing'));
  });
}
