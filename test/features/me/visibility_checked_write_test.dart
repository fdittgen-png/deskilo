// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 C2 — the privacy editor writes through the personal home's checked
// writer (`set_visibility_if_unchanged_network_v1`): the value the person
// read is the expected one. A field changed meanwhile is a conflict that
// keeps the draft, shows what is saved now and asks for an explicit review;
// a lost reply is read back (the intent saved is saved, anything else is
// reviewed, never resent); a reply of an older account or home is ignored.
import 'package:deskilo/features/me/application/me_actions.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:deskilo/features/me/domain/visibility_write.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _account(WidgetTester tester, FakeMeRepository me) async {
  final router = await pumpMeApp(
    tester,
    workspace: FakeWorkspaceRepository(workspaces: []),
    me: me,
    extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
  );
  await goTo(tester, router, '/me/account');
}

/// Contact details to the one chosen space ws-1, confirmed as a widening.
Future<void> _chooseAtelier(WidgetTester tester, FakeMeRepository me) async {
  await tapIn(
    tester,
    'me-account-list',
    _key('visibility-field-contact_channels'),
  );
  await _tap(tester, _key('visibility-audience-chosen_spaces'));
  await _tap(tester, _key('visibility-space-${me.refOf('ws-1')}'));
  await _tap(tester, _key('visibility-save'));
  await _tap(tester, _key('visibility-widen-confirm'));
}

