// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home's list of spaces is laid out before any widget is built: which
// groups show which rows in what order, what a search hides, when a row
// may be dragged, and which empty group explains itself. These cases call
// the layout directly, without pumping a screen.
import 'package:deskilo/core/storage/space_prefs_store.dart';
import 'package:deskilo/features/me/application/me_spaces_layout.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace _space(
  String id,
  String name, {
  String pair = '',
  String env = 'dev',
}) => Workspace(
  id: id,
  name: name,
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'X',
  pairId: pair,
  environment: env,
);

final _spaces = [
  _space('a', 'Atelier'),
  _space('b', 'Bureau'),
  _space('c', 'Cabane'),
];

const _mine = SpacePrefs(
  groups: [SpaceGroup('g1', 'Mine')],
  groupOf: {'space:b': 'g1'},
);

MeSpacesLayout _layout({
  SpacePrefs prefs = _mine,
  List<Workspace>? spaces,
  String? lastUsedId,
  String query = '',
}) => MeSpacesLayout.of(
  prefs: prefs,
  spaces: spaces ?? _spaces,
  lastUsedId: lastUsedId,
  query: query,
);

Map<String, List<String>> _groups(MeSpacesLayout layout) => {
  for (final g in layout.groups) g.id: g.keys,
};

void main() {
  test('without a search every group shows, Favorites and my own groups say '
      'why they are empty, Other does not', () {
    final layout = _layout(
      prefs: const SpacePrefs(groups: [SpaceGroup('g1', 'Mine')]),
    );
    expect(_groups(layout), {
      SpaceGroup.favoritesGroup: <String>[],
      'g1': <String>[],
      SpaceGroup.otherGroup: ['space:a', 'space:b', 'space:c'],
    });
    expect(layout.noMatch, isFalse);
    expect(layout.explainsEmpty(SpaceGroup.favoritesGroup), isTrue);
    expect(layout.explainsEmpty('g1'), isTrue);
    expect(layout.explainsEmpty(SpaceGroup.otherGroup), isFalse);
  });

  test('a search keeps only the groups it found something in', () {
    final layout = _layout(query: '  BUR ');
    expect(_groups(layout), {
      'g1': ['space:b'],
    });
    expect(layout.visible, ['space:b']);
    expect(
      layout.explainsEmpty('g1'),
      isFalse,
      reason: 'nothing explains itself during a search',
    );

    final none = _layout(query: 'zzz');
    expect(none.groups, isEmpty);
    expect(none.noMatch, isTrue);
  });

  test('rows move by hand only in my own order and with nothing filtered', () {
    expect(_layout().canDrag, isTrue);
    expect(_layout(query: 'a').canDrag, isFalse);
    expect(
      _layout(prefs: const SpacePrefs(sort: SpaceSort.alphabet)).canDrag,
      isFalse,
    );
  });

  test('unplaced rows keep the order they came in, the last used first', () {
    final layout = _layout(prefs: SpacePrefs.empty, lastUsedId: 'c');
    expect(_groups(layout)[SpaceGroup.otherGroup], [
      'space:c',
      'space:a',
      'space:b',
    ]);
  });

  test('both sides of a pair are one row, production first', () {
    final layout = _layout(
      prefs: SpacePrefs.empty,
      spaces: [
        _space('d', 'Pair'),
        _space('p', 'Pair', pair: 'x', env: 'prod'),
        _space('d2', 'Pair', pair: 'x'),
      ],
    );
    expect(_groups(layout)[SpaceGroup.otherGroup], ['space:d', 'pair:x']);
    expect([for (final side in layout.rows['pair:x']!) side.id], ['p', 'd2']);
  });
}
