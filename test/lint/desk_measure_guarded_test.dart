// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3874 — a route measured for the desk (any measure but `framed`) is a page
// someone has looked at on the desk: a desk guard (a guard of `test/ux` but
// the phones') opens it, or it is named below with the issue that will
// guard it. A measure given without a guard no longer counts as a page
// moved to the desk: the framed count falling was only a number.
//
// The list only shrinks. A route guarded since must leave it (a stale name
// fails), and a new measured route either joins a guard or is named here
// with an issue, never silently.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/core/ui/adaptive/page_measures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Measured routes no desk guard opens yet, each with the issue that will
/// guard it (or why it never draws a page of its own).
const _notGuardedYet = <String, String>{
  // A long task: its own page over the list (#3608), guarded with its list.
  '/invoicing/wizard': '#3948 text wider than 760 px at 1024',
  // A record at its address under a guarded list.
  // The purchase orders: guarded by their own leaf.
  // Each had two causes, fixed on two branches (#3946 its Tab order, #3947
  // its names and sizes): to join the guards once measured with both.
  // An address that only redirects: it draws no page.
  '/money/sales': '#3874 redirects to /invoices, draws nothing',
};

/// The route patterns the desk guards' [sources] open: every address
/// literal in them, matched to its rule (a query is not part of it).
Set<String> guardedPatterns(Iterable<String> sources) => {
  for (final text in sources)
    for (final m in RegExp(r"'(/[^'\s$]*)'").allMatches(text))
      if (matchRoute(m.group(1)!.split('?').first) case final rule?)
        rule.pattern,
};

/// The measured routes of [rules] no guard opens and [named] does not name.
List<String> unguarded(
  Iterable<RouteRule> rules,
  Set<String> guarded,
  Map<String, String> named,
) => [
  for (final r in rules)
    if (r.measure != PageMeasure.framed &&
        !guarded.contains(r.pattern) &&
        !named.containsKey(r.pattern))
      r.pattern,
];

/// The guards that open pages on the desk: every guard of `test/ux` but
/// the phones' (`pocket_guards_test.dart`).
Iterable<String> _deskGuards() => [
  for (final f in filesWithExtension('test/ux', '.dart'))
    if (f.uri.pathSegments.last case final name
        when name.contains('guard') && name != 'pocket_guards_test.dart')
      f.readAsStringSync(),
];

void main() {
  final guarded = guardedPatterns(_deskGuards());

  test('a planted measured route no guard opens is found; a guarded or '
      'named one is not', () {
    const rules = [
      RouteRule('/a', RouteClass.workspace, measure: PageMeasure.work),
      RouteRule('/b', RouteClass.workspace, measure: PageMeasure.form),
      RouteRule('/c', RouteClass.workspace, measure: PageMeasure.reading),
      RouteRule('/d', RouteClass.workspace),
    ];
    expect(unguarded(rules, {'/b'}, {'/c': '#1 why'}), ['/a']);
  });

  test('every route measured for the desk is guarded, or named with the '
      'issue that will guard it', () {
    expect(
      unguarded(routeRules, guarded, _notGuardedYet),
      isEmpty,
      reason:
          'open it in a desk guard (test/ux/desk_guard_pages_test.dart '
          "_pages), or name it in _notGuardedYet with its issue",
    );
  });

  test('every named route is still a measured route no guard opens: a '
      'route guarded since leaves the list', () {
    final measured = {
      for (final r in routeRules)
        if (r.measure != PageMeasure.framed) r.pattern,
    };
    expect(
      [
        for (final p in _notGuardedYet.keys)
          if (!measured.contains(p) || guarded.contains(p)) p,
      ],
      isEmpty,
      reason: 'remove these from _notGuardedYet',
    );
  });

  test('every reason names its issue first', () {
    expect([
      for (final e in _notGuardedYet.entries)
        if (!RegExp(r'^#\d+ \S').hasMatch(e.value)) e.key,
    ], isEmpty);
  });
}
