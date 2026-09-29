// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — who sees what of me. A change made on the card shows at once
// in "how others see me", AND in what another account reads through
// `visible_account` — the fake applies the server's audience rule, so
// the two views are checked against one model, positive beside
// negative.
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

Future<void> _choose(WidgetTester tester, VisibilityField field,
    VisibilityAudience audience, {List<String> spaces = const []}) async {
  await tapIn(tester, 'me-account-list',
      find.byKey(ValueKey('visibility-field-${field.wire}')));
  await tester.tap(find.byKey(ValueKey('visibility-audience-${audience.wire}')));
  await tester.pumpAndSettle();
  for (final id in spaces) {
    await tester.tap(find.byKey(ValueKey('visibility-space-$id')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('visibility-save')));
  await tester.pumpAndSettle();
}

Future<void> _previewAs(WidgetTester tester, PreviewAudience as) async {
  await tapIn(tester, 'me-account-list',
      find.byKey(ValueKey('visibility-preview-as-${as.wire}')));
}

void main() {
  late String current;
  late FakeMeRepository me;
  setUp(() {
    current = 'user-1';
    me = FakeMeRepository(currentUser: () => current, accounts: {
      'user-1': FakeAccount(
        name: 'Test User',
        profession: 'Designer',
        email: 'test@example.com',
        spaces: {'ws-1', 'ws-2'},
      ),
      // Shares no space with user-1: a stranger with an account.
      'user-9': FakeAccount(name: 'Stranger'),
      // Shares ws-2 only.
      'user-2': FakeAccount(name: 'Colleague', spaces: {'ws-2'}),
    });
  });

  testWidgets('the defaults are private: a stranger sees nothing, a member '
      'of my spaces my name', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=me');
    expect(find.descendant(
        of: find.byKey(const ValueKey('visibility-field-about')),
        matching: find.text('Nobody')), findsOneWidget);
    expect(find.byKey(const ValueKey('visibility-preview-name')), findsOneWidget);
    await _previewAs(tester, PreviewAudience.signedIn);
    expect(find.byKey(const ValueKey('visibility-preview-nothing')), findsOneWidget);
    // "Only me": everything, as I alone see it.
    await _previewAs(tester, PreviewAudience.nobody);
    expect(find.byKey(const ValueKey('visibility-preview-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('visibility-preview-email')), findsOneWidget);
  });

  testWidgets('profession and bio are written on the card and read only by '
      'their audience', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=me');
    await tapIn(tester, 'me-account-list',
        find.byKey(const ValueKey('visibility-about-edit')));
    await tester.enterText(find.byKey(const ValueKey('about-profession')), '  Architect ');
    await tester.enterText(find.byKey(const ValueKey('about-bio')), 'Plans and coffee.');
    await tester.tap(find.byKey(const ValueKey('about-save')));
    await tester.pumpAndSettle();
    expect(me.accounts['user-1']!.profession, 'Architect');
    expect(find.text('Architect · Plans and coffee.'), findsOneWidget);

    current = 'user-2';
    expect((await me.visibleAccount('user-1')).profession, isNull,
        reason: 'About is "nobody" by default, even for a space mate');
    current = 'user-1';
    await _choose(tester, VisibilityField.about, VisibilityAudience.mySpaces);
    current = 'user-2';
    expect((await me.visibleAccount('user-1')).profession, 'Architect');
  });

  testWidgets('a change shows in the preview and in what another account '
      'reads', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=me');

    // Before: a stranger reads nothing of user-1.
    current = 'user-9';
    expect((await me.visibleAccount('user-1')).name, isNull);
    current = 'user-1';

    await _choose(tester, VisibilityField.identity, VisibilityAudience.signedIn);
    await _choose(tester, VisibilityField.about, VisibilityAudience.signedIn);
    await _previewAs(tester, PreviewAudience.signedIn);
    expect(find.byKey(const ValueKey('visibility-preview-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('visibility-preview-profession')), findsOneWidget);
    expect(find.descendant(
        of: find.byKey(const ValueKey('visibility-field-identity')),
        matching: find.text('Anyone signed in')), findsOneWidget);

    // After: the same stranger reads the name and the profession.
    current = 'user-9';
    final seen = await me.visibleAccount('user-1');
    expect(seen.name, 'Test User');
    expect(seen.profession, 'Designer');
    expect(seen.email, isNull, reason: 'contact channels stayed nobody');
  });

  testWidgets('chosen spaces: only members of the chosen space read it, and '
      'reachability is chosen apart', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=me');
    await _choose(tester, VisibilityField.contactChannels,
        VisibilityAudience.chosenSpaces, spaces: ['ws-2']);
    await _choose(tester, VisibilityField.reachability, VisibilityAudience.nobody);
    expect(find.text('Members of 1 chosen space'), findsOneWidget);

    current = 'user-2';
    final colleague = await me.visibleAccount('user-1');
    expect(colleague.email, 'test@example.com');
    expect(colleague.canMessage, isFalse);
    current = 'user-9';
    expect((await me.visibleAccount('user-1')).email, isNull);

    current = 'user-1';
    await _previewAs(tester, PreviewAudience.mySpaces);
    expect(find.byKey(const ValueKey('visibility-preview-email')), findsOneWidget);
    expect(find.text('Cannot start a conversation with you'), findsOneWidget);
  });

  testWidgets('"chosen spaces" with none chosen cannot be saved',
      (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=me');
    await tapIn(tester, 'me-account-list',
        find.byKey(const ValueKey('visibility-field-presence')));
    await tester.tap(find.byKey(const ValueKey('visibility-audience-chosen_spaces')));
    await tester.pumpAndSettle();
    final save = tester.widget<FilledButton>(find.byKey(const ValueKey('visibility-save')));
    expect(save.onPressed, isNull);
  });

  testWidgets('the account messenger no longer holds a switch: its row opens '
      'the card in Me', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
    await goTo(tester, router, '/me?tab=messages');
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('portal-visibility-link')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/me?tab=me');
    expect(find.byKey(const ValueKey('me-visibility-card')), findsOneWidget);
  });
}
