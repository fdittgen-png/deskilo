// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- the Workspace settings form's decisions, as tables (no
// taps): which invitation draft each language opens on, when the reset
// phrase unlocks the reset, and what one Save sends. The screen keeps the
// wiring: seeding, the per-language draft switch, the reset dialog and the
// Save command.
import 'package:deskilo/features/workspace/domain/invitation_message.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/workspace_reset.dart';
import 'package:deskilo/features/workspace/domain/workspace_settings_save.dart';
import 'package:flutter_test/flutter_test.dart';

const _languages = ['en', 'fr', 'de'];

WorkspaceSettingsSave _save({
  String country = 'ch',
  String currency = 'chf',
  NewMemberDefaults? defaults,
}) => WorkspaceSettingsSave(
  expectedModifiedAt: null,
  countryCode: country,
  currencyCode: currency,
  timezone: 'Europe/Zurich',
  whatsappGroup: '',
  address: '2 Place du Marché',
  defaultLocale: 'fr',
  deskOpacity: 80,
  invitationTemplates: const {'en': 'Hello'},
  newMemberDefaults: defaults,
);

void main() {
  group('the invitation draft each language opens on', () {
    final table =
        <String, (Map<String, dynamic>, String, Map<String, String>)>{
          'a fresh workspace: every draft is the built-in message': (
            const {},
            '',
            const {'en': '', 'fr': '', 'de': ''},
          ),
          'per-language templates: each its own, a missing one empty': (
            const {'en': 'Hello', 'fr': 'Bonjour'},
            'Legacy',
            const {'en': 'Hello', 'fr': 'Bonjour', 'de': ''},
          ),
          'only the legacy template (0049): it opens in every language': (
            const {},
            '  Join us  ',
            const {'en': 'Join us', 'fr': 'Join us', 'de': 'Join us'},
          ),
          'blank per-language templates still count as none': (
            const {'en': '   ', 'fr': ''},
            'Join us',
            const {'en': 'Join us', 'fr': 'Join us', 'de': 'Join us'},
          ),
          'a language the form does not offer is ignored': (
            const {'it': 'Ciao'},
            'Join us',
            const {'en': '', 'fr': '', 'de': ''},
          ),
        };
    for (final MapEntry(key: name, value: (templates, legacy, drafts))
        in table.entries) {
      test(name, () {
        expect(
          invitationDraftsOf(
            templates,
            legacy: legacy,
            languages: _languages,
          ),
          drafts,
        );
      });
    }
  });

  group('when the reset phrase unlocks the reset', () {
    final table = <String, bool>{
      '': false,
      'yes': false,
      'I agre': false,
      'I agree!': false,
      'I agree': true,
      'I AGREE': true,
      '  i agree  ': true,
    };
    for (final MapEntry(key: typed, value: unlocks) in table.entries) {
      test("'$typed'", () {
        expect(resetPhraseMatches(typed, 'I agree'), unlocks);
      });
    }
  });

  group('what one Save sends', () {
    test('every field, the codes in capitals', () {
      expect(_save().toSettings(), {
        'country_code': 'CH',
        'currency_code': 'CHF',
        'timezone': 'Europe/Zurich',
        'whatsapp_group': '',
        'address': '2 Place du Marché',
        'default_locale': 'fr',
        'desk_opacity': 80,
        'invitation_templates': {'en': 'Hello'},
      });
    });

    test('new-member defaults never loaded: the key is absent (#1563)', () {
      expect(
        _save().toSettings().containsKey(newMemberDefaultsKey),
        isFalse,
      );
    });

    test('new-member defaults loaded: they ride the same Save', () {
      const defaults = NewMemberDefaults(
        subscriptionPct: 45,
        overagePolicy: OveragePolicy.payg,
        configured: true,
      );
      expect(
        _save(defaults: defaults).toSettings()[newMemberDefaultsKey],
        defaults.toValue(),
      );
    });
  });
}
