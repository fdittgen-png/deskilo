// SPDX-License-Identifier: AGPL-3.0-or-later
// #2472: what typing suggests in a new discussion — the rules without a
// widget: a person once per server with every shared workspace, never me,
// prefix (first or last name) before contains, accent- and
// case-insensitive.
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/recipient_search.dart';
import 'package:flutter_test/flutter_test.dart';

ReachablePerson _p(String ws, String id, String name) => ReachablePerson(
  workspaceId: ws,
  workspaceName: ws == 'w1' ? 'Atelier' : 'Loft',
  id: id,
  name: name,
);

Recipient _r(String name) =>
    Recipient.person(source: '', id: name, name: name, workspaces: const []);

void main() {
  test('a person in two workspaces is one recipient naming both, and I am '
      'never one', () {
    final all = recipientsOf(
      {
        '': [
          _p('w1', 'a', 'Alice'),
          _p('w2', 'a', 'Alice'),
          _p('w1', 'me', 'Me'),
        ],
        'https://far.example': [_p('w1', 'a', 'Alice')],
      },
      hostOf: {'': '', 'https://far.example': 'far.example'},
      self: 'me',
    );
    expect(all.map((r) => (r.source, r.id)), [
      ('', 'a'),
      ('https://far.example', 'a'),
    ]);
    expect(all.first.workspaces, ['Atelier', 'Loft']);
    expect(all.last.workspaces, ['Atelier · far.example']);
  });

  test('one letter suggests; prefix before a last name before contains', () {
    final all = [_r('Pauline Martin'), _r('Marc Durand'), _r('Amélie Roux')];
    expect(suggestRecipients(all, 'm').map((r) => r.name), [
      'Marc Durand', // the name starts with it
      'Pauline Martin', // the last name does
      'Amélie Roux', // only contains it
    ]);
  });

  test('accents and case do not matter, either way', () {
    final all = [_r('Élodie Faure'), _r('Zoe Muller')];
    expect(suggestRecipients(all, 'elo').single.name, 'Élodie Faure');
    expect(suggestRecipients(all, 'ZOË').single.name, 'Zoe Muller');
    expect(suggestRecipients(all, 'MÜL').single.name, 'Zoe Muller');
    expect(suggestRecipients(all, 'x'), isEmpty);
    expect(suggestRecipients(all, ''), isEmpty);
  });

  test('groups are suggested by title, and the list is capped', () {
    final group = Recipient.group(
      InboxEntry(
        source: '',
        kind: MessageContextKind.accountGroup,
        contextId: 'g1',
        title: 'Floor crew',
        lastAt: DateTime.utc(2026, 7, 15),
      ),
    );
    expect(suggestRecipients([group], 'fl').single.isGroup, isTrue);
    final many = [for (var i = 0; i < 20; i++) _r('Anna $i')];
    expect(suggestRecipients(many, 'a', limit: 5), hasLength(5));
  });

  test('initials come from the first two words', () {
    expect(initialsOf('élodie faure'), 'ÉF');
    expect(initialsOf('Bob'), 'B');
    expect(initialsOf('  '), '?');
  });
}
