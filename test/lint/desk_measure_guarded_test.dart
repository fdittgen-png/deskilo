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
  '/money/purchase-orders/new': '#3892 a long task over its list',
  '/money/purchase-orders/:id/edit': '#3892 a long task over its list',
  '/invoicing/wizard': '#3892 a long task',
  '/money/repartition-wizard': '#3892 a long task',
  // A record at its address under a guarded list.
  '/invoices/:id': '#3892 a record beside its guarded list',
  '/invoices/customer/:id': '#3892 a record beside its guarded list',
  '/members/plans/:id': '#3892 a record beside its guarded list',
  '/members/privacy/:id': '#3892 a record beside its guarded list',
  '/bi/report/:id': '#3892 a record of a guarded page',
  '/member/:memberId': '#3892 a record page',
  '/res/:id': '#3892 a record page, guarded on phones only',
  '/space/:kind/:id': '#3892 a record page',
  '/conversation/:conversationId': '#3892 a record page',
  '/editor/level/:levelId': '#3892 a record page',
  // The purchase orders: guarded by their own leaf.
  // Pages measured for the desk and not guarded yet.
  '/settings/public-page': '#3892 a desk page not guarded yet',
  '/money/repartition': '#3892 a desk page not guarded yet',
  '/money/settlement': '#3892 a desk page not guarded yet',
  '/assistants/connect': '#3892 a desk page not guarded yet',
  '/settings/assistants': '#3892 a desk page not guarded yet',
  '/settings/assistant-setup': '#3892 a desk page not guarded yet',
  '/kiosk-gate': '#3892 a desk page not guarded yet',
  '/kiosk': '#3892 a desk page not guarded yet',
  '/pending': '#3892 a desk page not guarded yet',
  '/formats': '#3892 a desk page not guarded yet',
  '/events': '#3892 a desk page not guarded yet',
  '/plan': '#3892 a desk page not guarded yet',
  '/library': '#3892 a desk page not guarded yet',
  '/workspace-code': '#3892 a desk page not guarded yet',
  '/nfc-config': '#3892 a desk page not guarded yet',
  '/badge-kiosks': '#3892 a desk page not guarded yet',
  '/payment-config': '#3892 a desk page not guarded yet',
  '/billing': '#3892 a desk page not guarded yet',
  '/einvoice-config': '#3892 a desk page not guarded yet',
  '/documents': '#3892 a desk page not guarded yet',
  '/accounting/connected': '#3892 a desk page not guarded yet',
  '/report-editor': '#3892 a desk page not guarded yet',
  '/settings/personal-info': '#3892 a desk page not guarded yet',
  '/settings/payment-terms': '#3892 a desk page not guarded yet',
  '/settings/sites': '#3892 a desk page not guarded yet',
  '/suppliers': '#3892 a desk page not guarded yet',
  '/money/cash': '#3892 a desk page not guarded yet',
  '/settings/wording': '#3892 a desk page not guarded yet',
  '/settings/colours': '#3892 a desk page not guarded yet',
  '/settings/roles-of-this-space': '#3892 a desk page not guarded yet',
  '/settings/what-you-can-do': '#3892 a desk page not guarded yet',
  '/settings/questions': '#3892 a desk page not guarded yet',
  '/attention': '#3892 a desk page not guarded yet',
  '/reservations/period': '#3892 a desk page not guarded yet',
  '/setup/levels': '#3892 a desk page not guarded yet',
  '/settings/number-sequences': '#3892 a desk page not guarded yet',
  '/members/managed': '#3892 a desk page not guarded yet',
  '/legal-identity': '#3892 a desk page not guarded yet',
  '/deployment': '#3892 a desk page not guarded yet',
  '/vat-declarations': '#3892 a desk page not guarded yet',
  '/vat': '#3892 a desk page not guarded yet',
  '/accessories': '#3892 a desk page not guarded yet',
  '/validation': '#3892 a desk page not guarded yet',
  '/availability': '#3892 a desk page not guarded yet',
  '/members/plans': '#3892 a desk page not guarded yet',
  '/editor': '#3892 a desk page not guarded yet',
  '/payment-methods': '#3892 a desk page not guarded yet',
  // Guarded, it is reached twice by Tab: its keyboard order, older than
  // this list, is to be fixed before its guard joins.
  '/workspace-overview': '#3892 reached twice by Tab in its desk guard',
  // An address that only redirects: it draws no page.
  '/money/sales': '#3892 redirects to /invoices, draws nothing',
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
