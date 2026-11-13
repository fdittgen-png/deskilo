// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3622 — the web size budget has ONE home, tool/web/size_budget.json, and
// the workflow runs the checker after the build it already makes. A number
// without its two sentences (what it measures, how to raise it) is a number
// nobody dares to touch or everybody raises; the workflow must not carry
// the numbers as literals nor build a second time for the check.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final budgets =
      (jsonDecode(File('tool/web/size_budget.json').readAsStringSync())
              as Map<String, dynamic>)['budgets']
          as Map<String, dynamic>;

  test('every budget names what it measures and how to raise it', () {
    expect(budgets, isNotEmpty);
    for (final entry in budgets.entries) {
      final rule = entry.value as Map<String, dynamic>;
      expect(rule['max'], isA<int>(), reason: entry.key);
      expect(
        rule['max'] as int,
        greaterThanOrEqualTo(rule['measured'] as int),
        reason: '${entry.key}: the ceiling sits at or above the measured value',
      );
      expect(
        (rule['measures'] as String).length,
        greaterThan(40),
        reason: entry.key,
      );
      expect(
        (rule['raise'] as String).length,
        greaterThan(20),
        reason: entry.key,
      );
    }
  });

  test('the workflow checks the budget on the existing build', () {
    final yml = File('.github/workflows/web.yml').readAsStringSync();
    expect(yml, contains('node tool/web/size_budget_check.mjs'));
    expect(
      RegExp('flutter build web').allMatches(yml).length,
      1,
      reason: 'the budget reuses the one build, it adds none',
    );
    for (final rule in budgets.values) {
      expect(
        yml,
        isNot(contains('${(rule as Map<String, dynamic>)['max']}')),
        reason: 'the numbers live in size_budget.json only',
      );
    }
  });
}
