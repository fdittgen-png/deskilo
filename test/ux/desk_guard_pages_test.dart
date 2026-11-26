// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards on their first pages, through the app's
// builder at 1024, 1440 and 1920: /invoices, a records page, and the Me
// overview. With SHEET=1 each writes its sheet at 390 and 1440, light and
// dark, to build/sheets/<module>/ (docs/testing/desk-guards.md). The walk
// itself is test/ux/desk_walk_kit.dart; this file runs it on the first list
// of test/ux/walked_routes.dart, desk_guard_more_pages_test.dart on the
// second (#4077), and the checks that hold for both are here.
import 'package:deskilo/app/route_classes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desk_walk_kit.dart';
import 'experience_guards.dart';
import 'walked_routes.dart';

/// #3619 — how many workspace routes the guards above hold; it only rises
/// (the follow-up guards the rest, the most used modules first).
const _guardedWorkspaceRoutes = 104;

void main() {
  test('the guarded workspace routes only rise', () {
    final guarded = {
      for (final (path, _, _, _) in deskWalkAllPages)
        if (matchRoute(path) case final r? when r.kind == RouteClass.workspace)
          r.pattern,
    };
    final all = routeRules.where((r) => r.kind == RouteClass.workspace);
    expect(
      guarded.length,
      greaterThanOrEqualTo(_guardedWorkspaceRoutes),
      reason: 'of ${all.length} workspace routes',
    );
    if (guarded.length > _guardedWorkspaceRoutes) {
      fail('raise _guardedWorkspaceRoutes to ${guarded.length}');
    }
  });

  setUpAll(() => loadSheetFonts(always: true));
  // A sheet runs on the real clock, where the records table's read of its
  // saved columns needs a store to answer.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  runDeskWalk(deskWalkPages, pictures: true);

  // #4076 -- the same pages, seen by an administrator and by a plain member:
  // every page the router opens for that persona is rendered as that persona
  // at one desk and one phone size, under the same guards (the desk's at the
  // desk, the phone's at the phone).
  test('a persona walk has pages to render', () {
    for (final persona in walkedPersonas) {
      final opens = personaOpens(persona);
      final walked = {
        for (final (path, _, _, _) in deskWalkAllPages)
          if (opens.contains(matchRoute(path)?.pattern)) path,
      };
      expect(walked, isNotEmpty, reason: persona.name);
    }
  });

  test('every finding left out of the desk walk is a case of it', () {
    final cases = {
      for (final (path, _, _, _) in deskWalkAllPages)
        for (final size in deskGuardSizes) '$path|${size.width.toInt()}',
    };
    expect(deskFindings.keys.toSet().difference(cases), isEmpty);
  });

  test('every finding left out of the persona walk is a case of it', () {
    final cases = {
      for (final persona in walkedPersonas)
        for (final size in walkPersonaSizes)
          for (final (path, _, _, _) in deskWalkAllPages)
            if (personaOpens(persona).contains(matchRoute(path)?.pattern))
              '$path|${persona.name}|${size.width.toInt()}',
    };
    expect(personaFindings.keys.toSet().difference(cases), isEmpty);
  });

  // #4076 -- each walk fails on a planted fault.
  testWidgets('the persona walk fails on a page the persona is refused', (
    tester,
  ) async {
    // The router sends a plain member away from the members' table: the
    // landing check of the walk would name it.
    await openWalkPage(tester, '/members', const Size(1440, 900), WalkPersona.member);
    expect(walkLanded(tester), isNot('/members'));
    expect(personaOpens(WalkPersona.member), isNot(contains('/members')));
    expect(personaOpens(WalkPersona.admin), contains('/members'));
  });

  testWidgets('the phone guard fails on a planted overflow, a cut line and '
      'a small unnamed target', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text(
              'A title that is far too long for the bar of a phone to hold',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Column(
            children: [
              const Row(
                children: [
                  SizedBox(width: 300, child: Text('left')),
                  SizedBox(width: 300, child: Text('right')),
                ],
              ),
              GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 20, height: 20),
              ),
            ],
          ),
        ),
      ),
    );
    final details = <String>[];
    final problems = phoneProblems(tester, details);
    expect(problems, contains('overflow or exception'));
    expect(problems, contains('information cut'));
    expect(problems, contains('unnamed control'));
    expect(problems, contains('target under 48 dp'));
    semantics.dispose();
  });

  // #4095 -- a control half scrolled out is measured as the control it is:
  // its visible part is not its size. A small control inside the viewport
  // is still named.
  testWidgets('the phone guard measures a control cut by its viewport whole, '
      'and still names a small one inside it', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(390, 300)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget row(String name, double height) => InkWell(
      onTap: () {},
      child: SizedBox(height: height, child: Text(name)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              row('whole', 270),
              // 100 high, 30 dp of it in the viewport.
              row('cut', 100),
            ],
          ),
        ),
      ),
    );
    final details = <String>[];
    expect(
      phoneProblems(tester, details),
      isNot(contains('target under 48 dp')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [row('first', 100), row('small', 20), row('big', 400)]),
        ),
      ),
    );
    expect(phoneProblems(tester, details), contains('target under 48 dp'));
    semantics.dispose();
  });
}
