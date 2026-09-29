// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1818 — one shell at a time. When the session ends, the Navigator keeps
// the old shell mounted under the incoming sign-in page until that page
// has arrived. A session that comes back inside that window must not
// build a second shell beside it: both would carry the one
// StatefulNavigationShell GlobalKey that StatefulShellRoute owns.
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../tool/bench/onboarding_entry_recipes.dart';

void main() {
  testWidgets('signed out and straight back in while the sign-in page is '
      'still arriving: one shell, and the person is back on the hub', (
    tester,
  ) async {
    State? before;
    final run = await returningEntry(
      tester,
      afterEntry: (probe, auth) async {
        before = tester.state(find.byType(StatefulNavigationShell));
        await auth.signOut();
        // ONE frame: /auth has replaced the shell, and the old shell is
        // still mounted beneath it.
        await tester.pump();
        auth.signInAs('user-1');
        await probe.settle();
      },
    );
    expect(tester.takeException(), isNull);
    expect(run.trail.last, '/reserve');
    expect(
      find.byType(ShellScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'exactly one shell is mounted once the hand-over is done',
    );
    expect(
      tester.state(find.byType(StatefulNavigationShell)),
      isNot(same(before)),
      reason:
          'the new session starts fresh: the ended session\'s tabs '
          'and open pages are not carried over',
    );
  });
}
