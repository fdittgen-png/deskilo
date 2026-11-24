// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4422 — a route path is a symbol. A path spelled inline where a page is
// opened (`context.go('/…')`, `context.push('/…')`, `location: '/…'`)
// survives a rename of the route and opens nothing; `Routes.<name>` in
// lib/core/navigation/routes.dart is checked against the live router by
// route_registry_test. The inline spellings that remain are budgeted per
// file in docs/design/CODE_HEALTH_BASELINE.json (`inlineRoute`) and only
// fall.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health_budgets.dart';

void main() {
  test('no lib/ file opens a page by an inline path beyond its budget', () {
    final problems = budgetFailures(
      Budgets.load(),
      measureBudgetActuals(),
      only: 'inlineRoute',
    );
    expect(
      problems,
      isEmpty,
      reason:
          '${problems.join('\n')}\n\n'
          'Name the page by its symbol in lib/core/navigation/routes.dart '
          '(Routes.<name>, or a builder for a path with a parameter) '
          'instead of writing its path; add the symbol there when the '
          'route has none.',
    );
  });

  test('an inline path is counted across a line break, not in a comment', () {
    const source = '''
      onTap: () => context.push('/settings'),
      onTap: () => context.go(
        '/members/\$id',
      ),
      onTap: () => context.push<bool>('/res/1'),
      // context.go('/settings') in a comment
      const ShellNav('messages', location: '/messages'),
      onTap: () => context.push(Routes.settings),
''';
    expect(inlineRouteCountOf(source), 4);
  });
}