void main() {
  late FakeMeRepository me;
  setUp(() {
    me = FakeMeRepository(
      accounts: {
        'user-1': FakeAccount(
          name: 'Test User',
          email: 'test@example.com',
          spaces: {'ws-1'},
        ),
      },
      spaceLabels: {'ws-1': 'Atelier'},
    );
  });

  FieldAudience contact() =>
      me.accounts['user-1']!.visibility.of(VisibilityField.contactChannels);
  const atelier = FieldAudience(VisibilityAudience.chosenSpaces, {
    '00000000-0000-4000-8000-0000000000e1:ws-1',
  });

  group('the privacy card', () {
    testWidgets('success: the change is sent once with the value read as '
        'expected, and the card shows what the home saved', (tester) async {
      await _account(tester, me);
      await _chooseAtelier(tester, me);
      expect(contact(), atelier);
      expect(me.visibilityWrites, 1);
      expect(_key('visibility-conflict'), findsNothing);
      expect(
        find.descendant(
          of: _key('visibility-field-contact_channels'),
          matching: find.text('Members of 1 chosen space'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('conflict: changed on another device meanwhile — nothing is '
        'written, the saved value and the draft are shown, Keep keeps the '
        'saved one', (tester) async {
      await _account(tester, me);
      // Another device saves "my spaces" after this card read "nobody".
      me.accounts['user-1']!.visibility = me.accounts['user-1']!.visibility
          .withField(
            VisibilityField.contactChannels,
            const FieldAudience(VisibilityAudience.mySpaces),
          );
      await _chooseAtelier(tester, me);

      expect(_key('visibility-conflict'), findsOneWidget);
      expect(find.text('This setting changed meanwhile'), findsOneWidget);
      expect(find.text('Saved now: Members of my spaces'), findsOneWidget);
      expect(
        find.text('Your change: Members of 1 chosen space'),
        findsOneWidget,
      );
      expect(
        contact(),
        const FieldAudience(VisibilityAudience.mySpaces),
        reason: 'the conflict wrote nothing',
      );
      expect(me.visibilityWrites, 0);
      expect(
        find.text('Could not save who sees this. Please try again.'),
        findsNothing,
        reason: 'a conflict is reviewed, not reported as a failure',
      );

      await _tap(tester, _key('visibility-conflict-keep'));
      expect(contact(), const FieldAudience(VisibilityAudience.mySpaces));
      expect(
        find.descendant(
          of: _key('visibility-field-contact_channels'),
          matching: find.text('Members of my spaces'),
        ),
        findsOneWidget,
        reason: 'the card rereads what is saved now',
      );
    });

    testWidgets('recovery: Review reopens the draft against the saved value '
        'and sends it with the new expected value', (tester) async {
      await _account(tester, me);
      me.accounts['user-1']!.visibility = me.accounts['user-1']!.visibility
          .withField(
            VisibilityField.contactChannels,
            const FieldAudience(VisibilityAudience.mySpaces),
          );
      await _chooseAtelier(tester, me);
      await _tap(tester, _key('visibility-conflict-review'));

      // The sheet opens on the draft: chosen spaces, Atelier ticked.
      final atelierBox = tester.widget<CheckboxListTile>(
        _key('visibility-space-${me.refOf('ws-1')}'),
      );
      expect(atelierBox.value, isTrue);
      await _tap(tester, _key('visibility-save'));
      // Chosen spaces is narrower than my spaces: no widening question.
      expect(_key('visibility-widen-confirm'), findsNothing);
      expect(contact(), atelier);
      expect(me.visibilityWrites, 1);
    });

    testWidgets('a lost reply whose change was saved reads as saved', (
      tester,
    ) async {
      await _account(tester, me);
      me.replyLost = Exception('timeout');
      await _chooseAtelier(tester, me);
      expect(contact(), atelier);
      expect(me.visibilityWrites, 1, reason: 'read back, never resent');
      expect(_key('visibility-conflict'), findsNothing);
      expect(
        find.text('Could not save who sees this. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('a lost reply with another value saved is reviewed as '
        'unconfirmed, never resent', (tester) async {
      await _account(tester, me);
      me
        ..replyLost = Exception('timeout')
        ..onWrite = () {
          me.accounts['user-1']!.visibility = me.accounts['user-1']!.visibility
              .withField(
                VisibilityField.contactChannels,
                const FieldAudience(VisibilityAudience.nobody),
              );
        };
      await _chooseAtelier(tester, me);
      expect(find.text('Your change could not be confirmed'), findsOneWidget);
      expect(find.text('Saved now: Nobody'), findsOneWidget);
      expect(me.visibilityWrites, 1);
    });
  });

  group('the command', () {
    test('a reply of an older epoch is ignored, success or conflict', () async {
      final actions = MeActions(me, FakeLinkedMeRepository(), me);
      var epoch = 'user-1@home';
      me.onWrite = () => epoch = 'user-2@home';
      final saved = await actions.choose(
        VisibilityField.contactChannels,
        atelier,
        saved: await me.myVisibility(),
        epoch: () => epoch,
      );
      expect(saved, isNull, reason: 'the account changed before the reply');

      me.onWrite = null;
      epoch = 'user-1@home';
      final stale = await me.myVisibility();
      me.accounts['user-1']!.visibility = stale.withField(
        VisibilityField.presence,
        const FieldAudience(VisibilityAudience.mySpaces),
      );
      var reads = 0;
      final result = await actions.choose(
        VisibilityField.presence,
        atelier,
        saved: stale,
        epoch: () => reads++ == 0 ? epoch : 'user-2@home',
      );
      expect(
        result,
        isNull,
        reason: 'a conflict of the old account is dropped',
      );
    });

    test('a conflict carries the value saved now; a lost reply that cannot '
        'be read back stays a failure', () async {
      final actions = MeActions(me, FakeLinkedMeRepository(), me);
      final read = await me.myVisibility();
      me.accounts['user-1']!.visibility = read.withField(
        VisibilityField.presence,
        const FieldAudience(VisibilityAudience.mySpaces),
      );
      await expectLater(
        actions.choose(VisibilityField.presence, atelier, saved: read),
        throwsA(
          isA<VisibilityConflict>()
              .having(
                (e) => e.current,
                'current',
                const FieldAudience(VisibilityAudience.mySpaces),
              )
              .having((e) => e.unconfirmed, 'unconfirmed', isFalse),
        ),
      );

      me
        ..replyLost = Exception('timeout')
        ..onWrite = () => me.readFailure = Exception('offline');
      await expectLater(
        actions.choose(
          VisibilityField.about,
          const FieldAudience(VisibilityAudience.mySpaces),
          saved: await me.myVisibility(),
        ),
        throwsA(isA<VisibilityReplyLost>()),
      );
    });
  });
}
