// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2598 — the generated budgets only fall: the tool lowers a number, drops
// an entry that reached its default and REFUSES a raise or an entry nobody
// allowed, and the lint failure names the command instead of a line to
// write by hand.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

BudgetActuals _tree({
  int parts = 3,
  Map<String, int> lines = const {},
  Map<String, int> setState = const {},
}) =>
    BudgetActuals(
      partOfFiles: parts,
      lines: lines,
      setState: setState,
      repositoryInWidgets: const {},
      pairBudget: const {},
    );

Budgets _held({
  int parts = 3,
  Map<String, int> fileLength = const {},
  Map<String, int> setState = const {},
}) =>
    Budgets(partOfFiles: parts, maps: {
      'fileLength': fileLength,
      'setState': setState,
      'repositoryInWidgets': {},
      'pairBudget': {},
    });

void main() {
  test('a file that shrank gets its length plus the headroom, never more '
      'than it had', () {
    final next = nextBudgets(
        _held(fileLength: {'lib/a.dart': 700, 'lib/b.dart': 530}),
        _tree(lines: {'lib/a.dart': 600, 'lib/b.dart': 525}));
    expect(next.refusals, isEmpty);
    expect(next.budgets.maps['fileLength'],
        {'lib/a.dart': 620, 'lib/b.dart': 530});
  });

  test('a file under the default leaves the block', () {
    final next = nextBudgets(
        _held(fileLength: {'lib/a.dart': 520}), _tree(lines: {'lib/a.dart': 480}));
    expect(next.budgets.maps['fileLength'], isEmpty);
  });

  test('a raise is refused, and so is an entry nobody allowed', () {
    final raise = nextBudgets(
        _held(fileLength: {'lib/a.dart': 600}), _tree(lines: {'lib/a.dart': 601}));
    expect(raise.refusals, hasLength(1));
    final fresh = nextBudgets(_held(), _tree(lines: {'lib/n.dart': 501}));
    expect(fresh.refusals, hasLength(1));
    final allowed = nextBudgets(_held(), _tree(lines: {'lib/n.dart': 501}),
        allowNew: {'fileLength:lib/n.dart'});
    expect(allowed.refusals, isEmpty);
    expect(allowed.budgets.maps['fileLength'], {'lib/n.dart': 521});
    expect(nextBudgets(_held(), _tree(parts: 4)).refusals, hasLength(1));
  });

  test('the failure for a fall names the command, for a raise it does not '
      'offer one', () {
    final fell = budgetFailures(
        _held(setState: {'lib/s.dart': 9}), _tree(setState: {'lib/s.dart': 7}));
    expect(fell.single, contains(budgetCommand));
    final grew = budgetFailures(
        _held(setState: {'lib/s.dart': 9}), _tree(setState: {'lib/s.dart': 10}));
    expect(grew.single, isNot(contains(budgetCommand)));
    expect(budgetFailures(_held(setState: {'lib/s.dart': 9}),
        _tree(setState: {'lib/s.dart': 9})), isEmpty);
  });

  test('the block renders sorted, a blank line between entries', () {
    final text = _held(fileLength: {'lib/b.dart': 2, 'lib/a.dart': 1}).render();
    expect(text.indexOf('lib/a.dart'), lessThan(text.indexOf('lib/b.dart')));
    expect(text, contains('"lib/a.dart": 1,\n\n      "lib/b.dart": 2'));
  });
}
