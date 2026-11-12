// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 — every route shown on the desk declares its place in the business's
// navigation (route_classes.dart), and that place is an entry or a group the
// navigation already has: the desk selects it and names it in the top bar
// and the window title. A place nobody offers would select nothing forever;
// a desk route without one would leave the navigation blank on its page.
import 'dart:io';

import 'package:deskilo/app/route_classes.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keys and group ids the navigation's sources declare.
Set<String> _knownPlaces() {
  final entries = File('lib/app/shell/shell_drawer_entries.dart')
      .readAsStringSync();
  final groups = File('lib/app/shell/shell_nav_groups.dart').readAsStringSync();
  final destinations = File('lib/app/shell/shell_destinations.dart')
      .readAsStringSync();
  return {
    for (final m in RegExp(r"'(drawer-[a-z-]+)'").allMatches(entries))
      m.group(1)!,
    // The tab entries: `drawer-tab-<branch>` for each ShellBranch constant.
    for (final m in RegExp(
      r'static const int \w+ = (\d+);',
    ).allMatches(destinations))
      'drawer-tab-${m.group(1)}',
    // The destinations opened by location: `drawer-nav-<id>`.
    for (final m in RegExp(
      r"ShellNav\(\s*'(\w+)',[^)]*location:",
    ).allMatches(destinations))
      'drawer-nav-${m.group(1)}',
    // The groups: `NavGroup('id'` and `pick('id'`.
    for (final m in RegExp(r"(?:NavGroup|pick)\(\s*'(\w+)'").allMatches(groups))
      m.group(1)!,
  };
}

void main() {
  test('every desk route declares a place the navigation has', () {
    final known = _knownPlaces();
    expect(
      known,
      containsAll(['drawer-members', 'drawer-tab-3', 'reporting']),
      reason: 'the sources moved: update the patterns above',
    );
    final missing = [
      for (final r in routeRules)
        if (r.chrome == RouteChrome.desk && r.place == null) r.pattern,
    ];
    expect(missing, isEmpty, reason: 'declare place: in route_classes.dart');
    final unknown = [
      for (final r in routeRules)
        if (r.place != null && !known.contains(r.place))
          '${r.pattern} → ${r.place}',
    ];
    expect(
      unknown,
      isEmpty,
      reason: 'a place is an entry key or a group id that exists today',
    );
  });

  test('a place outside the desk is a mistake', () {
    final stray = [
      for (final r in routeRules)
        if (r.place != null && r.chrome != RouteChrome.desk) r.pattern,
    ];
    expect(stray, isEmpty);
  });
}
