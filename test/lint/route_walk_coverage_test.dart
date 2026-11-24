// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4077 -- every route is rendered by a walk or says why it is not. A route
// of the registry (lib/app/route_classes.dart) is rendered when
//  - the desk walk's own page lists name it (test/ux/walked_routes.dart: the
//    walk of test/ux/desk_guard_pages_test.dart runs on those lists),
//  - the Me guards' screens name it (test/ux/me_screens.dart),
//  - the phone's five tabs name it (information_cut_guard_test.dart), or
//  - a row of the accessibility matrix (test/a11y/matrix.dart) draws it.
// A route no walk renders carries one line here: it has no layout of its own
// (it forwards to another page, or lands on one without its arguments). A
// new route with neither fails this test; so does a reason that names a route
// a walk renders.
import 'package:deskilo/app/route_classes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../a11y/matrix.dart';
import '../ux/me_screens.dart';
import '../ux/walked_routes.dart';

/// The routes a row of the accessibility matrix draws, and the row.
const Map<String, String> _matrixRows = {
  '/auth': 'Sign in',
  '/onboarding': 'Create workspace',
};

/// The routes no walk renders, and why: the router's golden
/// (test/app/fixtures/route_outcomes.golden) says where each one lands.
const Map<String, String> _noLayoutOfItsOwn = {
  '/stock/where/:itemId': '#4434 the places of an item and a date chip; its widget tests render it at phone and desk widths',
  '/stock/counts': '#4172 a list of cards and a sheet; its widget tests render it at phone and desk widths',
  '/stock/reorder': '#4294 two lists and a button; its widget tests render it at phone and desk widths',
  '/stock/value': '#4173 a total and two lists; its widget tests render it at phone and desk widths',
  '/stock/units': '#4435 a list and sheets; widget tests render it at phone and desk',
  '/settings/units': '#4442 a list by dimension and a sheet; widget tests render it at phone and desk',
  '/stock/expiry': '#4431 a filter form and a list; widget tests render it at phone and desk',
  '/stock/groups': '#4361 a list of groups and a sheet; its widget tests render it at phone and desk widths',
  '/stock/cycle-counts': '#4295 tabs of lists and a sheet; its widget tests render it at phone and desk widths',
  '/stock/cycle-counts/:taskId': '#4295 a list of lines and two sheets; its widget tests render it at phone and desk widths',
  '/till': '#4366 keys, a basket, two dialogs; widget tests render it at phone, tablet and desk',
  '/till/day': '#4367 a list of closed days and a full-screen report; widget tests render it at phone and desk',
  '/till/receipts': '#4185 the receipts the till made with their sheets; widget tests render them at phone and desk',
  '/till/drawer': '#4367 the tills with their sessions and four sheets; widget tests render them at phone and desk',
  '/stock/transfers': '#4170 a list of cards and three sheets; its widget tests render it at phone and desk widths',
  '/me/spaces/manage': 'forwards to /profiles, which the desk walk renders',
  '/invoicing/standalone/new': '#4165 composer behind its feature; its widget tests walk it at phone and desk',
  '/me/account/connections': 'forwards to /connections, which is walked',
  '/discover/workspace': 'forwards to /discover without a workspace chosen',
  '/account-messages/thread': 'forwards to /account-messages without a thread',
  '/me/messages/thread': 'forwards to /me without a thread to open',
  '/me/messages/inquiries': 'forwards to /me: the inquiries are a tab of it',
  '/me/messages/new': 'forwards to /account-messages (the compose sheet)',
  '/me/messages/:ref': 'forwards to /account-messages, which is walked',
  '/templates/compare': 'forwards to /onboarding without the templates chosen',
  '/templates/detail': 'forwards to /onboarding without a template chosen',
  '/task-recorder/guide': 'forwards to /task-recorder without a recording',
  '/task-recorder/recording': 'forwards to /task-recorder without a run',
  '/task-workbench/storyboard': 'forwards to /task-workbench without a clip',
  '/server/new-instance/first-start': 'forwards to /server without an instance',
  '/consent': 'forwards to the reserve hub: consent is already given',
  '/server-update': 'forwards to the reserve hub unless the schema is old',
  '/app-update': 'forwards to the reserve hub unless the floor is above this app',
  '/money/sales': 'forwards to /invoices (an owner, an administrator)',
};

/// The walk that renders each of [patterns], or null for none.
Map<String, String?> _renderedBy(Iterable<String> patterns) {
  final walked = <String, String>{};
  void add(String path, String walk) {
    final rule = matchRoute(path.split('?').first);
    if (rule != null) walked.putIfAbsent(rule.pattern, () => walk);
  }

  for (final (path, _, _, _) in deskWalkAllPages) {
    add(path, 'desk walk');
  }
  for (final screen in meScreens) {
    add(screen.route, 'Me guards');
  }
  for (final path in phoneTabRoutes) {
    add(path, 'phone tabs');
  }
  for (final entry in _matrixRows.entries) {
    add(entry.key, 'matrix row ${entry.value}');
  }
  return {for (final p in patterns) p: walked[p]};
}

/// What is wrong with the pairing of [routes], the walks and [reasons].
List<String> _problems(List<String> routes, Map<String, String> reasons) {
  final rendered = _renderedBy(routes);
  return [
    for (final r in routes)
      if (rendered[r] == null && !reasons.containsKey(r))
        '$r: no walk renders it and no reason says why not',
    for (final e in reasons.entries)
      if (!routes.contains(e.key))
        '${e.key}: a reason for a route the registry does not have'
      else if (rendered[e.key] != null)
        '${e.key}: the ${rendered[e.key]} renders it, drop the reason',
  ];
}

void main() {
  final routes = [for (final r in routeRules) r.pattern];

  test('every route is rendered by a walk or carries its reason', () {
    expect(_problems(routes, _noLayoutOfItsOwn), isEmpty);
  });

  test('every walked page is a route of the registry', () {
    final unregistered = [
      for (final (path, _, _, _) in deskWalkAllPages)
        if (matchRoute(path.split('?').first) == null) path,
      for (final screen in meScreens)
        if (matchRoute(screen.route.split('?').first) == null) screen.route,
      for (final path in [...phoneTabRoutes, ..._matrixRows.keys])
        if (matchRoute(path) == null) path,
    ];
    expect(unregistered, isEmpty);
  });

  test('the matrix rows named for a route exist', () {
    final rows = {for (final row in kMatrix) row.screen};
    for (final row in _matrixRows.values) {
      expect(rows, contains(row));
    }
  });

  test('a planted route with neither a walk nor a reason fails', () {
    final problems = _problems([
      ...routes,
      '/planted-route',
    ], _noLayoutOfItsOwn);
    expect(problems, [
      '/planted-route: no walk renders it and no reason says why not',
    ]);
  });

  test('a reason for a route a walk renders fails', () {
    final problems = _problems(routes, {
      ..._noLayoutOfItsOwn,
      '/profiles': 'a stale reason',
    });
    expect(problems.single, contains('/profiles'));
    expect(problems.single, contains('drop the reason'));
  });

  test('a reason for a route nobody registers fails', () {
    final problems = _problems(routes, {
      ..._noLayoutOfItsOwn,
      '/gone': 'a route that was removed',
    });
    expect(problems.single, contains('/gone'));
  });

  test('the reasons are one line each', () {
    for (final reason in _noLayoutOfItsOwn.values) {
      expect(reason, isNot(contains('\n')));
      expect(reason.length, lessThan(100));
    }
  });
}
