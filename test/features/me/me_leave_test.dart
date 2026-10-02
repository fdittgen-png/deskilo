// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — leaving a space is an ordinary action on its card in Me:
// confirmed, then `leave_workspace`. Cancelling leaves nothing; an owner
// cannot leave the space ownerless, so the action is not offered.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

Future<void> _openMenu(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('me-space-menu-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leave a space from its card: confirmed, then left',
      (tester) async {
    final me = FakeMeRepository();
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me');

    await _openMenu(tester, 'ws-2');
    await tester.tap(find.byKey(const ValueKey('me-space-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-leave-cancel')));
    await tester.pumpAndSettle();
    expect(me.left, isEmpty, reason: 'cancelling leaves nothing');

    await _openMenu(tester, 'ws-2');
    await tester.tap(find.byKey(const ValueKey('me-space-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-leave-confirm')));
    await tester.pumpAndSettle();
    expect(me.left, ['ws-2']);
    expect(find.text('You left Second Space.'), findsOneWidget);
  });

  testWidgets('an owner is not offered to leave', (tester) async {
    final me = FakeMeRepository();
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me');
    await _openMenu(tester, 'ws-1');
    final item = tester.widget<PopupMenuItem<String>>(
        find.byKey(const ValueKey('me-space-leave')));
    expect(item.enabled, isFalse);
    expect(find.text('Owners hand the space over before leaving'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('me-space-leave')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-leave-confirm')), findsNothing);
    expect(me.left, isEmpty);
  });

  testWidgets('a refused leave says so and changes nothing', (tester) async {
    final me = FakeMeRepository()..failure = StateError('server says no');
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me');
    await _openMenu(tester, 'ws-2');
    await tester.tap(find.byKey(const ValueKey('me-space-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-leave-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Could not leave the space. Please try again.'), findsOneWidget);
    expect(find.byKey(const ValueKey('me-space-ws-2')), findsOneWidget);
  });
}
