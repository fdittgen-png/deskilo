// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2211): a signed-out visitor sees nothing of me until I publish a
// public profile on purpose. Publishing asks first and names the audience;
// cancelling publishes nothing; withdrawing is immediate. The public page
// shows the name, the profession and the bio — and never a contact channel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

void main() {
  testWidgets('publish asks first; cancel keeps it private; withdraw is '
      'immediate', (tester) async {
    final me = FakeMeRepository();
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=me');
    final tile = find.byKey(const ValueKey('visibility-public-profile'));

    await tapIn(tester, 'me-account-list', tile);
    expect(
      find.byKey(const ValueKey('public-profile-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('public-profile-cancel')));
    await tester.pumpAndSettle();
    expect(me.published, isEmpty, reason: 'cancelling publishes nothing');

    await tapIn(tester, 'me-account-list', tile);
    await tester.tap(find.byKey(const ValueKey('public-profile-confirm')));
    await tester.pumpAndSettle();
    expect(me.published, {'user-1'});
    expect(find.byKey(const ValueKey('public-profile-link')), findsOneWidget);

    await tapIn(tester, 'me-account-list', tile);
    expect(
      find.byKey(const ValueKey('public-profile-confirm')),
      findsNothing,
      reason: 'withdrawing never asks',
    );
    expect(me.published, isEmpty);
  });

  testWidgets('the public page shows the three published fields only', (
    tester,
  ) async {
    final me = FakeMeRepository()..published.add('user-1');
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/p/user-1');
    expect(find.byKey(const ValueKey('public-person')), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Designer'), findsOneWidget);
    expect(
      find.text('test@example.com'),
      findsNothing,
      reason: 'a contact channel is never public',
    );
  });

  testWidgets('an unpublished profile reads one neutral sentence', (
    tester,
  ) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/p/user-1');
    expect(
      find.byKey(const ValueKey('public-person-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Test User'), findsNothing);
  });

  testWidgets('a visitor who is not signed in reads it too', (tester) async {
    final me = FakeMeRepository()..published.add('user-1');
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(),
      me: me,
      auth: FakeAuthRepository(),
    );
    await goTo(tester, router, '/p/user-1');
    expect(router.state.uri.path, '/p/user-1', reason: 'no sign-in wall');
    expect(find.text('Test User'), findsOneWidget);
  });
}
