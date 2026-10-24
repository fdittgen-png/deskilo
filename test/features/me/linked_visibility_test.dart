// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 (4) — who sees me on my other servers. Each connected server has
// its own account for me, so what people there see is set there: the
// card lists every connected server, the sheet reads that server's
// my_visibility, a change is written with that server's set_visibility,
// and the caps hold — contact details never offer every signed-in person,
// and chosen spaces are not offered for another server. A server that
// does not answer says so instead of showing defaults.
//
// #2558 — the servers are "Legacy personal accounts", an expandable section
// apart from the personal home. A picked audience is held unsaved for the
// account shown until Save; moving to another account with it asks Save /
// Discard / Keep editing, and the change never moves to the other account.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _other = 'https://coworkonti.example';

ConnectedInstallation _linked(String url) => ConnectedInstallation(
  endpoint: BackendEndpoint(url, 'sb_publishable_other'),
  account: 'remote-user',
  installationId: 'inst-$url',
);

const _second = 'https://atelier.example';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tapIn(tester, 'me-account-list', _key('visibility-legacy'));
}

/// Picks [audience] for [field] of the account shown: held, not saved.
Future<void> _pick(WidgetTester tester, String field, String audience) async {
  await tapIn(tester, 'me-account-list', _key('linked-visibility-field-$field'));
  await _tap(tester, 'linked-visibility-audience-$audience');
}

String? _subtitle(WidgetTester tester, String field) =>
    (tester.widget<ListTile>(_key('linked-visibility-field-$field')).subtitle
            as Text?)
        ?.data;

void main() {
  testWidgets('no connected server, no card', (tester) async {
    final router = await pumpMeApp(tester, me: FakeMeRepository());
    await goTo(tester, router, '/me?tab=me');
    expect(
      find.byKey(const ValueKey('me-linked-visibility-card')),
      findsNothing,
    );
  });

  testWidgets('a change is written on that server, within the caps', (
    tester,
  ) async {
    final me = FakeMeRepository();
    final linked = FakeLinkedMeRepository();
    final router = await pumpMeApp(
      tester,
      me: me,
      linkedMe: linked,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me?tab=me');
    await _openSheet(tester);

    // Contact details: no "every signed-in person", no chosen spaces.
    await tapIn(tester, 'me-account-list',
        _key('linked-visibility-field-contact_channels'));
    expect(_key('linked-visibility-audience-signed_in'), findsNothing);
    expect(_key('linked-visibility-audience-chosen_spaces'), findsNothing);
    await _tap(tester, 'linked-visibility-audience-my_spaces');
    // Held, not saved: the server still holds the old audience.
    expect(_subtitle(tester, 'contact_channels'),
        'Not saved yet: Members of my spaces');
    expect(linked.linkedVisibility[_other], isNull);
    // Widening asks first, then the server holds the new audience.
    await _tap(tester, 'legacy-draft-save');
    await _tap(tester, 'visibility-widen-confirm');
    expect(_key('legacy-draft-save'), findsNothing);
    expect(
      linked.linkedVisibility[_other]!.of(VisibilityField.contactChannels).audience,
      VisibilityAudience.mySpaces,
    );
    // Home is untouched.
    expect(
      (await me.myVisibility()).of(VisibilityField.contactChannels).audience,
      VisibilityAudience.nobody,
    );

    // Name and photo may go to every signed-in person there.
    await _pick(tester, 'identity', 'signed_in');
    await _tap(tester, 'legacy-draft-save');
    await _tap(tester, 'visibility-widen-confirm');
    expect(
      linked.linkedVisibility[_other]!.of(VisibilityField.identity).audience,
      VisibilityAudience.signedIn,
    );
  });

  testWidgets('a server that does not answer says so', (tester) async {
    final linked = FakeLinkedMeRepository()..unavailable.add(_other);
    final router = await pumpMeApp(
      tester,
      linkedMe: linked,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me?tab=me');
    await _openSheet(tester);
    expect(
      find.byKey(const ValueKey('linked-visibility-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('linked-visibility-field-identity')),
      findsNothing,
    );
  });

  group('#2558 switching accounts with an unsaved change', () {
    late FakeMeRepository me;
    late FakeLinkedMeRepository linked;
    Future<void> pump(WidgetTester tester) async {
      me = FakeMeRepository();
      linked = FakeLinkedMeRepository();
      final router = await pumpMeApp(
        tester,
        me: me,
        linkedMe: linked,
        connectedSources: [_linked(_other), _linked(_second)],
      );
      await goTo(tester, router, '/me?tab=me');
      await _openSheet(tester);
      // Contact details to my spaces on the first account, unsaved.
      await _pick(tester, 'contact_channels', 'my_spaces');
    }

    bool showing(WidgetTester tester, String url) => tester
        .widget<ChoiceChip>(_key('legacy-account-${Uri.parse(url).host}'))
        .selected;

    testWidgets('keep editing stays on the account with the change', (
      tester,
    ) async {
      await pump(tester);
      await tapIn(tester, 'me-account-list', _key('legacy-account-atelier.example'));
      expect(_key('legacy-dirty'), findsOneWidget);
      await _tap(tester, 'legacy-dirty-keep');
      expect(showing(tester, _other), isTrue);
      expect(_subtitle(tester, 'contact_channels'),
          'Not saved yet: Members of my spaces');
      expect(linked.linkedVisibility, isEmpty, reason: 'nothing was written');
    });

    testWidgets('discard drops the change and shows the other account, '
        'which never receives it', (tester) async {
      await pump(tester);
      await tapIn(tester, 'me-account-list', _key('legacy-account-atelier.example'));
      await _tap(tester, 'legacy-dirty-discard');
      expect(showing(tester, _second), isTrue);
      expect(_key('legacy-draft-save'), findsNothing);
      expect(_subtitle(tester, 'contact_channels'), 'Nobody');
      expect(linked.linkedVisibility, isEmpty);
      // Back on the first account, the saved value is what shows.
      await tapIn(tester, 'me-account-list', _key('legacy-account-coworkonti.example'));
      expect(_key('legacy-dirty'), findsNothing);
      expect(_subtitle(tester, 'contact_channels'), 'Nobody');
    });

    testWidgets('save writes the change on its own account, then switches', (
      tester,
    ) async {
      await pump(tester);
      await tapIn(tester, 'me-account-list', _key('legacy-account-atelier.example'));
      await _tap(tester, 'legacy-dirty-save');
      await _tap(tester, 'visibility-widen-confirm');
      expect(showing(tester, _second), isTrue);
      expect(
        linked.linkedVisibility[_other]!
            .of(VisibilityField.contactChannels)
            .audience,
        VisibilityAudience.mySpaces,
      );
      expect(linked.linkedVisibility[_second], isNull);
      expect(
        (await me.myVisibility()).of(VisibilityField.contactChannels).audience,
        VisibilityAudience.nobody,
        reason: 'the personal home is not changed by a legacy account',
      );
    });

    testWidgets('a save the server refuses keeps the change and the account', (
      tester,
    ) async {
      await pump(tester);
      linked.unavailable.add(_other);
      await tapIn(tester, 'me-account-list', _key('legacy-account-atelier.example'));
      await _tap(tester, 'legacy-dirty-save');
      await _tap(tester, 'visibility-widen-confirm');
      expect(
        find.text('Could not save who sees this. Please try again.'),
        findsOneWidget,
      );
      expect(showing(tester, _other), isTrue);
      expect(_subtitle(tester, 'contact_channels'),
          'Not saved yet: Members of my spaces');
      expect(linked.linkedVisibility, isEmpty);
    });
  });
}
