// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the client reads the shapes the server writes (#1822): a hidden
// part of an account is ABSENT, a field the server did not name takes its
// default, and "chosen spaces" with none chosen is refused before a call.
import 'package:deskilo/features/me/application/me_actions.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  test('widens: a wider audience, or more chosen spaces — never a narrower one', () {
    const nobody = FieldAudience(VisibilityAudience.nobody);
    const mine = FieldAudience(VisibilityAudience.mySpaces);
    const anyone = FieldAudience(VisibilityAudience.signedIn);
    expect(anyone.widens(nobody), isTrue);
    expect(mine.widens(nobody), isTrue);
    expect(nobody.widens(mine), isFalse);
    expect(mine.widens(mine), isFalse);
    const one = FieldAudience(VisibilityAudience.chosenSpaces, ['a']);
    const two = FieldAudience(VisibilityAudience.chosenSpaces, ['a', 'b']);
    expect(two.widens(one), isTrue);
    expect(one.widens(two), isFalse);
    expect(one.widens(nobody), isTrue);
  });

  test('my_visibility: fields, reachability and my own about text', () {
    final v = MyVisibility.fromJson({
      'fields': {
        'identity': {'audience': 'signed_in', 'workspaces': <String>[]},
        'about': {'audience': 'chosen_spaces', 'workspaces': ['ws-2']},
      },
      'reachability': {'audience': 'nobody', 'workspaces': <String>[]},
      'about': {'profession': 'Architect', 'bio': 'Plans.'},
    });
    expect(v.of(VisibilityField.identity).audience, VisibilityAudience.signedIn);
    expect(v.of(VisibilityField.about), const FieldAudience(VisibilityAudience.chosenSpaces, ['ws-2']));
    expect(v.of(VisibilityField.reachability).audience, VisibilityAudience.nobody);
    // Not named: the server's default.
    expect(v.of(VisibilityField.presence).audience, VisibilityAudience.nobody);
    expect(v.profession, 'Architect');
    expect(v.bio, 'Plans.');
  });

  test('visible_account: a hidden part is absent and reads as nothing', () {
    final seen = AccountView.fromJson({
      'user_id': 'u',
      'identity': {'name': 'Léa', 'avatar_path': null},
      'contact_channels': {'whatsapp': '', 'email': 'lea@example.com'},
      'can_message': true,
    });
    expect(seen.name, 'Léa');
    expect(seen.hasPhoto, isFalse);
    expect(seen.profession, isNull);
    expect(seen.whatsapp, isNull, reason: 'an empty value is no value');
    expect(seen.email, 'lea@example.com');
    expect(seen.presenceShared, isFalse);
    expect(seen.canMessage, isTrue);
    expect(AccountView.fromJson({'user_id': 'u', 'can_message': false}).isEmpty, isTrue);
  });

  test('the command refuses what the server would, before calling it', () async {
    final repo = FakeMeRepository();
    final actions = MeActions(repo);
    expect(() => actions.choose(VisibilityField.presence,
            const FieldAudience(VisibilityAudience.chosenSpaces)),
        throwsA(isA<MeRefused>()));
    expect(() => actions.saveAbout('x' * 121, ''), throwsA(isA<MeRefused>()));
    expect(() => actions.leave('ws-1', isOwner: true), throwsA(isA<MeRefused>()));
    // A non-chosen audience drops stale spaces rather than sending them.
    await actions.choose(VisibilityField.identity,
        const FieldAudience(VisibilityAudience.signedIn, ['ws-1']));
    expect((await repo.myVisibility()).of(VisibilityField.identity).workspaces, isEmpty);
    await actions.saveAbout('  Architect ', ' Plans. ');
    expect(repo.accounts['user-1']!.profession, 'Architect');
  });

  test('#2211 — contact channels and presence stop at my spaces', () {
    for (final field in VisibilityField.values) {
      final wide = field.allowedAudiences.contains(VisibilityAudience.signedIn);
      expect(wide,
          field != VisibilityField.contactChannels && field != VisibilityField.presence,
          reason: field.wire);
      // Every field keeps the narrow choices and its own default.
      expect(field.allowedAudiences, contains(VisibilityAudience.nobody));
      expect(field.allowedAudiences, contains(field.defaultAudience));
    }
  });
}
