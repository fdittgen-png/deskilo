// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2378 review -- the commands behind the settings editor: empty text is a
// value (the documented "nothing declared" state of a text row), a text
// longer than its bound is refused before anything is sent, and a choice
// that lists '' accepts it.
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/workspace/application/settings_commands.dart';
import 'package:flutter_test/flutter_test.dart';

class _Admin implements SettingsAdmin {
  final List<({String? workspaceId, String key, Object value, String note})>
  sent = [];

  @override
  Future<void> setValue({
    String? workspaceId,
    required String key,
    required Object value,
    String note = '',
  }) async {
    sent.add((workspaceId: workspaceId, key: key, value: value, note: note));
  }
}

SettingDefinition _text({num? max}) => SettingDefinition(
  key: 'records.cra_authorisation_reference',
  type: SettingType.text,
  defaultValue: '',
  max: max,
  group: 'records',
  scopes: {SettingScope.workspace},
  editPermission: 'manageBilling',
);

SettingDefinition _choice(List<String> choices) => SettingDefinition(
  key: 'records.hosting_country',
  type: SettingType.choice,
  defaultValue: '',
  group: 'records',
  scopes: {SettingScope.platform},
  choices: choices,
);

void main() {
  group('a text setting', () {
    test('an empty value is accepted and sent as the empty string', () async {
      final admin = _Admin();
      final commands = SettingsCommands(admin);
      expect(commands.problemOf(_text(max: 64), ''), isNull);
      await commands.save(
        workspaceId: 'ws',
        definition: _text(max: 64),
        text: '',
      );
      expect(admin.sent.single.value, '');
      expect(admin.sent.single.key, 'records.cra_authorisation_reference');
    });

    test('a value longer than its bound is refused, nothing sent', () async {
      final admin = _Admin();
      final commands = SettingsCommands(admin);
      final long = 'X' * 65;
      expect(commands.problemOf(_text(max: 64), long), SettingProblem.aboveMax);
      expect(commands.problemOf(_text(max: 64), 'X' * 64), isNull);
      // save() refuses before it builds a future: the throw is synchronous.
      expect(
        () => commands.save(
          workspaceId: 'ws',
          definition: _text(max: 64),
          text: long,
        ),
        throwsArgumentError,
      );
      expect(admin.sent, isEmpty);
    });

    test('without a bound any length passes the client check', () {
      expect(SettingsCommands(_Admin()).problemOf(_text(), 'X' * 500), isNull);
    });
  });

  group('a choice setting', () {
    test('empty is a choice only when the definition lists it', () {
      final commands = SettingsCommands(_Admin());
      expect(commands.problemOf(_choice(['', 'CA', 'DE']), ''), isNull);
      expect(
        commands.problemOf(_choice(['CA', 'DE']), ''),
        SettingProblem.notAChoice,
      );
    });

    test('a name instead of a code is not one of the choices', () {
      expect(
        SettingsCommands(_Admin())
            .problemOf(_choice(['', 'CA', 'DE']), 'Germany'),
        SettingProblem.notAChoice,
      );
    });
  });
}
