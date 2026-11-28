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
  '/till/layout/:tillId': '#4448 the layout editor: its widget tests measure it at phone, tablet and desk widths; joins the guards with the till guard',
  '/app-update': '#3726 a notice with one way out, shown only when the installation refuses this app: test/app/app_floor_gate_test.dart draws it; it needs an installation floor above the app to open in a desk guard',
  '/stock/where/:itemId': '#4434 the places of an item, the road, the documents and the pieces: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/counts': '#4172 a list of cards: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/reorder': '#4294 two lists of rows and cards: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/value': '#4173 a total, a list of unpriced goods and a list of priced goods: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/money/bank-accounts': '#4496 a list and a sheet: its widget tests render it at phone and desk widths',
  '/settings/devices': '#4466 a form: its widget tests measure it at phone and desk widths; joins the guards with the till guard',
  '/settings/units': '#4442 a list by dimension and a sheet: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/units': '#4435 a list and sheets: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/expiry': '#4431 a filter form and a list of rows: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/groups': '#4361 a list of groups and a sheet: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/cycle-counts': '#4295 tabs of lists and a plan sheet: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/stock/cycle-counts/:taskId': '#4295 a list of lines and two sheets: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  '/till': '#4366 a basket beside its keys and two dialogs: its widget tests measure it at phone, tablet and desk widths; joins the guards when the till has a Demo business to walk',
  '/till/day': '#4367 a list of closed days and a full-screen report: its widget tests measure it at phone and desk widths; joins the guards with the till',
  '/till/receipts': '#4185 a list of receipts with its sheets: its widget tests measure it at phone and desk widths; joins the guards with the till',
  '/till/drawer': '#4367 a list of cards and four sheets: its widget tests measure it at phone and desk widths; joins the guards with the till',
  '/stock/transfers': '#4170 a list of cards: its widget tests measure it at phone and desk widths; joins the guards with the stock guard',
  // A record at its address under a guarded list.
  // The purchase orders: guarded by their own leaf.
  // Each had two causes, fixed on two branches (#3946 its Tab order, #3947
  // its names and sizes): to join the guards once measured with both.
  // An address that only redirects: it draws no page.
  '/money/sales': '#3874 redirects to /invoices, draws nothing',
  '/invoicing/standalone/new': '#4165 a composer behind its feature: joins the guards with the payment part',
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
/// the phones' (`pocket_guards_test.dart`), and the lists the desk walk runs
/// on (`walked_routes.dart`, #4077).
Iterable<String> _deskGuards() => [
  for (final f in filesWithExtension('test/ux', '.dart'))
    if (f.uri.pathSegments.last case final name
        when (name.contains('guard') && name != 'pocket_guards_test.dart') ||
            name == 'walked_routes.dart')
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
